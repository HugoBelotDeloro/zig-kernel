const std = @import("std");

pub const StackSize = 8192;

const Self = @This();

const State = enum {
    unused,
    runnable,
};

const SavedRegisters = struct {
    ra: usize,
    s0: usize = 0,
    s1: usize = 0,
    s2: usize = 0,
    s3: usize = 0,
    s4: usize = 0,
    s5: usize = 0,
    s6: usize = 0,
    s7: usize = 0,
    s8: usize = 0,
    s9: usize = 0,
    s10: usize = 0,
    s11: usize = 0,
};

pid: usize,
state: State = .unused,
sp: *u8,
saved_registers: SavedRegisters,
stack: [StackSize]u8,

pub fn init(self: *Self, pid: usize, pc: usize) void {
    self.* = Self{
        .pid = pid,
        .sp = &self.stack[self.stack.len - 1],
        .state = .runnable,
        .saved_registers = SavedRegisters{
            .ra = pc,
        },
        .stack = undefined,
    };
}

pub fn saveContext(self: *Self) void {
    var ra: usize = undefined;
    var s0: usize = undefined;
    var s1: usize = undefined;
    var s2: usize = undefined;
    var s3: usize = undefined;
    var s4: usize = undefined;
    var s5: usize = undefined;
    var s6: usize = undefined;
    var s7: usize = undefined;
    var s8: usize = undefined;
    var s9: usize = undefined;
    var s10: usize = undefined;
    var s11: usize = undefined;
    asm volatile (""
        // Save callee-saved registers only
        : [ra] "={ra}" (ra),
          [s0] "={s0}" (s0),
          [s1] "={s1}" (s1),
          [s2] "={s2}" (s2),
          [s3] "={s3}" (s3),
          [s4] "={s4}" (s4),
          [s5] "={s5}" (s5),
          [s6] "={s6}" (s6),
          [s7] "={s7}" (s7),
          [s8] "={s8}" (s8),
          [s9] "={s9}" (s9),
          [s10] "={s10}" (s10),
          [s11] "={s11}" (s11),
    );
    self.saved_registers = SavedRegisters{
        .ra = ra,
        .s0 = s0,
        .s1 = s1,
        .s2 = s2,
        .s3 = s3,
        .s4 = s4,
        .s5 = s5,
        .s6 = s6,
        .s7 = s7,
        .s8 = s8,
        .s9 = s9,
        .s10 = s10,
        .s11 = s11,
    };
}

pub fn loadContext(self: *Self) void {
    const regs = &self.saved_registers;
    asm volatile (
    // Restore callee-saved registers only
    // Then return
        ""
        :
        : [ra] "{ra}" (regs.ra),
          [s0] "{s0}" (regs.s0),
          [s1] "{s1}" (regs.s1),
          [s2] "{s2}" (regs.s2),
          [s3] "{s3}" (regs.s3),
          [s4] "{s4}" (regs.s4),
          [s5] "{s5}" (regs.s5),
          [s6] "{s6}" (regs.s6),
          [s7] "{s7}" (regs.s7),
          [s8] "{s8}" (regs.s8),
          [s9] "{s9}" (regs.s9),
          [s10] "{s10}" (regs.s10),
          [s11] "{s11}" (regs.s11),
    );
}

pub fn format(
    self: *Self,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    try writer.print("{{Process #{d} sp {x} stack {x} {s}}}", .{ self.pid, @intFromPtr(self.sp), @intFromPtr(&self.stack), @tagName(self.state) });
}
