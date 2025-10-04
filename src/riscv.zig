const riscv = @import("riscv");
pub const common = @import("common");
pub const timer = @import("riscv/timer.zig");

const lib = @import("lib.zig");

const std = @import("std");
const log = std.log.scoped(.trap);

const Csr = riscv.Csr;

const handleSyscall = @import("syscall.zig").handleSyscall;

pub export fn handle_trap(f: *riscv.TrapFrame) void {
    const scause: Csr.Scause = Csr.read(.scause);
    const stval: usize = Csr.read(.stval);
    const sepc: usize = Csr.read(.sepc);

    log.info("trap: {} @ {x} from {c}-mode", .{scause, sepc, @as(u8, if (Csr.read(.sstatus).spp == .user)
'U' else 'S')});

    if (scause.caused_by == .exception and scause.code == 8) {

        handleSyscall(f);
        Csr.writeReg(.sepc, sepc + 4);
    } else if (scause.caused_by == .interrupt and scause.code == 5) {
        timer.handleTimer();
    } else {
        lib.panic("unexpected trap scause={x}, stval={x}, sepc={x}\n", .{ scause, stval, sepc }, @src());
    }

    // Reenable interrupts
    var sstatus: Csr.Sstatus = @bitCast(Csr.read(.sstatus));
    sstatus.sie = true;
    Csr.write(sstatus);
}
