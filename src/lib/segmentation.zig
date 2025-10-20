const std = @import("std");
const riscv = @import("riscv");
const PageTable = riscv.sv32.PageTable;
const log = std.log.scoped(.segmentation);

const Text = @extern([*]u8, .{ .name = "__text" });
const TextEnd = @extern([*]u8, .{ .name = "__text_end" });

const Rodata = @extern([*]u8, .{ .name = "__rodata" });
const RodataEnd = @extern([*]u8, .{ .name = "__rodata_end" });

const Sdata = @extern([*]u8, .{ .name = "__sdata" });
const SdataEnd = @extern([*]u8, .{ .name = "__sdata_end" });

const Data = @extern([*]u8, .{ .name = "__data" });
const DataEnd = @extern([*]u8, .{ .name = "__data_end" });

pub const Bss = @extern([*]u8, .{ .name = "__bss" });
pub const BssEnd = @extern([*]u8, .{ .name = "__bss_end" });

const Stack = @extern([*]u8, .{ .name = "__stack_bottom" });
pub const StackTop = @extern([*]u8, .{ .name = "__stack_top" });

pub const FreeRam = @extern([*]u8, .{ .name = "__free_ram" });
pub const FreeRamEnd = @extern([*]u8, .{ .name = "__free_ram_end" });

pub fn mapKernel(page_alloc: std.mem.Allocator) !*align(riscv.PageSize) PageTable {
    const sections = .{
        .{ .name = "Text", .start = Text, .end = TextEnd, .flags = "rx" },
        .{ .name = "Rodata", .start = Rodata, .end = RodataEnd, .flags = "r" },
        .{ .name = "Sdata", .start = Sdata, .end = SdataEnd, .flags = "rw" },
        .{ .name = "Data", .start = Data, .end = DataEnd, .flags = "rw" },
        .{ .name = "Bss", .start = Bss, .end = BssEnd, .flags = "rw" },
        .{ .name = "Stack", .start = Stack, .end = StackTop, .flags = "rw" },
        .{ .name = "FreeRam", .start = FreeRam, .end = FreeRamEnd, .flags = "rw" },
    };

    var page_table = try PageTable.create(page_alloc);
    inline for (sections) |section| {
        log.info("{s:<7} = {x}-{x} ({d} bytes)", .{ section.name, @intFromPtr(section.start), @intFromPtr(section.end), section.end - section.start });
        try page_table.mapRange(section.start[0 .. section.end - section.start], @intFromPtr(section.start), section.flags, page_alloc);
    }
    return page_table;
}
