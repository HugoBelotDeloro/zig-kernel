const std = @import("std");

const log = std.log.scoped(.virtio);
const lib = @import("lib.zig");

const SectorSize: u32 = 512;

const MagicValue: u32 = 0x74726976;

const MmioRegisterLegacy = @import("virtio/mmio_register_legacy.zig").MmioRegisterLegacy;
const SplitVirtqueue = @import("virtio/split_virtqueue.zig").SplitVirtqueue;

pub const Blk = @import("virtio/Blk.zig");
const DeviceStatus = packed struct(u32) {
    acknowledge: bool = false,
    driver: bool = false,
    driver_ok: bool = false,
    features_ok: bool = false,
    _unused1: u2 = 0,
    device_needs_reset: bool = false,
    failed: bool = false,
    _unused2: u24 = 0,

    pub fn reset() void {
        MmioRegisterLegacy.status.write(@bitCast(DeviceStatus{}));
    }

    pub fn set_bits(self: DeviceStatus) void {
        const current = MmioRegisterLegacy.status.read();
        MmioRegisterLegacy.status.write(@as(u32, @bitCast(self)) | current);
    }

    pub fn read() DeviceStatus {
        return @bitCast(MmioRegisterLegacy.status.read());
    }
};

pub fn init() !void {
    if (MmioRegisterLegacy.magic_value.read() != 0x74726976)
        std.debug.panic("wrong magic number", .{});
    log.info("magic ok", .{});

    if (MmioRegisterLegacy.version.read() != 1)
        std.debug.panic("wrong version", .{});
    log.info("version ok", .{});

    if (MmioRegisterLegacy.device_id.read() != 2)
        std.debug.panic("wrong device id", .{});
    log.info("device id ok", .{});

    DeviceStatus.reset();
    DeviceStatus.set_bits(DeviceStatus{
        .acknowledge = true,
    });
    DeviceStatus.set_bits(DeviceStatus{
        .driver = true,
    });
    DeviceStatus.set_bits(DeviceStatus{
        .features_ok = true,
    });
    if (!DeviceStatus.read().features_ok) {
        log.warn("features refused by device", .{});
        return;
    }
    MmioRegisterLegacy.guest_page_size.write(lib.PageSize);
    const blk_request_vq = try SplitVirtqueue.init(0);
    DeviceStatus.set_bits(DeviceStatus{
        .driver_ok = true,
    });

    const blk_capacity = MmioRegisterLegacy.readConfig(0) * SectorSize;
    log.info("virtio-blk: capacity is {d} bytes", .{blk_capacity});

    const blk_req: *Blk.Req = @ptrCast(@alignCast(try lib.allocPages(1)));

    var buf: [SectorSize]u8 = undefined;
    read_write_disk(blk_request_vq, &buf, 0, 0, blk_capacity, blk_req);
    log.err("After: {s}", .{buf});
}

pub fn read_write_disk(vq: *SplitVirtqueue, buf: []u8, sector: u32, is_write: i32, blk_capacity: u64, blk_req: *Blk.Req) void {
    if (sector >= blk_capacity / SectorSize) {
        log.warn("trying to read/write sector {d}, but capacity is {d}", .{ sector, blk_capacity /
            SectorSize });
        return;
    }

    blk_req.sector = sector;
    blk_req.typ = if (is_write == 1) .Out else .In;
    if (is_write == 1) @memcpy(&blk_req.data, buf[0..SectorSize]);

    vq.descriptors[0].addr = @intFromPtr(blk_req);
    vq.descriptors[0].len = @sizeOf(u32) * 2 + @sizeOf(u64);
    vq.descriptors[0].flags = .{ .next = true };
    vq.descriptors[0].next = 1;

    vq.descriptors[1].addr = @intFromPtr(blk_req) + @offsetOf(Blk.Req, "data");
    vq.descriptors[1].len = SectorSize;
    vq.descriptors[1].flags = .{ .next = true, .device_access = if (is_write == 1) .read_only else .write_only };
    vq.descriptors[1].next = 2;

    vq.descriptors[2].addr = @intFromPtr(blk_req) + @offsetOf(Blk.Req, "status");
    vq.descriptors[2].len = @sizeOf(u8);
    vq.descriptors[2].flags = .{ .device_access = .write_only };

    vq.kick(0);

    while (vq.isBusy()) {}

    if (blk_req.status != .Ok) {
        log.err("failed to read/write sector {d} status {any}", .{ sector, blk_req.status });
        return;
    }

    if (is_write == 0) @memcpy(buf, &blk_req.data);
}
