const std = @import("std");
const lib = @import("lib.zig");
const riscv = @import("riscv");
const sv32 = riscv.sv32;
const Csr = riscv.Csr;

pub const UserBase: usize = 0x1000000;

pub const StackSize = 8192;
const PageSize = lib.PageSize;

const log = std.log.scoped(.process);

const Self = @This();

const State = enum {
    unused,
    runnable,
    exited,
};

pid: usize,
state: State = .unused,
sp: [*]u8,
page_table: sv32.PageTable.Ptr,
stack: [StackSize]u8 align(4),

const KernelProcessStackSize: usize = 64 * 1024;

pub fn initIdle(self: *Self, page_alloc: std.mem.Allocator) !void {
    self.* = Self{ .pid = 0, .page_table = try @import("lib/segmentation.zig").mapKernel(page_alloc), .sp = undefined, .stack = undefined, .state = .runnable };

    self.sp = initStack(&self.stack, @intFromPtr(&idle), null);
}

fn initStack(stack: *align(4) [StackSize]u8, initial_return_address: usize, initial_param: ?usize) [*]u8 {
    const stack_usize: *[StackSize / @sizeOf(usize)]usize align(4) = @ptrCast(stack);
    const regs = stack_usize[stack_usize.len - 13 ..];

    regs[0] = initial_return_address;
    if (initial_param) |param| {
        regs[1] = param;
        for (regs[2..]) |*reg| {
            reg.* = 0;
        }
    } else {
        for (regs[1..]) |*reg| {
            reg.* = 0;
        }
    }

    return @ptrCast(regs);
}

/// Only meaningful on a stopped process of course
pub fn logSavedRegisters(self: *Self) void {
    const sp: usize = @intFromPtr(self.sp);
    const stack_addr_int: usize = @intFromPtr(&self.stack);
    if (sp <= stack_addr_int) {
        log.warn("Process {x}: sp points outside of the stack (sp = {x}, stack = {x}-{x})", .{ self.pid, sp, stack_addr_int, stack_addr_int + self.stack.len });
    } else if (sp > stack_addr_int + self.stack.len) {
        log.warn("Process {x}: sp points outside of the stack (stack = {x}-{x}, sp = {x})", .{ self.pid, stack_addr_int, stack_addr_int + self.stack.len, sp });
    }
    log.info("Saved sp for process {d}: {x}", .{ self.pid, sp });
    const regs: [*]usize = @ptrCast(@alignCast(self.sp));

    const RegNames: [13][]const u8 = [_][]const u8{ "ra", "s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11" };
    for (regs[0..13], RegNames) |reg, reg_name| {
        log.info("Saved value for {s}: {x}", .{ reg_name, reg });
    }
}

pub fn initKernel(self: *Self, pid: usize, entry: *const fn () callconv(.c) noreturn, page_alloc: std.mem.Allocator) !void {
    const page_table = try @import("processes.zig").Idle.page_table.clone(page_alloc);

    // Allocate and map stack pages
    const pages = try lib.allocPagesFromLen(KernelProcessStackSize);
    try page_table.mapRange(pages, UserBase, "rwx", page_alloc);

    self.* = Self{
        .pid = pid,
        .sp = undefined,
        .state = .runnable,
        .page_table = page_table,
        .stack = undefined,
    };

    self.sp = initStack(&self.stack, @intFromPtr(&kernelEntry), @intFromPtr(entry));
    self.logSavedRegisters();
}

/// Jump to s0 (kernel function to run in this process) in kernel mode and with interrupts enabled.
fn kernelEntry() callconv(.naked) noreturn {
    const sstatus = Csr.Sstatus{
        .spie = true,
        .spp = .supervisor,
    };
    const kernel_stack_top = UserBase + KernelProcessStackSize;
    asm volatile (
        \\csrw sstatus, %[sstatus]
        \\csrw sepc, s0
        \\mv sp, %[stack_top]
        \\sret
        :
        : [stack_top] "r" (kernel_stack_top),
          [sstatus] "r" (sstatus),
    );
    while (true) asm volatile ("wfi");
}

pub fn initUser(self: *Self, pid: usize, image: []const u8, page_alloc: std.mem.Allocator) !void {
    const page_table = try @import("processes.zig").Idle.page_table.clone(page_alloc);
    log.debug("Created page table {*} for process {d}", .{ page_table, pid });

    // Allocate, copy and map user pages
    const pages = try lib.allocPagesFromLen(image.len);
    @memcpy(pages, image);
    try page_table.mapRange(pages, UserBase, "rwxu", page_alloc);

    self.* = Self{
        .pid = pid,
        .sp = undefined,
        .state = .runnable,
        .page_table = page_table,
        .stack = undefined,
    };

    self.sp = initStack(&self.stack, @intFromPtr(&userEntry), null);
}

/// Jump to UserBase in user mode with interrupts enabled
fn userEntry() callconv(.naked) noreturn {
    const sstatus = Csr.Sstatus{
        .spie = true,
        .spp = .user,
    };
    asm volatile (
        \\csrw sepc, %[sepc]
        \\csrw sstatus, %[sstatus]
        \\sret
        :
        : [sepc] "r" (UserBase),
          [sstatus] "r" (sstatus),
    );
}

fn idle() callconv(.naked) noreturn {
    while (true) asm volatile ("wfi");
}

pub fn format(
    self: *Self,
    writer: *std.Io.Writer,
) !void {
    try writer.print("{{{*} #{d} sp {x} {s}}}", .{ self, self.pid, @intFromPtr(self.sp), @tagName(self.state) });
}
