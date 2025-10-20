const std = @import("std");
const riscv = @import("riscv");
const PageTable = riscv.sv32.PageTable;
const log = std.log.scoped(.segmentation);

const Text = @extern([*]u8, .{ .name = "__text" });
const TextEnd = @extern([*]u8, .{ .name = "__text_end" });

const Rodata = @extern([*]u8, .{ .name = "__rodata" });
const RodataEnd = @extern([*]u8, .{ .name = "__rodata_end" });

const Data = @extern([*]u8, .{ .name = "__data" });
const DataEnd = @extern([*]u8, .{ .name = "__data_end" });

pub const Bss = @extern([*]u8, .{ .name = "__bss" });
pub const BssEnd = @extern([*]u8, .{ .name = "__bss_end" });

const Stack = @extern([*]u8, .{ .name = "__stack_bottom" });
pub const StackTop = @extern([*]u8, .{ .name = "__stack_top" });

pub const FreeRam = @extern([*]u8, .{ .name = "__free_ram" });
pub const FreeRamEnd = @extern([*]u8, .{ .name = "__free_ram_end" });

pub fn mapKernel(page_alloc: std.mem.Allocator) !*align(riscv.PageSize) PageTable {
    var page_table = try PageTable.create(page_alloc);
    log.info("Text: {*}-{*}", .{Text, TextEnd});
    try page_table.mapRange(Text[0 .. TextEnd - Text], @intFromPtr(Text), "rx", page_alloc);
    log.info("Rodata: {*}-{*}", .{Rodata, RodataEnd});
    try page_table.mapRange(Rodata[0 .. RodataEnd - Rodata], @intFromPtr(Rodata), "r", page_alloc);
    log.info("Data: {*}-{*}", .{Data, DataEnd});
    try page_table.mapRange(Data[0 .. DataEnd - Data], @intFromPtr(Data), "rw", page_alloc);
    log.info("Bss: {*}-{*}", .{Bss, BssEnd});
    try page_table.mapRange(Bss[0 .. BssEnd - Bss], @intFromPtr(Bss), "rw", page_alloc);
    log.info("Stack: {*}-{*}", .{Stack, StackTop});
    try page_table.mapRange(Stack[0 .. StackTop - Stack], @intFromPtr(Stack), "rw", page_alloc);
    log.info("FreeRam: {*}-{*}", .{FreeRam, FreeRamEnd});
    try page_table.mapRange(FreeRam[0 .. FreeRamEnd - FreeRam], @intFromPtr(FreeRam), "rw", page_alloc);
    return page_table;
}
