const StackTop = @extern([*]u8, .{ .name = "__stack_top" });

export fn exit() noreturn {
    while (true) {}
}

pub fn putChar(c: u8) void {
    _ = c;
}

export fn start() linksection(".text.start") callconv(.naked) void {
    asm volatile (
        \\mv sp, %[stack_top]
        \\call main
        \\call exit
        :
        : [stack_top] "r" (StackTop),
    );
}

export fn main() void {
    const bad_ptr: *volatile usize = @ptrFromInt(0x80200004);
    bad_ptr.* = 5;
    while (true) {}
}
