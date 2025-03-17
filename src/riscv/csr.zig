pub const Csr = enum {
    scause,
    stval,
    sepc,
    stvec,
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

pub const Satp = packed struct(u32) {
    /// Physical page number of the root page table
    ppn: u22,
    /// Address space identifier
    asid: u9,
    mode: enum(u1) {
        bare = 0,
        sv32 = 1,
    },

    pub fn setBare(self: Satp) void {
        self = @bitCast(0);
    }
};
