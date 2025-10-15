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

const SavedRegisters = struct {
    regs: [13]usize = [_]usize{0} ** 13,

    pub fn init(initial_return_address: usize, init_param: ?usize) SavedRegisters {
        var sr = SavedRegisters{};
        sr.regs[0] = initial_return_address;
        if (init_param) |s0| sr.regs[1] = s0;
        return sr;
    }

    pub fn ra(self: *SavedRegisters) usize {
        return self.regs[0];
    }

    pub inline fn save(self: *SavedRegisters) void {
        asm volatile (
            \\sw ra, 4 * 0(%[regs])
            \\sw s0, 4 * 1(%[regs])
            \\sw s1, 4 * 2(%[regs])
            \\sw s2, 4 * 3(%[regs])
            \\sw s3, 4 * 4(%[regs])
            \\sw s4, 4 * 5(%[regs])
            \\sw s5, 4 * 6(%[regs])
            \\sw s6, 4 * 7(%[regs])
            \\sw s7, 4 * 8(%[regs])
            \\sw s8, 4 * 9(%[regs])
            \\sw s9, 4 * 10(%[regs])
            \\sw s10, 4 * 11(%[regs])
            \\sw s11, 4 * 12(%[regs])
            :
            : [regs] "r" (&self.regs),
        );
    }

    pub inline fn load(self: *SavedRegisters) void {
        asm volatile (
            \\lw ra, 4 * 0(%[regs])
            \\lw s0, 4 * 1(%[regs])
            \\lw s1, 4 * 2(%[regs])
            \\lw s2, 4 * 3(%[regs])
            \\lw s3, 4 * 4(%[regs])
            \\lw s4, 4 * 5(%[regs])
            \\lw s5, 4 * 6(%[regs])
            \\lw s6, 4 * 7(%[regs])
            \\lw s7, 4 * 8(%[regs])
            \\lw s8, 4 * 9(%[regs])
            \\lw s9, 4 * 10(%[regs])
            \\lw s10, 4 * 11(%[regs])
            \\lw s11, 4 * 12(%[regs])
            :
            : [regs] "r" (&self.regs),
        );
    }

    pub fn format(
        self: *const SavedRegisters,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("{any} ", .{self.regs});
    }
};

pid: usize,
state: State = .unused,
sp: [*]u8,
saved_registers: SavedRegisters,
page_table: sv32.PageTable.Ptr,
stack: [StackSize]u8 align(4),

pub fn initIdle(self: *Self, page_alloc: std.mem.Allocator) !void {
    self.* = Self{ .pid = 0, .page_table = try @import("lib/segmentation.zig").mapKernel(page_alloc), .sp = self.stack[self.stack.len - 1 ..], .stack = undefined, .state = .runnable,
    .saved_registers = .init(@intFromPtr(&idle), null) };
}

pub fn initKernel(self: *Self, pid: usize, entry: *const fn () noreturn) !void {
    const page_table = @import("processes.zig").Idle.page_table;
    log.debug("Created page table {*} for process {d}", .{ page_table, pid });

    self.* = Self{
        .pid = pid,
        .sp = self.stack[self.stack.len - 1 ..],
        .state = .runnable,
        .saved_registers = .init(
            @intFromPtr(&kernelEntry),
            @intFromPtr(entry),
        ),
        .page_table = page_table,
        .stack = undefined,
    };
}

fn kernelEntry() callconv(.naked) noreturn {
    const sstatus = Csr.Sstatus{
        .sie = true,
        .spp = .supervisor,
    };
    asm volatile (
        \\csrw sepc, s0
        \\csrw sstatus, %[sstatus]
        \\sret
        :
        : [sstatus] "r" (sstatus),
    );
}

pub fn initUser(self: *Self, pid: usize, image: []const u8, page_alloc: std.mem.Allocator) !void {
    const page_table = try @import("processes.zig").Idle.page_table.clone(page_alloc);
    log.debug("Created page table {*} for process {d}", .{ page_table, pid });

    // Map user pages
    const pages = try lib.allocPagesFromLen(image.len);
    @memcpy(pages, image);
    try page_table.mapRange(pages, UserBase, "rwxu", page_alloc);

    self.* = Self{
        .pid = pid,
        .sp = self.stack[self.stack.len - 1 ..],
        .state = .runnable,
        .saved_registers = SavedRegisters{
            .ra = @intFromPtr(&userEntry),
        },
        .page_table = page_table,
        .stack = undefined,
    };
}

fn userEntry() callconv(.naked) noreturn {
    const sstatus = Csr.Sstatus{
        .spie = true,
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

fn idle() callconv(.Naked) noreturn {
    while (true) asm volatile ("wfi");
}

pub fn format(
    self: *Self,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    try writer.print("{{Process #{d} sp {x} ra {x} {s}}}", .{ self.pid, @intFromPtr(self.sp),
self.saved_registers.ra(), @tagName(self.state) });
}
