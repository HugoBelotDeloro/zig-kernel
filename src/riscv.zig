pub fn putChar(c: u8) void {
    _ = sbiCall(c, 0, 0, 0, 0, 0, 0, 1);
}

fn sbiCall(
    arg0: usize,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
    fid: usize,
    eid: usize
) SbiRet
{
    var err: usize = undefined;
    var val: usize = undefined;

    asm volatile (
    "ecall"
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
    : "memory");
    return SbiRet { .err = err, .value = val};
}

const SbiRet = struct {
    err: usize,
    value: usize,
};
