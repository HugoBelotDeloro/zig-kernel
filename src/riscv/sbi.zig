pub const base = @import("sbi/base.zig");

pub fn putChar(c: u8) void {
    _ = sbiCall6(c, 0, 0, 0, 0, 0, 0, 1);
}

pub fn getChar() isize {
    return @bitCast(sbiCall6(0, 0, 0, 0, 0, 0, 0, 2).err);
}

pub fn setTimer(time: usize) void {
    _ = sbiCall6(time, 0, 0, 0, 0, 0, 0, 0x5449_4D45);
}

pub const SbiRet = struct {
    err: usize,
    value: usize,
};

pub const Extensions = enum(usize) {
    SetTimer = 0x00,
    ConsolePutchar = 0x01,
    ConsoleGetchar = 0x02,
    ClearIpi = 0x03,
    SendIpi = 0x04,
    RemoteFenceI = 0x05,
    RemoteSfenceVma = 0x06,
    RemoteSfenceVmaAsid = 0x07,
    Shutdown = 0x08,
    Base = 0x10,
    Hsm = 0x48534D,
    Pmu = 0x504D55,
    Sse = 0x535345,
    Sta = 0x535441,
    Ipi = 0x735049,
    Cppc = 0x43505043,
    Dbcn = 0x4442434E,
    Dbtr = 0x44425452,
    Fwft = 0x46574654,
    Mpxy = 0x4D505859,
    Nacl = 0x4E41434C,
    Rfnc = 0x52464E43,
    Srst = 0x53525354,
    Susp = 0x53555350,
    Time = 0x54494D45,
};

const ExtensionNameType = @import("std").EnumArray(Extensions, []const u8);
const ExtensionNames = ExtensionNameType.init(.{
    .SetTimer = "Set Timer",
    .ConsolePutchar = "Console Putchar",
    .ConsoleGetchar = "Console Getchar",
    .ClearIpi = "Clear IPI",
    .SendIpi = "Send IPI",
    .RemoteFenceI = "Remote FENCE.I",
    .RemoteSfenceVma = "Remote SFENCE.VMA",
    .RemoteSfenceVmaAsid = "Remote SFENCE.VMA with ASID",
    .Shutdown = "System Shutdown",
    .Base = "Base",
    .Hsm = "Hart State Management",
    .Pmu = "Performance Monitoring Unit",
    .Sse = "Supervisor Software Events",
    .Sta = "Steal-time Accounting Extension",
    .Ipi = "IPI",
    .Cppc = "CPPC",
    .Dbcn = "Debug Console",
    .Dbtr = "Debug Triggers",
    .Fwft = "SBI Firmware Features",
    .Mpxy = "Message Proxy",
    .Nacl = "Nested Acceleration",
    .Rfnc = "RFENCE",
    .Srst = "System Reset Extension",
    .Susp = "System Suspend",
    .Time = "Timer",
});

pub fn getExtensionName(eid: usize) []const u8 {
    const e = @import("std").meta.intToEnum(Extensions, eid) catch return "Unknown";
    return ExtensionNames.get(e);
}


pub fn sbiCall0(fid: usize, eid: usize) SbiRet {
    var err: usize = undefined;
    var val: usize = undefined;

    asm volatile ("ecall"
        : [err] "={a0}" (err),
          [val] "={a1}" (val),
        : [arg6] "{a6}" (fid),
          [arg7] "{a7}" (eid),
        : "memory"
    );
    return SbiRet{ .err = err, .value = val };
}

pub fn sbiCall1(arg0: usize, fid: usize, eid: usize) SbiRet {
    var err: usize = undefined;
    var val: usize = undefined;

    asm volatile ("ecall"
        : [err] "={a0}" (err),
          [val] "={a1}" (val),
        : [arg0] "{a0}" (arg0),
          [arg6] "{a6}" (fid),
          [arg7] "{a7}" (eid),
        : "memory"
    );
    return SbiRet{ .err = err, .value = val };
}

pub fn sbiCall6(arg0: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize, fid: usize, eid: usize) SbiRet {
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
