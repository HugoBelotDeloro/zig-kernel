const std = @import("std");
const root = @import("root");
const lib = root.lib;
const riscv = root.riscv;

const PageSize = riscv.PageSize;
const EntriesPerTable = PageSize / @sizeOf(PageTableEntry);

const isAligned = std.mem.isAligned;

const log = std.log.scoped(.sv32);

/// Sv32 Virtual Address
pub const VirtAddr = packed struct(u32) {
    page_offset: u12,
    vpn_0: u10,
    vpn_1: u10,

    pub fn from(addr: usize) VirtAddr {
        return @bitCast(addr);
    }

    pub fn to(self: VirtAddr) usize {
        return @bitCast(self);
    }

    pub fn pageAddress(self: VirtAddr) usize {
        self.to() & ~(PageSize - 1);
    }

    pub fn offset(self: VirtAddr, offset_value: usize) VirtAddr {
        const s: u32 = @bitCast(self);
        return @bitCast(s + offset_value);
    }
};

/// Sv32 Physical Address
pub const PhysAddr = packed struct(u32) {
    page_offset: u12,
    ppn_0: u10,
    ppn_1: u10,

    pub fn from(addr: u32) PhysAddr {
        return @bitCast(addr);
    }

    pub fn to(self: PhysAddr) u32 {
        return @bitCast(self);
    }

    pub fn pageAddress(self: PhysAddr) u32 {
        self.to() & ~(PageSize - 1);
    }

    pub fn offset(self: PhysAddr, offset_value: usize) PhysAddr {
        const s: u32 = @bitCast(self);
        return @bitCast(s + offset_value);
    }
};

pub const PageFlags = packed struct(u9) {
    /// Readable page
    r: bool = false,
    /// Writable page
    w: bool = false,
    /// Executable page
    x: bool = false,
    /// Accessible to user mode
    u: bool = false,
    /// Globally mapped (exists in all address spaces)
    g: bool = false,
    /// Accessed (automatically set to true when the page has been read, written or fetched)
    a: bool = false,
    /// Dirty (automatically set to true when the page has been written)
    d: bool = false,
    /// Reserved for use by the supervisor
    rsw: u2 = 0,

    pub const Rwx = PageFlags{
        .r = true,
        .w = true,
        .x = true,
    };

    pub fn format(
        self: PageFlags,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        const str = "rwxugad??";
        var repr = str.*;
        const s: u9 = @bitCast(self);
        inline for (0..@bitSizeOf(PageFlags)) |i| {
            if (s & (1 << i) == 0) repr[i] = '-';
        }
        _ = try writer.write(&repr);
    }
};

/// An entry in a page table.
/// It can contain either the physical address of the next page table,
/// or the physical address of a page.
pub const PageTableEntry = packed struct(u32) {
    /// Whether the entry is valid
    v: bool = false,
    flags: PageFlags = .{},
    ppn_0: u10,
    ppn_1: u12,

    pub fn init(self: *PageTableEntry, flags: PageFlags, addr: PhysAddr) void {
        self.* = .{
            .v = true,
            .flags = flags,
            .ppn_0 = addr.ppn_0,
            .ppn_1 = addr.ppn_1,
        };
    }

    pub fn address(self: PageTableEntry) u32 {
        return @bitCast(PhysAddr{ .ppn_1 = @truncate(self.ppn_1), .ppn_0 = self.ppn_0, .page_offset = 0 });
    }

    pub fn nextPage(self: PageTableEntry) ![*]PageTableEntry {
        if (self.flags.r or self.flags.w or self.flags.x)
            return error.LeafPage;
        return @ptrFromInt(self.address());
    }

    pub fn format(
        self: PageTableEntry,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("SV32PTE{{ *{x}, {}}}", .{ self.address(), self.flags });
    }
};

pub const PageTable = [EntriesPerTable]PageTableEntry;
pub const PageTablePtr = *align(PageSize) PageTable;

pub fn createPageTable(alloc: std.mem.Allocator) !PageTablePtr {
    const page_table = try alloc.alignedAlloc(PageTable, @intCast(PageSize), 1);
    return &page_table.ptr[0];
}

pub fn mapPage(table_1: PageTablePtr, va: VirtAddr, pa: PhysAddr, flags: PageFlags, alloc: std.mem.Allocator) !void {
    if (!isAligned(va.to(), PageSize))
        lib.panic("unaligned virtual address {x}", .{va.to()}, @src());

    if (!isAligned(pa.to(), PageSize))
        lib.panic("unaligned physical address {x}", .{pa.to()}, @src());

    const vpn_1 = va.vpn_1;
    if (!table_1[vpn_1].v) {
        const page = try createPageTable(alloc);
        const addr = PhysAddr.from(@intFromPtr(page));
        table_1[vpn_1].init(.{}, addr);
        log.debug("new lv1 PTE: {}", .{table_1[vpn_1]});
    }

    const table_0 = try table_1[vpn_1].nextPage();
    const vpn_0 = va.vpn_0;
    table_0[vpn_0] = PageTableEntry{ .ppn_0 = pa.ppn_0, .ppn_1 = pa.ppn_1, .v = true, .flags = flags };
    log.debug("new lv2 PTE: {}", .{table_0[vpn_0]});
}

pub fn mapRange(table_1: PageTablePtr, len: usize, base_va: VirtAddr, base_pa: PhysAddr, flags: PageFlags, alloc: std.mem.Allocator) !void {
    var i: usize = 0;
    log.info("mapping {d} pages for page {*}", .{ len, table_1 });
    while (i < len) : (i += 1) {
        const va = base_va.offset(PageSize * i);
        const pa = base_pa.offset(PageSize * i);
        try mapPage(table_1, va, pa, flags, alloc);
    }
}

const t = std.testing;

test "physical addresses are built correctly" {
    const pa_n: u32 = 0x12345678;
    const pa: PhysAddr = @bitCast(pa_n);
    try t.expectEqual(pa.ppn_1, 0x48);
    try t.expectEqual(pa.ppn_0, 0x345);
    try t.expectEqual(pa.page_offset, 0x678);
}

test "virtual addresses are built correctly" {
    const va_n: u32 = 0x12345678;
    const va: VirtAddr = @bitCast(va_n);
    try t.expectEqual(va.vpn_1, 0x48);
    try t.expectEqual(va.vpn_0, 0x345);
    try t.expectEqual(va.page_offset, 0x678);
}

test "page flags representation" {
    const flags = PageFlags.Rwx;
    var b: [@bitSizeOf(PageFlags)]u8 = undefined;
    const s = try std.fmt.bufPrint(&b, "{}", .{flags});
    try t.expectEqualSlices(u8, "rwx------", s);
}

test "page table entries can store and retrieve addresses" {
    const addr = PhysAddr.from(0x12345678).pageAddress();
    var pte: PageTableEntry = undefined;
    pte.init(.{}, PhysAddr.from(addr));
    try t.expectEqual(addr, pte.address());
}
