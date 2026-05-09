const std = @import("std");
const Process = @import("Process.zig");
const ProcsMax = 8;
const lib = @import("lib.zig");

const log = std.log.scoped(.processes);

var Procs: [ProcsMax]Process = @splat(Process{
    .state = .unused,
    .pid = undefined,
    .sp = undefined,
    .stack = undefined,
    .page_table = undefined,
});

pub var current: *Process = undefined;
pub const Idle: *Process = &Procs[0];

pub fn createIdleProcess(page_alloc: std.mem.Allocator) !void {
    try Process.initIdle(Idle, page_alloc);
}

pub fn createKernelProcess(entry: *const fn () callconv(.c) noreturn, pa: std.mem.Allocator) !*Process {
    const proc_id = for (&Procs, 0..) |*process, id| {
        if (process.state == .unused) {
            break id;
        }
    } else return error.NoProcessSlot;

    var proc = &Procs[proc_id];

    try proc.initKernel(proc_id, entry, pa);
    log.info("Created {f}", .{proc});

    return proc;
}

pub fn createUserProcess(image: []const u8, pa: std.mem.Allocator) !*Process {
    const proc_id = for (&Procs, 0..) |*process, id| {
        if (process.state == .unused) {
            break id;
        }
    } else return error.NoProcessSlot;

    var proc = &Procs[proc_id];

    try proc.initUser(proc_id, image, pa);
    log.info("Created {f}", .{proc});

    return proc;
}

pub fn yield() void {
    var i = (current.pid + 1) % ProcsMax;
    while (i != current.pid) : (i = (i + 1) % ProcsMax) {
        if (i != 0 and Procs[i].state == .runnable) break;
    }

    const next = if (Procs[i].state == .runnable) &Procs[i] else Idle;

    if (next == current) {
        log.debug("process #{d} keeps running", .{current.pid});
        return;
    }

    next.page_table.setActive();

    asm volatile ("csrw sscratch, %[sscratch]"
        :
        : [sscratch] "r" (@as([*]u8, @ptrCast(&next.stack)) + next.stack.len),
    );

    log.info("switching from process #{d} to #{d}", .{ current.pid, next.pid });

    const curr = current;
    current = next;

    asm volatile (
        \\mv a0, %[from_sp]
        \\mv a1, %[to_sp]
        \\call switchContextTo
        :
        : [from_sp] "r" (&curr.sp),
          [to_sp] "r" (&next.sp),
    );
}

export fn switchContextTo() callconv(.naked) void {
    asm volatile (
        \\addi sp, sp, -4 * 13
        \\sw ra, 4 * 0(sp)
        \\sw s0, 4 * 1(sp)
        \\sw s1, 4 * 2(sp)
        \\sw s2, 4 * 3(sp)
        \\sw s3, 4 * 4(sp)
        \\sw s4, 4 * 5(sp)
        \\sw s5, 4 * 6(sp)
        \\sw s6, 4 * 7(sp)
        \\sw s7, 4 * 8(sp)
        \\sw s8, 4 * 9(sp)
        \\sw s9, 4 * 10(sp)
        \\sw s10, 4 * 11(sp)
        \\sw s11, 4 * 12(sp)
        \\sw sp, (a0)
        \\lw sp, (a1)
        \\lw ra, 4 * 0(sp)
        \\lw s0, 4 * 1(sp)
        \\lw s1, 4 * 2(sp)
        \\lw s2, 4 * 3(sp)
        \\lw s3, 4 * 4(sp)
        \\lw s4, 4 * 5(sp)
        \\lw s5, 4 * 6(sp)
        \\lw s6, 4 * 7(sp)
        \\lw s7, 4 * 8(sp)
        \\lw s8, 4 * 9(sp)
        \\lw s9, 4 * 10(sp)
        \\lw s10, 4 * 11(sp)
        \\lw s11, 4 * 12(sp)
        \\addi sp, sp, 4 * 13
        \\ret
    );
}
