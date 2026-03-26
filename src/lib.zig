const std = @import("std");
const riscv = @import("riscv");
const processes = @import("processes.zig");

pub const segmentation = @import("lib/segmentation.zig");

pub const PageSize = riscv.PageSize;

// Allocation

const page_allocator = @import("lib/page_allocator.zig");
pub const allocPages = page_allocator.allocPages;
pub const freePages = page_allocator.freePages;
pub const allocPagesFromLen = page_allocator.allocPagesFromLen;
pub const freePagesFromLen = page_allocator.freePagesFromLen;
pub const PageAllocator = page_allocator.PageAllocator;

// Logging

pub var serialWriter = std.Io.Writer{
    .buffer = &[_]u8{},
    .vtable = &std.Io.Writer.VTable {
        .drain = &drain,
    },
};

fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
    _ = splat;
    var total = writeToSerialConsole(w.buffer[0..w.end]);

    for (data) |slice| {
        total += writeToSerialConsole(slice);
    }

    return total;
}

fn writeToSerialConsole(bytes: []const u8) usize {
    for (bytes) |c| {
        riscv.sbi.putChar(c);
    }
    return bytes.len;
}

pub fn panic(msg: []const u8, return_address: ?usize) noreturn {
    serialWriter.print("\n\nPANIC @ {?x}: {s}\n", .{ return_address, msg }) catch {};

    while (true) asm volatile ("wfi");
}

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
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

    const level_text: *const [3]u8 = switch (level) {
        .debug => "DBG",
        .info => "INF",
        .warn => "WRN",
        .err => "ERR",
    };

    const underline_code = "\x1B[4:1m";

    comptime var fmt: []const u8 = "[" ++ color_code ++ level_text ++ reset_code ++ ":";
    fmt = fmt ++ underline_code ++ @tagName(scope) ++ reset_code ++ "] ";
    serialWriter.print(fmt ++ format ++ "\n", args) catch {};
}

// Process control
pub const yield = @import("processes.zig").yield;
