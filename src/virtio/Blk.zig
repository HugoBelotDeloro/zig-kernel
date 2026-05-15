const std = @import("std");
const lib = @import("../lib.zig");
const SplitVirtqueue = @import("split_virtqueue.zig").SplitVirtqueue;
const MmioRegisterLegacy = @import("mmio_register_legacy.zig").MmioRegisterLegacy;
const virtio = @import("virtio.zig");

const log = std.log.scoped(.virtio_blk);

pub const SectorSize: u32 = 512;
pub const Paddr: [*]align(4096) volatile u32 = @ptrFromInt(0x10001000);
const Self = @This();

blk_capacity: u64,
vq: *SplitVirtqueue,

pub const Device = virtio.Device(@This()){
    .device_id = 2,
    .DeviceFeatures = DeviceFeatures,
    .device_init = init,
};

fn init() virtio.DeviceInitError!Self {
    MmioRegisterLegacy.guest_page_size.write(lib.PageSize);
    const config: *volatile Configuration = @ptrCast(MmioRegisterLegacy.getConfig());
    const self = Self{ .blk_capacity = config.capacity * SectorSize, .vq = try SplitVirtqueue.init(0) };
    return self;
}

pub const Req = extern struct {
    /// Type of the request
    typ: enum(u32) {
        /// Read
        In = 0,
        /// Write
        Out = 1,
        Flush = 4,
        GetId = 8,
        GetLifeTime = 10,
        Discard = 11,
        WriteZeroes = 13,
        SecureErase = 14,
    },
    reserved: u32 = 0,
    /// Offset (multiplied by 512) where the read or write is to occur.
    sector: u64 = 0,
    data: [512]u8,
    /// Result of the operation, written by the device.
    status: enum(u8) {
        Ok = 0,
        IoErr = 1,
        Unsupp = 2,
    },
};

pub const DeviceFeatures = packed struct(u64) {
    /// Device supports request barriers.
    barrier: bool,
    /// Maximum size of any single segment is in size_max.
    size_max: bool,
    /// Maximum number of segments in a request is in seg_max.
    seg_max: bool,
    unused1: u1,
    /// Disk-style geometry specified in geometry.
    geometry: bool,
    /// Device is read-only.
    ro: bool,
    /// Block size of disk is in blk_size.
    blk_size: bool,
    /// Device supports scsi packet commands.
    scsi: bool,
    unused2: u1,
    /// Cache flush command support.
    flush: bool,
    /// Device exports information on optimal I/O alignment.
    topology: bool,
    /// Device can toggle its cache between writeback and writethrough modes.
    config_wce: bool,
    /// Device supports multiqueue.
    mq: bool,
    /// Device can support discard command: bool, maximum discard sectors size in max_discard_sectors and maximum discard segment number in max_discard_seg.
    discard: bool,
    /// Device can support write zeroes command: bool, maximum write zeroes sectors size in max_write_zeroes_sectors and maximum write zeroes segment number in max_write_zeroes_seg.
    write_zeroes: bool,
    /// Device supports providing storage lifetime information.
    lifetime: bool,
    /// Device supports secure erase command: bool, maximum erase sectors count in max_secure_erase_sectors and maximum erase segment number in max_secure_erase_seg.
    secure_erase: bool,
    /// Device is a Zoned Block Device: bool, that is: bool, a device that follows the zoned storage device behavior that is also supported by industry standards such as the T10 Zoned Block Command standard (ZBC r05) or the NVMe(TM) NVM Express Zoned Namespace Command Set Specification 1.1b (ZNS). For brevity, these standard documents are referred as "ZBD standards" from this point on in the text.
    zoned: bool,
    unused3: u6,
    /// If this feature has been negotiated by driver, the device MUST issue a used buffer notification if the device runs out of available descriptors on a virtqueue, even though notifications are suppressed using the VIRTQ_AVAIL_F_NO_INTERRUPT flag or the used_event field. Note: An example of a driver using this feature is the legacy networking driver: it doesn’t need to know every time a packet is transmitted, but it does need to free the transmitted packets a finite time after they are transmitted. It can avoid using a timer if the device notifies it when all the packets are transmitted.
    notify_on_empty: bool,
    unused4: u2,
    /// This feature indicates that the device accepts arbitrary descriptor layouts, as described in Section 2.7.4.3 Legacy Interface: Message Framing.
    any_layout: bool,
    /// Negotiating this feature indicates that the driver can use descriptors with the VIRTQ_DESC_F_INDIRECT flag set, as described in 2.7.5.3 Indirect Descriptors and 2.8.7 Indirect Flag: Scatter-Gather Support.
    indirect_desc: bool,
    event_idx: bool,
    /// Bit 30 is used by qemu’s implementation to check for experimental early versions of virtio which did not perform correct feature negotiation, and SHOULD NOT be negotiated.
    unused: bool,
    unused6: u1,
    version_1: bool,
    tbd: u31,

    pub fn logAvailable(self: DeviceFeatures) void {
        inline for (@typeInfo(DeviceFeatures).@"struct".fields) |field| {
            if (@FieldType(DeviceFeatures, field.name) == bool and @field(self, field.name))
                log.info("Detected device feature: {s}", .{field.name});
        }
    }
};

