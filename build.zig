const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(std.Target.Query{
        .os_tag = .freestanding,
        .cpu_arch = .riscv32,
        .abi = .none,
    });

    const exe = b.addExecutable(.{
        .name = "kernel.elf",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
        .strip = false,
    });
    exe.entry = .disabled;
    exe.setLinkerScript(b.path("./kernel.ld"));

    b.installArtifact(exe);

    const run_cmd = b.addSystemCommand(&.{"qemu-system-riscv32"});
    run_cmd.addArgs(&.{
        "-machine",   "virt",
        "-bios",      "default",
        "-serial",    "mon:stdio",
        "-nographic", "--no-reboot",
        "-kernel",
    });
    run_cmd.addArtifactArg(exe);

    const debug = b.option(bool, "debug", "Start a debug session") orelse false;
    if (debug) {
        run_cmd.addArgs(&.{ "-s", "-S" });
    }

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the kernel");
    run_step.dependOn(&run_cmd.step);

    const gdb_cmd = b.addSystemCommand(&.{"lldb"});
    gdb_cmd.addArtifactArg(exe);
    gdb_cmd.addArgs(&.{ "-o", "gdb-remote localhost:1234" });
    const debug_step = b.step("debug", "Start an LLDB instance");
    debug_step.dependOn(&gdb_cmd.step);
}
