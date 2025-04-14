const lib = @import("../lib.zig");

pub fn handleTimer() void {
    // TODO
    lib.panic("timer interrupt", .{}, @src());
}
