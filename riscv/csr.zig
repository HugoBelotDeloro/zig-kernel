const std = @import("std");

pub const Csr = union(enum) {
    scause: Scause,
    sstatus: Sstatus,
    sie: Sie,
    time: usize,
    stval: usize,
    stvec: usize,
    sepc: usize,
    sip: usize,
    satp: @import("sv32.zig").Satp,

    fn tagOf(comptime reg_type: type) std.meta.Tag(Csr) {
        return switch (reg_type) {
            Scause => .scause,
            Sstatus => .sstatus,
            Sie => .sie,
            @import("sv32.zig").Satp => .satp,
            else => @compileError("Unknown csr type: " ++ @typeName(reg_type)),
        };
    }

    pub fn read(comptime self: std.meta.Tag(Csr)) @FieldType(Csr, @tagName(self)) {
        const v = asm volatile ("csrr %[ret], " ++ @tagName(self)
            : [ret] "=r" (-> usize),
        );
        return @bitCast(v);
    }

    pub inline fn write(self: anytype) void {
        asm volatile ("csrw " ++ @tagName(tagOf(@TypeOf(self))) ++ ", %[val]"
            :
            : [val] "r" (self),
        );
    }

    pub fn writeReg(comptime csr: std.meta.Tag(Csr), value: anytype) void {
        asm volatile ("csrw " ++ @tagName(csr) ++ ", %[val]"
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

            try writer.print("{s} {s} ({x})", .{ switch (self.caused_by) {
                .interrupt => switch (self.code) {
                    1 => "Supervisor software",
                    5 => "Supervisor timer",
                    9 => "Supervisor external",
                    0, 2...4, 6...8, 10...15 => "Reserved",
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
                    24...31, 48...63 => "Custom",
                    else => "Reserved",
                },
            }, @tagName(self.caused_by), bytes });
        }
    };

    /// Superviser Interrupt Enable
    /// Determines which kinds of interrupts are
    pub const Sie = packed struct(u32) {
        _reserved1: u1 = 0,
        software: bool = true,
        _reserved2: u3 = 0,
        timer: bool = true,
        _reserved3: u3 = 0,
        external: bool = true,
        _reserved4: u6 = 0,
        _custom: u16 = 0,

        pub fn format(
            self: Sie,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            try writer.print("{{sw: {s}, tm: {s}, ext: {s}}}", .{
                if (self.software) "enabled" else "disabled",
                if (self.timer) "enabled" else "disabled",
                if (self.external) "enabled" else "disabled",
            });
        }
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
        _wpri4: u1 = 0,
        /// Privilege level before entering S-mode.
        /// The level is restored when returning from the trap.
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

        pub fn format(
            self: Sstatus,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            try writer.print("{{interrupts: {s} (prev {s}), prev privilege: {s}}}", .{
                if (self.sie) "enabled" else "disabled",
                if (self.spie) "enabled" else "disabled",
                @tagName(self.spp),
            });
        }
    };
};
