const std = @import("std");

pub const libriscv = @import("riscv");
const PageSize = libriscv.PageSize;

pub const lib = @import("lib.zig");
pub const PageAllocator = lib.PageAllocator;
const Process = @import("Process.zig");
const processes = @import("processes.zig");
pub const riscv = @import("riscv.zig");

const shell = @embedFile("shell.bin");

pub const std_options = std.Options{
    .page_size_max = PageSize,
    .page_size_min = PageSize,
    .logFn = lib.logFn,
    .log_level = .info,
    .log_scope_levels = &.{},
};

comptime {
    // Required to ensure handle_trap is not ignored by lazy evaluation
    _ = riscv.handle_trap;
}

pub const panic = std.debug.FullPanic(lib.panic);

export fn boot() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_setup
        :
        : [stack_top] "r" (lib.segmentation.StackTop),
    );
}

export fn kernel_setup() noreturn {
    @memset(lib.segmentation.Bss[0 .. lib.segmentation.BssEnd - lib.segmentation.Bss], 0);

    libriscv.setTrapHandler();

    kmain() catch |err| {
        lib.serialWriter.print("ERROR: {}\n", .{err}) catch {};
    };

    std.debug.panic("kmain returned", .{});
}

const KAllocator = std.heap.DebugAllocator(.{
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

const Million: usize = 1_000_000;
const TimerDelay = 30 * Million;

fn loop() callconv(.c) noreturn {
    var sstatus = libriscv.Csr.read(.sstatus);
    sstatus.sie = true;
    libriscv.Csr.write(sstatus);

    while (true) {
        const log = std.log.scoped(.loop);
        log.info("On process {d}", .{processes.current.pid});
        log.info("Current time: {d}", .{libriscv.readTime()});
        log.info("=== Going to sleep ===", .{});
        asm volatile ("wfi");
    }
}

pub fn kmain() !void {
    //var gpa_instance = KAllocator{ .backing_allocator = PageAllocator };

    var heap_buffer: [4096 * 32]u8 = undefined;
    var fba_instance = std.heap.FixedBufferAllocator.init(&heap_buffer);
    const gpa = fba_instance.allocator();

    const log = std.log.scoped(.kernel);
    log.info("========== kernel started ==========", .{});

    riscv.printSbiInfo();
    riscv.checkExtensions(&.{
        .Base,
        .ConsolePutchar,
        .ConsoleGetchar,
        .Time,
    });

    try processes.createIdleProcess(gpa);
    processes.current = processes.Idle;
    processes.current.page_table.setActive();
    processes.current.page_table.logMemoryMap();

    // log.warn("shell.bin: size {d} addr {*}", .{ shell.len, shell.ptr });
    //_ = try processes.createUserProcess(shell, gpa);
    _ = try processes.createKernelProcess(&loop, gpa);
    _ = try processes.createKernelProcess(&loop, gpa);

    // Enable interrupts at first switch to U-mode
    var sstatus: libriscv.Csr.Sstatus = libriscv.Csr.read(.sstatus);
    sstatus.spie = true;
    //sstatus.sie = true;
    libriscv.Csr.write(sstatus);

    // Enable all types of interrupts
    const sie = libriscv.Csr.Sie{
        .software = true,
        .timer = true,
        .external = true,
    };
    libriscv.Csr.write(sie);
    log.info("All supervisor interrupts enabled", .{});

    // Set initial timer
    const rdtime = libriscv.readTime();
    libriscv.sbi.setTimer(rdtime + TimerDelay);

    // What I want to do now:
    // - Have an idle process which can be switched to, has low priority (only switched to if no
    //   other is ready, only runs the wfi instruction and waits for the next timer to switch)
    // - Putchar should not busy loop and instead set the process to waiting then switch

    log.info("Initialization done, yielding", .{});
    processes.yield();
}
