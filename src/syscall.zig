const std = @import("std");
const riscv = @import("riscv.zig");
const TrapFrame = riscv.TrapFrame;
const Syscall = @import("common").Syscall;
const putChar = riscv.opensbi.putChar;
const getChar = riscv.opensbi.getChar;
const lib = @import("lib.zig");
const processes = @import("processes.zig");

pub fn handleSyscall(f: *TrapFrame) void {
    const log = std.log.scoped(.syscall);

    const syscall_number: Syscall = @enumFromInt(f.a3);
    log.debug("syscall: {}", .{syscall_number});
    switch (syscall_number) {
        .putchar => putChar(@intCast(f.a0)),
        .getchar => {
            while (true) {
                const c = getChar();
                if (c >= 0) {
                    f.a0 = @intCast(c);
                    break;
                }
                lib.yield();
            }
        },
        .exit => {
            log.info("process #{d} exited", .{processes.current.pid});
            processes.current.state = .exited;
            lib.yield();
            unreachable;
        },
        _ => lib.panic("Unknown syscall: {d}", .{f.a3}, @src()),
    }
}