pub const Configuration = extern struct {
    /// Capacity of the device (expressed in 512-byte sectors).
    /// Always available.
    capacity: u64,
    size_max: u32,
    seg_max: u32,
    geometry: extern struct {
        cylinders: u16,
        heads: u8,
        sectors: u8,
    },
    blk_size: u32,
    topology: extern struct {
        // # of logical blocks per physical block (log2)
        physical_block_exp: u8,
        // offset of first aligned logical block
        alignment_offset: u8,
        // suggested minimum I/O size in blocks
        min_io_size: u16,
        // optimal (suggested maximum) I/O size in blocks
        opt_io_size: u32,
    },
    writeback: u8,
    unused0: u8,
    num_queues: u16,
    max_discard_sectors: u32,
    max_discard_seg: u32,
    discard_sector_alignment: u32,
    max_write_zeroes_sectors: u32,
    max_write_zeroes_seg: u32,
    write_zeroes_may_unmap: u8,
    unused1: [3]u8,
    max_secure_erase_sectors: u32,
    max_secure_erase_seg: u32,
    secure_erase_sector_alignment: u32,
    zoned_characteristics: extern struct {
        zone_sectors: u32,
        max_open_zones: u32,
        max_active_zones: u32,
        max_append_sectors: u32,
        write_granularity: u32,
        model: u8,
        unused2: [3]u8,
    },
};

pub fn read_write_disk(self: Self, buf: []u8, sector: u32, is_write: i32, blk_req: *Req) void {
    if (sector >= self.blk_capacity / SectorSize) {
        log.warn("trying to read/write sector {d}, but capacity is {d}", .{ sector, self.blk_capacity /
            SectorSize });
        return;
    }

    blk_req.sector = sector;
    blk_req.typ = if (is_write == 1) .Out else .In;
    if (is_write == 1) @memcpy(&blk_req.data, buf[0..SectorSize]);

    self.vq.descriptors[0].addr = @intFromPtr(blk_req);
    self.vq.descriptors[0].len = @sizeOf(u32) * 2 + @sizeOf(u64);
    self.vq.descriptors[0].flags = .{ .next = true };
    self.vq.descriptors[0].next = 1;

    self.vq.descriptors[1].addr = @intFromPtr(blk_req) + @offsetOf(Req, "data");
    self.vq.descriptors[1].len = SectorSize;
    self.vq.descriptors[1].flags = .{ .next = true, .device_access = if (is_write == 1) .read_only else .write_only };
    self.vq.descriptors[1].next = 2;

    self.vq.descriptors[2].addr = @intFromPtr(blk_req) + @offsetOf(Req, "status");
    self.vq.descriptors[2].len = @sizeOf(u8);
    self.vq.descriptors[2].flags = .{ .device_access = .write_only };

    self.vq.kick(0);

    while (self.vq.isBusy()) {}

    if (blk_req.status != .Ok) {
        log.err("failed to read/write sector {d} status {any}", .{ sector, blk_req.status });
        return;
    }

    if (is_write == 0) @memcpy(buf, &blk_req.data);
}
