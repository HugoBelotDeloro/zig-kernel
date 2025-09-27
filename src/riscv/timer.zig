const std = @import("std");
const lib = @import("../lib.zig");
const riscv = @import("../riscv.zig");

pub fn handleTimer() void {
    const time = riscv.readTime();
    riscv.sbi.time.setTimer(time + 15_000_000);
    lib.yield();
}
