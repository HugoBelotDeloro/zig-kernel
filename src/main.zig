pub const lib = @import("lib.zig");
pub const libriscv = @import("riscv");
const std = @import("std");
const processes = @import("processes.zig");
const Process = @import("Process.zig");

pub const riscv = @import("riscv.zig");

const PageSize = libriscv.PageSize;

const shell = @embedFile("shell.bin");

pub const std_options = std.Options{
    .page_size_max = PageSize,
    .page_size_min = PageSize,
    .logFn = lib.logFn,
    .log_level = .info,
    .log_scope_levels = &.{},
};

export fn boot() linksection(".text.boot") callconv(.Naked) noreturn {
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

const Million: usize = 1_000_000;
const TimerDelay = 30 * Million;

fn loop() noreturn {
    var sstatus = libriscv.Csr.read(.sstatus);
    sstatus.sie = true;
    libriscv.Csr.write(sstatus);
    while (true) {
        std.log.info("On process {d}", .{processes.current.pid});
        std.log.info("sstatus {}", .{libriscv.Csr.read(.sstatus)});
        asm volatile ("wfi");
    }
}

pub fn kmain() !void {
    var gpa_instance = KAllocator{ .backing_allocator = PageAllocator };
    const gpa = gpa_instance.allocator();

    const log = std.log.scoped(.kernel);
    log.debug("kernel started", .{});

    log.info("SBI version {d} ({d}/{s} version {d})", .{ libriscv.sbi.base.getSpecVersion(), libriscv.sbi.base.getImplementationId(), libriscv.sbi.base.getImplementationName(), libriscv.sbi.base.getImplementationVersion() });

    for (std.enums.values(libriscv.sbi.Extension)) |ext| {
        if (libriscv.sbi.base.probeExtension(ext)) {
            log.info("Extension enabled: {s}", .{ext.name().?});
        } else {
            log.info("Extension disabled: {s}", .{ext.name().?});
        }
    }

    try processes.createIdleProcess(gpa);
    processes.current = processes.Idle;

    // log.warn("shell.bin: size {d} addr {*}", .{ shell.len, shell.ptr });
    //_ = try processes.createUserProcess(shell, gpa);
    _ = try processes.createKernelProcess(&loop, gpa);
    _ = try processes.createKernelProcess(&loop, gpa);

    // Enable interrupts at first switch to U-mode
    var sstatus: libriscv.Csr.Sstatus = libriscv.Csr.read(.sstatus);
    sstatus.spie = true;
    sstatus.sie = true;
    libriscv.Csr.write(sstatus);

    // Enable all types of interrupts
    const sie = libriscv.Csr.Sie{
        .software = true,
        .timer = true,
        .external = true,
    };
    libriscv.Csr.write(sie);
    log.warn("sie: {}", .{libriscv.Csr.read(.sie)});

    // Set initial timer
    const rdtime = libriscv.readTime();
    libriscv.sbi.time.setTimer(rdtime + TimerDelay);

    // What I want to do now:
    // - Have an idle process which can be switched to, has low priority (only switched to if no
    //   other is ready, only runs the wfi instruction and waits for the next timer to switch)
    // - Putchar should not busy loop and instead set the process to waiting then switch

    processes.yield();
}
