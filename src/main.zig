pub const lib = @import("lib.zig");
pub const riscv = @import("riscv.zig");
const std = @import("std");
const processes = @import("processes.zig");
const Process = @import("Process.zig");

const PageSize = riscv.PageSize;

pub const KernelBase = @extern([*]u8, .{ .name = "__kernel_base" });
pub const Bss = @extern([*]u8, .{ .name = "__bss" });
pub const BssEnd = @extern([*]u8, .{ .name = "__bss_end" });
pub const StackTop = @extern([*]u8, .{ .name = "__stack_top" });
pub const FreeRamStart = @extern([*]u8, .{ .name = "__free_ram" });
pub const FreeRamEnd = @extern([*]u8, .{ .name = "__free_ram_end" });

const shell = @embedFile("shell.bin");

pub const std_options = std.Options{
    .page_size_max = PageSize,
    .page_size_min = PageSize,
    .logFn = lib.logFn,
    .log_level = .info,
    .log_scope_levels = &.{ .{ .scope = .sv32, .level = .info }, .{ .scope = .processes, .level = .info } },
};

export fn boot() linksection(".text.boot") callconv(.Naked) noreturn {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_setup
        :
        : [stack_top] "r" (StackTop),
    );
}

export fn kernel_setup() noreturn {
    @memset(Bss[0 .. BssEnd - Bss], 0);

    riscv.setTrapHandler();

    kmain() catch |err| {
        lib.serialWriter.print("ERROR: {!}\n", .{err}) catch {};
    };

    lib.panic("kmain returned", .{}, @src());
}

pub const PageAllocator = lib.PageAllocator;
const KAllocator = std.heap.GeneralPurposeAllocator(.{
    .thread_safe = false,
    .page_size = PageSize,
    .backing_allocator_zeroes = false,
});

// Override the page allocator to avoid Zig trying to import the default page allocator,
// as it does not exist for freestanding.
pub const os = struct {
    pub const heap = struct {
        pub const page_allocator = PageAllocator;
    };
};

pub fn kmain() !void {
    var gpa_instance = KAllocator{ .backing_allocator = PageAllocator };
    const gpa = gpa_instance.allocator();

    const log = std.log.scoped(.kernel);
    log.info("kernel started", .{});

    const idle_process = try processes.createProcess(&.{}, gpa);
    processes.current = idle_process;

    log.warn("shell.bin: size {d} addr {*}", .{ shell.len, shell.ptr });

    _ = try processes.createProcess(shell, gpa);

    // Enable interrupts at first switch to U-mode
    var sstatus: riscv.csr.Sstatus = @bitCast(riscv.csr.readCsr(.sstatus));
    sstatus.spie = true;
    riscv.csr.writeCsr(.sstatus, @bitCast(sstatus));

    // Enable all types of interrupts
    const sie = riscv.csr.Sie{
        .software = true,
        .timer = true,
        .external = true,
    };
    riscv.csr.writeCsr(.sie, @bitCast(sie));

    // Set initial timer
    //const i = riscv.csr.readCsr(.time);
    //riscv.opensbi.setTimer(i + 10000000);

    // What I want to do now:
    // - Have an idle process which can be switched to, has low priority (only switched to if no
    //   other is ready, only runs the wfi instruction and waits for the next timer to switch)
    // - Putchar should not busy loop and instead set the process to waiting then switch

    processes.yield();
}
