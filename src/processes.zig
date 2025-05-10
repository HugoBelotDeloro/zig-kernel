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

pub fn createProcess(image: []const u8, pa: std.mem.Allocator) !*Process {
    const proc_id = for (&Procs, 0..) |*process, id| {
        if (process.state == .unused) {
            break id;
        }
    } else return error.NoProcessSlot;

    var proc = &Procs[proc_id];

    try proc.init(proc_id, image, pa);
    log.info("Created {}", .{proc});

    return proc;
}

pub fn yield() void {
    var i = current.pid + 1;
    while (i != current.pid) : (i = (i + 1) % ProcsMax) {
        if (Procs[i].pid != 0 and Procs[i].state == .runnable) break;
    }

    const next = &Procs[i];

    // Switch to idle
    if (next.state != .runnable) switchContextTo(current, &Procs[0]);

    if (next == current) {
        log.debug("process #{d} keeps running", .{current.pid});
        return;
    }

    switchContextTo(current, next);
}

fn switchContextTo(from: *Process, to: *Process) void {
    log.info("switching from process #{d} to #{d}", .{ from.pid, to.pid });
    asm volatile ("csrw sscratch, %[sscratch]"
        :
        : [sscratch] "r" (@as([*]u8, @ptrCast(&to.stack)) + to.stack.len),
    );

    current = to;

    from.saveContext();
    const Satp = @import("root").riscv.sv32.Satp;
    Satp.fromPageTable(to.page_table).set();

    asm volatile (
    // Switch the stack pointer.
    // *prev_sp = sp;
        \\sw sp, (%[curr])
        // Switch stack pointer (sp) here
        \\lw sp, (%[next])
        :
        : [next] "r" (&to.sp),
          [curr] "r" (&from.sp),
    );
    to.loadContext();

    asm volatile ("ret");
}
