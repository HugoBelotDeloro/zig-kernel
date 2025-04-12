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

    if (next == current) {
        return;
    }

    const Satp = @import("root").riscv.sv32.Satp;
    Satp.fromPageTable(next.page_table).set();
    asm volatile ("csrw sscratch, %[sscratch]"
        :
        : [sscratch] "r" (@as([*]u8, @ptrCast(&next.stack)) + next.stack.len),
    );

    const prev = current;
    current = next;

    switchContextTo(prev, current);
}

//callconv(.naked)
fn switchContextTo(from: *Process, to: *Process) void {
    from.saveContext();

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
