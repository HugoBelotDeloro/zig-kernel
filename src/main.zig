const riscv = @import("riscv.zig");

const bss = @extern([*]u8, .{ .name = "__bss"});
const bss_end = @extern([*]u8, .{ .name = "__bss_end"});
const stack_top = @extern([*]u8, .{ .name = "__stack_top"});

export fn kernel_main() noreturn {
    @memset(bss[0..bss_end - bss], 0);

    const hello = "\n\nHello Kernel!\n";
    _ = try riscv.serialWriter.write(hello);

    while (true) asm volatile ("wfi");
}

export fn boot() linksection(".text.boot") callconv(.Naked) void {
    asm volatile (
      \\mv sp, %[stack_top]
      \\j kernel_main
      :
      : [stack_top] "r" (stack_top)
    );
}
