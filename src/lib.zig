const std = @import("std");
const riscv = @import("riscv.zig");

const PageSize = riscv.PageSize;

// Allocation

const page_allocator = @import("lib/page_allocator.zig");
pub const allocPages = page_allocator.allocPages;
pub const freePages = page_allocator.freePages;
pub const allocPagesFromLen = page_allocator.allocPagesFromLen;
pub const freePagesFromLen = page_allocator.freePagesFromLen;
pub const PageAllocator = page_allocator.PageAllocator;

// Logging

const Context = void;
const Writer = std.io.Writer(Context, WriteError, writeToSerialConsole);
pub const serialWriter = Writer{
    .context = {},
};

const WriteError = error{};
fn writeToSerialConsole(context: Context, bytes: []const u8) WriteError!usize {
    _ = context;
    for (bytes) |c| {
        riscv.putChar(c);
    }
    return bytes.len;
}

/// Last parameter should be @src()
pub fn panic(comptime fmt: []const u8, args: anytype, src: std.builtin.SourceLocation) noreturn {
    try serialWriter.print("\n\nPANIC: {s}:{s}:{d}: " ++ fmt ++ "\n", .{ src.file, src.fn_name, src.line } ++ args);

    while (true) asm volatile ("wfi");
}

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const color_code: []const u8 = switch (level) {
        .debug => "\x1B[0;37m",
        .info => "\x1B[0;34m",
        .warn => "\x1B[0;33m",
        .err => "\x1B[0;31m",
    };
    const reset_code = "\x1B[0m";

    const level_text: []const u8 = switch (level) {
        .debug => "DEB",
        .info => "INF",
        .warn => "WRN",
        .err => "ERR",
    };

    const underline_code = "\x1B[4:1m";

    comptime var fmt: []const u8 = "[" ++ color_code ++ level_text ++ reset_code ++ ":";
    fmt = fmt ++ underline_code ++ @tagName(scope) ++ reset_code ++ "] ";
    serialWriter.print(fmt ++ format ++ "\n", args) catch {};
}
