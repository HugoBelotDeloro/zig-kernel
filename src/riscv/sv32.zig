const std = @import("std");
const root = @import("root");
const lib = root.lib;
const riscv = root.riscv;

const PageSize = riscv.PageSize;
const EntriesPerTable = PageSize / @sizeOf(PageTableEntry);

const isAligned = std.mem.isAligned;

const log = std.log.scoped(.sv32);

pub const Satp = packed struct(u32) {
    /// Physical page number of the root page table
    ppn_0: u10,
    ppn_1: u12,
    /// Address space identifier
    asid: u9,
    mode: enum(u1) {
        bare = 0,
        sv32 = 1,
    },

    pub fn setBare(self: Satp) void {
        self = @bitCast(0);
    }

    pub fn set(self: Satp) void {
        asm volatile ("sfence.vma");
        riscv.csr.writeCsr(.satp, @bitCast(self));
        asm volatile ("sfence.vma");
    }

    pub fn fromPageTable(page_table: PageTable.Ptr) Satp {
        const pt: PhysAddr = @bitCast(@intFromPtr(page_table));
        return .{
            .ppn_0 = pt.ppn_0,
            .ppn_1 = pt.ppn_1,
            .asid = 0,
            .mode = .sv32,
        };
    }
};

/// Sv32 Virtual Address
const VirtAddr = packed struct(u32) {
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
const PhysAddr = packed struct(u32) {
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

/// A PTE is a leaf is r, w and x are clear.
/// If it is non-leaf then u, a and d must be clear.
pub const PageFlags = packed struct(u9) {
    /// Readable page
    r: bool = false,
    /// Writable page.
    /// If set, the page must also be marked as readable.
    w: bool = false,
    /// Executable page
    x: bool = false,
    /// Accessible to user mode
    /// If set, the page can only be accessed for reading and writing by the supervisor if the SUM
    /// bit of sstatus is set.
    /// Regardless of the value of this field or of sstatus, S-mode can never execute code on a page
    /// where this bit is set.
    u: bool = false,
    /// Globally mapped (exists in all address spaces)
    g: bool = false,
    /// Accessed (automatically set to true when the page has been read, written or fetched)
    a: bool = false,
    /// Dirty (automatically set to true when the page has been written)
    d: bool = false,
    /// Reserved for use by the supervisor
    rsw: u2 = 0,

    pub fn from(comptime s: []const u8) PageFlags {
        var flags = PageFlags{};
        comptime var i = 0;
        if (i < s.len and s[i] == 'r') {
            flags.r = true;
            i += 1;
        }
        if (i < s.len and s[i] == 'w') {
            flags.w = true;
            i += 1;
        }
        if (i < s.len and s[i] == 'x') {
            flags.x = true;
            i += 1;
        }
        if (i < s.len and s[i] == 'u') {
            flags.u = true;
            i += 1;
        }
        if (i < s.len and s[i] == 'g') {
            flags.g = true;
            i += 1;
        }
        if (i < s.len and s[i] == 'a') {
            flags.a = true;
            i += 1;
        }
        if (i < s.len and s[i] == 'd') {
            flags.d = true;
            i += 1;
        }

        if (i != s.len) @compileError("Some flags are unknown or in the wrong order: " ++ s);
        return flags;
    }

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

    pub fn nextPage(self: PageTableEntry) !PageTable.Ptr {
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

pub const PageTable = struct {
    entries: [EntriesPerTable]PageTableEntry,

    pub const Ptr = *align(PageSize) PageTable;

    pub fn create(page_alloc: std.mem.Allocator) !*align(PageSize) PageTable {
        const page_table = try page_alloc.alignedAlloc(PageTable, @intCast(PageSize), 1);
        return &page_table.ptr[0];
    }

    pub fn clone(self: *PageTable, page_alloc: std.mem.Allocator) !*align(PageSize) PageTable {
        const page_table = try PageTable.create(page_alloc);
        @memcpy(&page_table.entries, &self.entries);
        return page_table;
    }

    fn mapPageInner(table_1: Ptr, va: VirtAddr, pa: PhysAddr, flags: PageFlags, page_alloc: std.mem.Allocator) !void {
        if (!isAligned(va.to(), PageSize))
            lib.panic("unaligned virtual address {x}", .{va.to()}, @src());

        if (!isAligned(pa.to(), PageSize))
            lib.panic("unaligned physical address {x}", .{pa.to()}, @src());

        const entry_1 = &table_1.entries[va.vpn_1];
        if (!entry_1.v) {
            const page = try PageTable.create(page_alloc);
            const addr = PhysAddr.from(@intFromPtr(page));
            entry_1.init(.{}, addr);
            log.debug("new lv1 PTE: {}", .{entry_1});
        }

        const table_0 = try entry_1.nextPage();
        const entry_0 = &table_0.entries[va.vpn_0];
        entry_0.* = PageTableEntry{ .ppn_0 = pa.ppn_0, .ppn_1 = pa.ppn_1, .v = true, .flags = flags };
        log.debug("new lv2 PTE: {}", .{entry_0});
    }

    pub fn mapPage(self: Ptr, va: u32, pa: u32, flags: PageFlags, page_alloc: std.mem.Allocator) !void {
        return self.mapPageInner(VirtAddr.from(va), PhysAddr.from(pa), flags, page_alloc);
    }

    pub fn mapRange(table_1: Ptr, mem: []u8, base_va: u32, comptime flags: []const u8, page_alloc: std.mem.Allocator) !void {
        var i: usize = 0;
        log.debug("mapping {d} bytes for table {*}", .{ mem.len, table_1 });
        while (i < mem.len) : (i += PageSize) {
            try table_1.mapPage(base_va + i, @intFromPtr(&mem[i]), PageFlags.from(flags), page_alloc);
        }
    }
};

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
