const std = @import("std");
const Process = @import("Process.zig");
const ProcsMax = 8;
const lib = @import("lib.zig");

const log = std.log.scoped(.processes);

var Procs: [ProcsMax]Process = .{Process{
    .state = .unused,
    .pid = undefined,
    .sp = undefined,
    .stack = undefined,
    .saved_registers = undefined,
    .page_table = undefined,
}} ** ProcsMax;

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
    log.info("Created {}", .{proc});

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
    log.info("Created {}", .{proc});

    return proc;
}

pub fn yield() void {
    var i = (current.pid + 1) % ProcsMax;
    while (i != current.pid) : (i = (i + 1) % ProcsMax) {
        if (i != 0 and Procs[i].state == .runnable) break;
    }

    const next = &Procs[i];

    // Switch to idle
    if (next.state != .runnable) switchContextTo(current, Idle);

    if (next == current) {
        log.debug("process #{d} keeps running", .{current.pid});
        return;
    }

    switchContextTo(current, next);
}

noinline fn switchContextTo(from: *Process, to: *Process) callconv(.C) void {
    from.saved_registers.save();

    log.info("switching from process #{d} to #{d} @ {x}", .{ from.pid, to.pid, to.saved_registers.ra() });
    asm volatile ("csrw sscratch, %[sscratch]"
        :
        : [sscratch] "r" (@as([*]u8, @ptrCast(&to.stack)) + to.stack.len),
    );

    current = to;

    to.page_table.setActive();

    asm volatile (
        \\sw sp, (%[curr])
        \\lw sp, (%[next])
        :
        : [next] "r" (&to.sp),
          [curr] "r" (&from.sp),
    );
    to.saved_registers.load();
    asm volatile ("ret");
}
