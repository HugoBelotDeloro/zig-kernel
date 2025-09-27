pub const Csr = @import("riscv/csr.zig").Csr;
pub const sv32 = @import("riscv/sv32.zig");
pub const common = @import("common");
pub const sbi = @import("riscv/sbi.zig");
pub const timer = @import("riscv/timer.zig");

const lib = @import("lib.zig");

const std = @import("std");
const log = std.log.scoped(.trap);

pub const PageSize = 4096;

const handleSyscall = @import("syscall.zig").handleSyscall;

pub fn setTrapHandler() void {
    const entry_addr: usize = @intFromPtr(&kernel_entry);
    Csr.writeReg(.stvec, entry_addr);
    log.info("set trap handler to {x}", .{entry_addr});
}

pub const TrapFrame = extern struct {
    ra: usize,
    gp: usize,
    tp: usize,
    t0: usize,
    t1: usize,
    t2: usize,
    t3: usize,
    t4: usize,
    t5: usize,
    t6: usize,
    a0: usize,
    a1: usize,
    a2: usize,
    a3: usize,
    a4: usize,
    a5: usize,
    a6: usize,
    a7: usize,
    s0: usize,
    s1: usize,
    s2: usize,
    s3: usize,
    s4: usize,
    s5: usize,
    s6: usize,
    s7: usize,
    s8: usize,
    s9: usize,
    s10: usize,
    s11: usize,
    sp: usize,
};

export fn kernel_entry() align(4) callconv(.Naked) void {
    asm volatile (
    // Swap the stack pointer with the one stored in sscratch
        \\csrrw sp, sscratch, sp
        \\addi sp, sp, -4 * 31
        \\sw ra,  4 * 0(sp)
        \\sw gp,  4 * 1(sp)
        \\sw tp,  4 * 2(sp)
        \\sw t0,  4 * 3(sp)
        \\sw t1,  4 * 4(sp)
        \\sw t2,  4 * 5(sp)
        \\sw t3,  4 * 6(sp)
        \\sw t4,  4 * 7(sp)
        \\sw t5,  4 * 8(sp)
        \\sw t6,  4 * 9(sp)
        \\sw a0,  4 * 10(sp)
        \\sw a1,  4 * 11(sp)
        \\sw a2,  4 * 12(sp)
        \\sw a3,  4 * 13(sp)
        \\sw a4,  4 * 14(sp)
        \\sw a5,  4 * 15(sp)
        \\sw a6,  4 * 16(sp)
        \\sw a7,  4 * 17(sp)
        \\sw s0,  4 * 18(sp)
        \\sw s1,  4 * 19(sp)
        \\sw s2,  4 * 20(sp)
        \\sw s3,  4 * 21(sp)
        \\sw s4,  4 * 22(sp)
        \\sw s5,  4 * 23(sp)
        \\sw s6,  4 * 24(sp)
        \\sw s7,  4 * 25(sp)
        \\sw s8,  4 * 26(sp)
        \\sw s9,  4 * 27(sp)
        \\sw s10, 4 * 28(sp)
        \\sw s11, 4 * 29(sp)

        // Retrieve and save the stack pointer at time of exception
        \\csrr a0, sscratch
        \\sw a0, 4 * 30(sp)

        // Reset the kernel stack
        \\addi a0, sp, 4 * 31
        \\csrw sscratch, a0
        \\mv a0, sp
        \\call handle_trap
        \\lw ra,  4 * 0(sp)
        \\lw gp,  4 * 1(sp)
        \\lw tp,  4 * 2(sp)
        \\lw t0,  4 * 3(sp)
        \\lw t1,  4 * 4(sp)
        \\lw t2,  4 * 5(sp)
        \\lw t3,  4 * 6(sp)
        \\lw t4,  4 * 7(sp)
        \\lw t5,  4 * 8(sp)
        \\lw t6,  4 * 9(sp)
        \\lw a0,  4 * 10(sp)
        \\lw a1,  4 * 11(sp)
        \\lw a2,  4 * 12(sp)
        \\lw a3,  4 * 13(sp)
        \\lw a4,  4 * 14(sp)
        \\lw a5,  4 * 15(sp)
        \\lw a6,  4 * 16(sp)
        \\lw a7,  4 * 17(sp)
        \\lw s0,  4 * 18(sp)
        \\lw s1,  4 * 19(sp)
        \\lw s2,  4 * 20(sp)
        \\lw s3,  4 * 21(sp)
        \\lw s4,  4 * 22(sp)
        \\lw s5,  4 * 23(sp)
        \\lw s6,  4 * 24(sp)
        \\lw s7,  4 * 25(sp)
        \\lw s8,  4 * 26(sp)
        \\lw s9,  4 * 27(sp)
        \\lw s10, 4 * 28(sp)
        \\lw s11, 4 * 29(sp)
        \\lw sp,  4 * 30(sp)
        \\sret
    );
}

export fn handle_trap(f: *TrapFrame) void {
    const scause: Csr.Scause = Csr.read(.scause);
    const stval: usize = Csr.read(.stval);
    const user_pc: usize = Csr.read(.sepc);

    if (scause.caused_by == .exception and scause.code == 8) {
        // Reenable interrupts
        var sstatus: Csr.Sstatus = @bitCast(Csr.read(.sstatus));
        sstatus.sie = true;
        Csr.write(sstatus);

        handleSyscall(f);
        Csr.writeReg(.sepc, user_pc + 4);
    } else if (scause.caused_by == .interrupt and scause.code == 5) {
        timer.handleTimer();
    } else {
        lib.panic("unexpected trap scause={x}, stval={x}, sepc={x}\n", .{ scause, stval, user_pc }, @src());
    }
}

pub fn readTime() u64 {
    const high_1: u64 = @intCast(asm volatile ("rdtimeh %[ret]"
        : [ret] "=r" (-> usize),
    ));
    const low = asm volatile ("rdtime %[ret]"
        : [ret] "=r" (-> usize),
    );
    const high_2: u64 = @intCast(asm volatile ("rdtimeh %[ret]"
        : [ret] "=r" (-> usize),
    ));
    if (high_1 == high_2) return (high_1 << 32) + low else return readTime();
}
