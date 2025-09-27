pub const lib = @import("lib.zig");
pub const riscv = @import("riscv.zig");
const std = @import("std");
const processes = @import("processes.zig");
const Process = @import("Process.zig");

const PageSize = riscv.PageSize;

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

const Million: usize = 1_000_000;
const TimerDelay = 30 * Million;

fn loop() noreturn {
    var sstatus = riscv.Csr.read(.sstatus);
    sstatus.sie = true;
    riscv.Csr.write(sstatus);
    while (true) {
        std.log.info("On process {d}", .{processes.current.pid});
        std.log.info("sstatus {}", .{riscv.Csr.read(.sstatus)});
        asm volatile ("wfi");
    }
}

pub fn kmain() !void {
    var gpa_instance = KAllocator{ .backing_allocator = PageAllocator };
    const gpa = gpa_instance.allocator();

    const log = std.log.scoped(.kernel);
    log.info("kernel started", .{});

    log.info("SBI version {d} ({d}/{s} version {d})", .{ riscv.sbi.base.getSpecVersion(), riscv.sbi.base.getImplementationId(), riscv.sbi.base.getImplementationName(), riscv.sbi.base.getImplementationVersion() });

    var enabled_extensions = std.enums.EnumArray(
        riscv.sbi.Extension,
        bool,
    ).initFill(false);

    for (std.enums.values(riscv.sbi.Extension)) |ext| {
        if (riscv.sbi.base.probeExtension(@intFromEnum(ext))) {
            enabled_extensions.set(ext, true);
            log.info("Extension enabled: {s}", .{riscv.sbi.getExtensionName(@intFromEnum(ext))});
        } else {
            log.info("Extension disabled: {s}", .{riscv.sbi.getExtensionName(@intFromEnum(ext))});
        }
    }

    try processes.createIdleProcess(gpa);
    processes.current = processes.Idle;

    // log.warn("shell.bin: size {d} addr {*}", .{ shell.len, shell.ptr });
    //_ = try processes.createUserProcess(shell, gpa);
    _ = try processes.createKernelProcess(&loop, gpa);
    //_ = try processes.createKernelProcess(&loop, gpa);

    // Enable interrupts at first switch to U-mode
    var sstatus: riscv.Csr.Sstatus = riscv.Csr.read(.sstatus);
    sstatus.spie = true;
    sstatus.sie = true;
    riscv.Csr.write(sstatus);

    // Enable all types of interrupts
    const sie = riscv.Csr.Sie{
        .software = true,
        .timer = true,
        .external = true,
    };
    riscv.Csr.write(sie);
    log.warn("sie: {}", .{riscv.Csr.read(.sie)});

    // Set initial timer
    const rdtime = riscv.readTime();
    riscv.sbi.time.setTimer(rdtime + TimerDelay);

    // What I want to do now:
    // - Have an idle process which can be switched to, has low priority (only switched to if no
    //   other is ready, only runs the wfi instruction and waits for the next timer to switch)
    // - Putchar should not busy loop and instead set the process to waiting then switch

    processes.yield();
}
