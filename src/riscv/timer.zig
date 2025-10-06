const std = @import("std");
const lib = @import("../lib.zig");
const riscv = @import("riscv");

pub fn handleTimer() void {
    const time = riscv.readTime();
    riscv.sbi.setTimer(time + 30_000_000);
    lib.yield();
}
