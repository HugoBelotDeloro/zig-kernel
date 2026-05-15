const std = @import("std");

const log = std.log.scoped(.virtio);
const lib = @import("lib.zig");

const MmioRegisterLegacy = @import("virtio/mmio_register_legacy.zig").MmioRegisterLegacy;
const SplitVirtqueue = @import("virtio/split_virtqueue.zig").SplitVirtqueue;

pub const Blk = @import("virtio/Blk.zig");

pub fn init() !void {
    const blk = try Blk.Device.init();

    const blk_req: *Blk.Req = @ptrCast(@alignCast(try lib.allocPages(1)));

    var buf: [Blk.SectorSize]u8 = undefined;
    blk.read_write_disk(&buf, 0, 0, blk_req);
    log.err("Sector: {s}", .{buf});
}
