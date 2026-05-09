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
            : [ret] "=r" (-> u32),
        );
        const low = asm volatile ("rdtime %[ret]"
            : [ret] "=r" (-> u32),
        );
        if (high == asm volatile ("rdtimeh %[ret]"
            : [ret] "=r" (-> u32),
        ))
            return (@as(u64, @intCast(high)) << 32) + low;
    }
}
