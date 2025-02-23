const std = @import("std");
const Process = @import("Process.zig");
const ProcsMax = 8;

const log = std.log.scoped(.processes);

var Procs: [ProcsMax]Process = .{Process{
    .state = .unused,
    .pid = undefined,
    .sp = undefined,
    .stack = undefined,
    .saved_registers = undefined,
}} ** ProcsMax;

pub fn createProcess(pc: usize) !*Process {
    const proc_id = for (&Procs, 0..) |*process, id| {
        if (process.state == .unused) {
            break id;
        }
    } else return error.NoProcessSlot;

    var proc = &Procs[proc_id];

    proc.init(proc_id, pc);
    log.info("Created {}", .{proc});

    return proc;
}
