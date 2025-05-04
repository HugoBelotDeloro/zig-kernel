pub const Text = @extern([*]u8, .{ .name = "__text" });
pub const TextEnd = @extern([*]u8, .{ .name = "__text_end" });

pub const Rodata = @extern([*]u8, .{ .name = "__rodata" });
pub const RodataEnd = @extern([*]u8, .{ .name = "__rodata_end" });

pub const Data = @extern([*]u8, .{ .name = "__data" });
pub const DataEnd = @extern([*]u8, .{ .name = "__data_end" });

pub const Bss = @extern([*]u8, .{ .name = "__bss" });
pub const BssEnd = @extern([*]u8, .{ .name = "__bss_end" });

pub const Stack = @extern([*]u8, .{ .name = "__stack" });
pub const StackTop = @extern([*]u8, .{ .name = "__stack_top" });

pub const FreeRam = @extern([*]u8, .{ .name = "__free_ram" });
pub const FreeRamEnd = @extern([*]u8, .{ .name = "__free_ram_end" });
