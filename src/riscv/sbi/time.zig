const Sbi = @import("../sbi.zig");
const sbiCall2 = Sbi.sbiCall2;

pub fn setTimer(time: u64) void {
    _ = sbiCall2(@truncate(time), @intCast(time >> 32), 0, .Time);
}
