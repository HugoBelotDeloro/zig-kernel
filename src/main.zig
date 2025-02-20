const lib = @import("lib.zig");
const riscv = @import("riscv.zig");
const std = @import("std");

const free_ram = @extern([*]u8, .{ .name = "__free_ram" });
const free_ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });

pub const std_options = std.Options{ .page_size_max = 4096, .page_size_min = 4096 };

const stack_top = @extern([*]u8, .{ .name = "__stack_top" });
const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });

export fn boot() linksection(".text.boot") callconv(.Naked) noreturn {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_main
        :
        : [stack_top] "r" (stack_top),
    );
}

export fn kernel_main() noreturn {
    @memset(bss[0 .. bss_end - bss], 0);

    riscv.setTrapHandler();

    main() catch |err| {
        lib.serialWriter.print("ERROR: {!}\n", .{err}) catch {};
    };

    lib.panic("kernel_main end", .{}, @src());
}

const KAllocator = std.heap.GeneralPurposeAllocator(.{
    .thread_safe = false,
});

// Override the page allocator to avoid Zig trying to import the default page allocator,
// as it does not exist for freestanding.
pub const os = struct {
    pub const heap = struct {
        pub const page_allocator: std.mem.Allocator = .{
            .ptr = undefined,
            .vtable = undefined,
        };
    };
};

pub fn main() !void {
    var fba = std.heap.FixedBufferAllocator.init(free_ram[0 .. free_ram_end - free_ram]);
    var allocator = KAllocator{ .backing_allocator = fba.allocator() };

    const a = try allocator.allocator().create(usize);
    a.* = 42;

    lib.panic("test: {d}, {*}", .{ a.*, a }, @src());
}
