const std = @import("std");
const riscv = @import("riscv.zig");

const Context = void;
const WriteError = error{};
const Writer = std.io.Writer(Context, WriteError, writeToSerialConsole);

pub const serialWriter = Writer{
    .context = {},
};

fn writeToSerialConsole(context: Context, bytes: []const u8) WriteError!usize {
    _ = context;
    for (bytes) |c| {
        riscv.putChar(c);
    }
    return bytes.len;
}

/// Last parameter should be @src()
pub fn panic(comptime fmt: []const u8, args: anytype, src: std.builtin.SourceLocation) noreturn {
    try serialWriter.print("PANIC: {s}:{s}:{d}: " ++ fmt ++ "\n", .{ src.file, src.fn_name, src.line } ++ args);

    while (true) asm volatile ("wfi");
}
