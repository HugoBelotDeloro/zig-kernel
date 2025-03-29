pub const Csr = enum {
    scause,
    stval,
    sepc,
    stvec,
    satp,
};

pub fn readCsr(comptime reg: Csr) usize {
    return asm volatile ("csrr %[ret], " ++ @tagName(reg)
        : [ret] "=r" (-> usize),
    );
}

pub fn writeCsr(comptime reg: Csr, value: usize) void {
    asm volatile ("csrw " ++ @tagName(reg) ++ ", %[val]"
        :
        : [val] "r" (value),
    );
}
