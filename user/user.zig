const StackTop = @extern([*]u8, .{ .name = "__stack_top" });

fn exit() noreturn {
    while (true) {}
}

pub fn putChar(c: u8) void {
    _ = c;
}

fn start() linksection(".text.start") callconv(.naked) void {
    asm volatile (
        \\mv sp, %[stack_top]
        \\call main
        \\call exit
        :
        : [stack_top] "r" (StackTop),
    );
}
