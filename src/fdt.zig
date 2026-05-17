const std = @import("std");

const log = std.log.scoped(.fdt);

pub const FdtHeader = extern struct {
    const Magic = 0xd00dfeed;

    magic: u32,
    /// Total size of the DTB.
    total_size: u32,
    /// Offset of the structure block from the beginning of the header.
    off_dt_struct: u32,
    /// Offset of the strings block from the beginning of the header.
    off_dt_strings: u32,
    /// Offset of the memory reservation block from the beginning of the header.
    off_mem_rsvmap: u32,
    /// Version of the DTB.
    /// Supported is 17.
    version: u32,
    /// Lowest version of the DTB with which the version is compatible.
    /// Should be 16.
    last_comp_version: u32,
    /// Physical ID of the boot CPU.
    boot_cpuid_phys: u32,
    /// Size of the strings block section.
    size_dt_strings: u32,
    /// Size of the structure block section.
    size_dt_struct: u32,

    pub fn parse(addr: u32) void {
        const big_endian_header: *FdtHeader = @ptrFromInt(addr);

        var header: FdtHeader = undefined;
        inline for (@typeInfo(FdtHeader).@"struct".fields) |field| {
            @field(header, field.name) = @byteSwap(@field(big_endian_header, field.name));
        }

        if (header.magic == Magic) log.info("Magic ok", .{});

        const rsv_maps: [*]ReserveEntry = @ptrFromInt(addr + header.off_mem_rsvmap);
        var i: usize = 0;
        while (rsv_maps[i].address != 0 and rsv_maps[i].size != 0) : (i += 1) {
            log.info("Reserved area: 0x{x}-0x{x} ({d} bytes)", .{ rsv_maps[i].address, rsv_maps[i].address + rsv_maps[i].size, rsv_maps[i].size });
        }

        i = addr + header.off_dt_struct;
        const strings = addr + header.off_dt_strings;

        var depth: usize = 0;
        while (i < addr + header.off_dt_struct + header.size_dt_struct) {
            const tok_be: *u32 = @ptrFromInt(i);
            i += @sizeOf(TokenType);
            const tok: TokenType = @enumFromInt(@byteSwap(tok_be.*));
            switch (tok) {
                .BeginNode => {
                    depth += 1;

                    var j: usize = 0;
                    while (@as(*u8, @ptrFromInt(i + j)).* != 0) : (j += 1) {}
                    const name: [*]const u8 = @ptrFromInt(i);
                    log.info("node: '{s}'", .{name[0..j]});
                    i = i + j + 1;
                },
                .EndNode => depth -= 1,
                .Prop => {
                    const prop_be: *Property = @ptrFromInt(i);
                    const prop = Property{
                        .len = @byteSwap(prop_be.len),
                        .name_offset = @byteSwap(prop_be.name_offset),
                    };
                    const name: [*:0]const u8 = @ptrFromInt(strings + prop.name_offset);
                    i += @sizeOf(Property);

                    var j: usize = 0;
                    while (@as(*u8, @ptrFromInt(i + j)).* != 0) : (j += 1) {}
                    const value: [*]const u8 = @ptrFromInt(i);
                    log.info("\t'{s}': '{s}'", .{ name, value[0..prop.len] });
                    i = i + prop.len;
                },
                .Nop => {},
                .End => {
                    if (i != addr + header.off_dt_struct + header.size_dt_struct) {
                        log.warn("structure section ends before the reserved space", .{});
                    }
                    break;
                },
            }
            i = std.mem.alignForward(u32, i, @sizeOf(u32));
        }
    }
};

const ReserveEntry = extern struct {
    address: u64,
    size: u64,
};

const TokenType = enum(u32) {
    BeginNode = 1,
    EndNode = 2,
    Prop = 3,
    Nop = 4,
    End = 9,
};

const Property = extern struct {
    len: u32,
    name_offset: u32,
};
