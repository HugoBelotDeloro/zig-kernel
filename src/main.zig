const lib = @import("lib.zig");
const riscv = @import("riscv.zig");
const std = @import("std");
const processes = @import("processes.zig");
const Process = @import("Process.zig");

const free_ram = @extern([*]u8, .{ .name = "__free_ram" });
const free_ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });

pub const std_options = std.Options{
    .page_size_max = 4096,
    .page_size_min = 4096,
    .logFn = lib.logFn,
    .log_level = .info,
};

const stack_top = @extern([*]u8, .{ .name = "__stack_top" });
const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });

export fn boot() linksection(".text.boot") callconv(.Naked) noreturn {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_setup
        :
        : [stack_top] "r" (stack_top),
    );
}

export fn kernel_setup() noreturn {
    @memset(bss[0 .. bss_end - bss], 0);

    riscv.setTrapHandler();

    kmain() catch |err| {
        lib.serialWriter.print("ERROR: {!}\n", .{err}) catch {};
    };

    lib.panic("kmain returned", .{}, @src());
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

var proc_a: *Process = undefined;
var proc_b: *Process = undefined;

fn delay() void {
    for (0..10000000) |_| {
        asm volatile ("nop");
    }
}

fn proc_a_entry() noreturn {
    std.log.info("starting {}", .{proc_a});
    while (true) {
        riscv.putChar('A');
        proc_a.switchContextTo(proc_b);
        delay();
    }
}

fn proc_b_entry() noreturn {
    std.log.info("starting {}", .{proc_b});
    while (true) {
        riscv.putChar('B');
        proc_b.switchContextTo(proc_a);
        delay();
    }
}

pub fn kmain() !void {
    var fba = std.heap.FixedBufferAllocator.init(free_ram[0 .. free_ram_end - free_ram]);
    var allocator = KAllocator{ .backing_allocator = fba.allocator() };

    const a = try allocator.allocator().create(usize);
    a.* = 42;

    const log = std.log.scoped(.kernel);
    log.debug("test: {d}, {*}", .{ a.*, a });

    proc_a = try processes.createProcess(@intFromPtr(&proc_a_entry));
    proc_b = try processes.createProcess(@intFromPtr(&proc_b_entry));
    proc_a_entry();
}
