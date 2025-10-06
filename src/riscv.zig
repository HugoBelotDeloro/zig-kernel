const riscv = @import("riscv");
pub const common = @import("common");
pub const timer = @import("riscv/timer.zig");

const lib = @import("lib.zig");

const std = @import("std");
const log = std.log.scoped(.riscv);

const Csr = riscv.Csr;

const handleSyscall = @import("syscall.zig").handleSyscall;

pub export fn handle_trap(f: *riscv.TrapFrame) void {
    const scause: Csr.Scause = Csr.read(.scause);
    const stval: usize = Csr.read(.stval);
    const sepc: usize = Csr.read(.sepc);

    log.info("trap: {} @ {x} from {c}-mode", .{ scause, sepc, @as(u8, if (Csr.read(.sstatus).spp == .user)
        'U'
    else
        'S') });

    if (scause.caused_by == .exception and scause.code == 8) {
        handleSyscall(f);
        Csr.writeReg(.sepc, sepc + 4);
    } else if (scause.caused_by == .interrupt and scause.code == 5) {
        timer.handleTimer();
    } else {
        std.debug.panic("unexpected trap scause={x}, stval={x}, sepc={x}\n", .{ scause, stval, sepc });
    }

    // Reenable interrupts
    var sstatus: Csr.Sstatus = @bitCast(Csr.read(.sstatus));
    sstatus.sie = true;
    Csr.write(sstatus);
}

pub fn checkExtensions(comptime required_extensions: []const riscv.sbi.Extension) void {
    var missing_ext = false;

    for (std.enums.values(riscv.sbi.Extension)) |ext| {
        if (riscv.sbi.base.probeExtension(ext)) {
            log.debug("Extension enabled: {s}", .{ext.name().?});
        } else {
            log.debug("Extension disabled: {s}", .{ext.name().?});
            for (required_extensions) |required_ext|
                if (required_ext == ext) {
                    missing_ext = true;
                    log.err("Missing extension {s}", .{@tagName(ext)});
                };
        }
    }

    if (missing_ext) std.debug.panic("Missing extension", .{});
}

pub fn printSbiInfo() void {
    log.info("SBI version {x} ({d}/{s} version {x})", .{ riscv.sbi.base.getSpecVersion(), riscv.sbi.base.getImplementationId(), riscv.sbi.base.getImplementationName(), riscv.sbi.base.getImplementationVersion() });
}
