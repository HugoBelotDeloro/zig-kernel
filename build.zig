const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(std.Target.Query{
        .os_tag = .freestanding,
        .cpu_arch = .riscv32,
        .abi = .none,
    });

    const kernel = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
        .strip = false,
    });

    const shell = b.createModule(.{
        .root_source_file = b.path("user/user.zig"),
        .target = target,
        .optimize = .Debug,
        .strip = false,
    });

    const kernel_only = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = kernel,
    });
    kernel_only.entry = .disabled;
    kernel_only.setLinkerScript(b.path("./kernel.ld"));

    b.installArtifact(kernel_only);

    const shell_elf = b.addExecutable(.{
        .name = "shell.elf",
        .root_module = shell,
    });
    shell_elf.setLinkerScript(b.path("./user.ld"));

    //const shell_bin = b.addObjCopy(shell_elf.getEmittedBin(), .{
    //    .set_section_flags = .{ .section_name = ".bss", .flags = .{ .alloc = true, .contents = true } },
    //    .format = .bin,
    //});
    const shell_bin = b.addSystemCommand(&.{ "llvm-objcopy", "--set-section-flags", ".bss=alloc,contents", "-O", "binary" });
    shell_bin.addArtifactArg(shell_elf);
    const shell_bin_path = shell_bin.addOutputFileArg("shell.bin");

    kernel_only.root_module.addAnonymousImport("shell.bin", .{ .root_source_file = shell_bin_path });

    const run_cmd = b.addSystemCommand(&.{"qemu-system-riscv32"});
    run_cmd.addArgs(&.{
        "-machine",   "virt",
        "-bios",      "default",
        "-serial",    "mon:stdio",
        "-nographic", "--no-reboot",
        "-kernel",
    });
    run_cmd.addArtifactArg(kernel_only);
    run_cmd.step.dependOn(b.getInstallStep());

    const debug = b.option(bool, "debug", "Start a debug session") orelse false;
    if (debug) {
        run_cmd.addArgs(&.{ "-s", "-S" });
    }

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the kernel");
    run_step.dependOn(&run_cmd.step);

    const gdb_cmd = b.addSystemCommand(&.{"lldb"});
    gdb_cmd.addArtifactArg(kernel_only);
    gdb_cmd.addArgs(&.{ "-o", "gdb-remote localhost:1234" });
    const debug_step = b.step("debug", "Start an LLDB instance");
    debug_step.dependOn(&gdb_cmd.step);

    const tests = b.addTest(.{
        .root_module = kernel,
    });
    const run_unit_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_unit_tests.step);
}
