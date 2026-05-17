const std = @import("std");

const log = std.log.scoped(.virtio);
const lib = @import("lib.zig");

const MmioRegisterLegacy = @import("virtio/mmio_register_legacy.zig").MmioRegisterLegacy;
const SplitVirtqueue = @import("virtio/split_virtqueue.zig").SplitVirtqueue;

pub const Blk = @import("virtio/Blk.zig");

pub fn init() !void {
    const blk = try Blk.Device.init();

    var buf: [Blk.SectorSize]u8 = undefined;
    try blk.read_write_disk(&buf, 0, false);
    log.err("Sector: {s}", .{buf});
}
