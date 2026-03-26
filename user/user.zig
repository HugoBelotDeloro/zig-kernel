const common = @import("common");
const std = @import("std");

const Syscall = common.Syscall;
const StackTop = @extern([*]u8, .{ .name = "__user_stack_top" });

export fn exit() noreturn {
    _ = syscall(.exit, 0, 0, 0);
    serialWriter.print("EXIT FAILED", .{}) catch {};
    while (true) {}
}

fn syscall(sysno: Syscall, arg0: u32, arg1: u32, arg2: u32) u32 {
    return asm volatile (
        \\ecall
        : [ret] "={a0}" (-> u32),
        : [sysno] "{a3}" (@intFromEnum(sysno)),
          [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
    );
}

fn putChar(char: u8) void {
    _ = syscall(.putchar, char, 0, 0);
}

fn getChar() u8 {
    return @truncate(syscall(.getchar, 0, 0, 0));
}

fn writeToSerialConsole(bytes: []const u8) usize {
    for (bytes) |c| {
        putChar(c);
    }
    return bytes.len;
}

fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
    _ = splat;
    var total = writeToSerialConsole(w.buffer[0..w.end]);

    for (data) |slice| {
        total += writeToSerialConsole(slice);
    }

    return total;
}

pub var serialWriter = std.Io.Writer {
    .vtable = &std.Io.Writer.VTable{
        .drain = &drain,
    },
    .buffer = &[_]u8{},
};

fn stream(r: *std.Io.Reader, w: *std.Io.Writer, limit: std.Io.Limit) std.Io.Reader.StreamError!usize {
    _ = r;
    for (0..@intFromEnum(limit)) |i| {
        const c = getChar();
        putChar(c);
        try w.writeByte(c);
        if (c == '\r') {
            putChar('\n');
            return i;
        }
    }
    return @intFromEnum(limit);
}

pub var serialReader = std.Io.Reader {
    .vtable = &std.Io.Reader.VTable {
        .stream = &stream,
    },
    .buffer = &[_]u8{},
    .seek = 0,
    .end = 0,
};

export fn start() linksection(".text.start") callconv(.naked) void {
    asm volatile (
        \\mv sp, %[stack_top]
        \\call callMain
        \\call exit
        :
        : [stack_top] "r" (StackTop),
    );
}

export fn callMain() void {
    main() catch |err| {
        serialWriter.print("{}", .{err}) catch {};
    };
}

fn main() !void {
    while (true) {
        try serialWriter.print("> ", .{});
        var buf: [128]u8 = undefined;
        const size = try serialReader.readSliceShort(&buf);
        if (std.mem.eql(u8, buf[0..size], "hello")) {
            try serialWriter.print("Hello from shell!\n", .{});
        } else if (std.mem.eql(u8, buf[0..size], "exit")) {
            return;
        } else if (std.mem.eql(u8, buf[0..size], "time")) {
            const time = asm volatile ("csrr %[ret], time"
                : [ret] "=r" (-> usize),
            );
            try serialWriter.print("Time: {d}", .{time});
        } else {
            try serialWriter.print("unknown command \"{s}\"\n", .{buf[0..size]});
        }
    }
}
