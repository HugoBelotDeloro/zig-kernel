const root = @import("root");
const std = @import("std");
const serialWriter = root.lib.serialWriter;

pub const Csr = enum {
    scause,
    sstatus,
    stval,
    sepc,
    stvec,
    satp,
    time,
    sie,
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

pub const Scause = packed struct(u32) {
    code: u31,
    caused_by: enum(u1) {
        exception = 0,
        interrupt = 1,
    },

    pub fn format(
        self: Scause,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        const bytes: u32 = @bitCast(self);

        try writer.print("{x}({s} {s})", .{ bytes, @tagName(self.caused_by), switch (self.caused_by) {
            .interrupt => switch (self.code) {
                1 => "Supervisor software interrupt",
                5 => "Supervisor timer interrupt",
                9 => "Supervisor external interrupt",
                0, 2...4, 6...8, 10...15 => "Reserved interrupt",
                else => "Designated for platform use",
            },
            .exception => switch (self.code) {
                0 => "Instruction address misaligned",
                1 => "Instruction access fault",
                2 => "Illegal instruction",
                3 => "Breakpoint",
                4 => "Load address misaligned",
                5 => "Load access fault",
                6 => "Store/AMO address misaligned",
                7 => "Store/AMO access fault",
                8 => "Environment call from U-mode",
                9 => "Environment call from S-mode",
                12 => "Instruction page fault",
                13 => "Load page fault",
                15 => "Store/AMO page fault",
                24...31, 48...63 => "Designated for custom use",
                else => "Reserved exception",
            },
        } });
    }
};

// Superviser Interrupt Enable
// Determines which kinds of interrupts are
pub const Sie = packed struct(u32) {
    _reserved1: u1 = 0,
    software: bool = true,
    _reserved2: u3 = 0,
    timer: bool = true,
    _reserved3: u3 = 0,
    external: bool = true,
    _reserved4: u6 = 0,
    _custom: u16 = 0,
};

pub const Sstatus = packed struct(u32) {
    _wpri6: u1 = 0,
    /// Determines if interrupts are enabled in S-mode.
    sie: bool = false,
    _wpri5: u3 = 0,
    /// Whether interrupts were enabled prior to trapping into S-mode.
    spie: bool = false,
    /// Endianness of explicit memory accesses in U-mode.
    ube: enum(u1) {
        little = 0,
        big = 1,
    } = .little,
    /// Privilege level before entering S-mode.
    /// The level is restored when returning from the trap.
    _wpri4: u1 = 0,
    spp: enum(u1) {
        user = 0,
        supervisor = 1,
    } = .user,
    vs: u2 = 0,
    _wpri3: u2 = 0,
    fs: u2 = 0,
    xs: u2 = 0,
    _wpri2: u1 = 0,
    /// Supervisor User Memory access.
    /// Whether S-mode is allowed access to U-mode pages.
    sum: bool = false,
    /// Make eXecutable Readable.
    /// Whether pages marked executable but not readable can be accessed in virtual memory.
    /// No effect when virtual memory is disabled.
    mxr: bool = false,
    _wpri1: u11 = 0,
    sd: bool = false,
};
