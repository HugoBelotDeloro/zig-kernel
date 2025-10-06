pub const sbi = @import("sbi.zig");
pub const sv32 = @import("sv32.zig");

pub const PageSize = 4096;

pub const Csr = @import("csr.zig").Csr;

const trap = @import("trap.zig");
pub const TrapFrame = trap.TrapFrame;
pub const setTrapHandler = trap.setTrapHandler;

pub fn readTime() u64 {
    while (true) {
        const high = asm volatile ("rdtimeh %[ret]"
            : [ret] "=r" (-> u64),
        );
        const low = asm volatile ("rdtime %[ret]"
            : [ret] "=r" (-> usize),
        );
        if (high == asm volatile ("rdtimeh %[ret]"
            : [ret] "=r" (-> u64),
        ))
            return (high << 32) + low;
    }
}
