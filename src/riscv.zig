pub fn putChar(c: u8) void {
    _ = sbiCall(c, 0, 0, 0, 0, 0, 0, 1);
}

pub const Csr = enum {
    scause,
    stval,
    sepc,
    stvec,
};

pub fn readCsr(comptime reg: Csr) usize {
    return asm volatile ("csrr %[ret], " ++ @tagName(reg): [ret] "=r" (-> usize));
}

pub fn writeCsr(comptime reg: Csr, value: usize) void {
    asm volatile ("csrw " ++ @tagName(reg) ++ ", %[val]" :: [val] "r" (value));
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

fn sbiCall(arg0: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize, fid: usize, eid: usize) SbiRet {
    var err: usize = undefined;
    var val: usize = undefined;

    asm volatile ("ecall"
        : [err] "={a0}" (err),
          [val] "={a1}" (val),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (arg3),
          [arg4] "{a4}" (arg4),
          [arg5] "{a5}" (arg5),
          [arg6] "{a6}" (fid),
          [arg7] "{a7}" (eid),
        : "memory"
    );
    return SbiRet{ .err = err, .value = val };
}

const SbiRet = struct {
    err: usize,
    value: usize,
};
