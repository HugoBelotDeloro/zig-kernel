const common = @import("common");
const std = @import("std");

const Syscall = common.Syscall;
const StackTop = @extern([*]u8, .{ .name = "__stack_top" });

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

const WriteError = error{};
const Context = void;

fn writeToSerialConsole(context: Context, bytes: []const u8) WriteError!usize {
    _ = context;
    for (bytes) |c| {
        putChar(c);
    }
    return bytes.len;
}

const Writer = std.io.Writer(Context, WriteError, writeToSerialConsole);
pub const serialWriter = Writer{
    .context = {},
};

const ReadError = error{};

fn readFromSerialConsole(context: *const anyopaque, buffer: []u8) anyerror!usize {
    _ = context;
    var i: usize = 0;
    while (i < buffer.len) {
        const c = getChar();
        putChar(c);
        buffer[i] = c;
        if (c == '\r') {
            putChar('\n');
            break;
        }
        i += 1;
    }
    return i;
}

const serialReader = std.io.AnyReader{ .context = undefined, .readFn = readFromSerialConsole };

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
        const size = try serialReader.read(&buf);
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
