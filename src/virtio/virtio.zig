const std = @import("std");

const MmioRegisterLegacy = @import("mmio_register_legacy.zig").MmioRegisterLegacy;

const log = std.log.scoped(.virtio);
const MagicValue: u32 = 0x74726976;

pub const DeviceStatus = packed struct(u32) {
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

pub const DeviceInitError = error{
    QueueAlreadyInUse,
    QueueNotAvailable,
    OutOfMemory,
};

pub fn Device(DeviceType: type) type {
    return struct {
        device_id: u32,
        DeviceFeatures: type,
        device_init: fn () DeviceInitError!DeviceType,

        pub fn init(self: @This()) !DeviceType {
            if (MmioRegisterLegacy.magic_value.read() != MagicValue)
                std.debug.panic("wrong magic number", .{});
            log.info("magic ok", .{});

            if (MmioRegisterLegacy.version.read() != 1)
                std.debug.panic("wrong version", .{});
            log.info("version ok", .{});

            if (MmioRegisterLegacy.device_id.read() != self.device_id)
                std.debug.panic("wrong device id", .{});
            log.info("device id ok", .{});

            DeviceStatus.reset();
            (DeviceStatus{ .acknowledge = true }).set_bits();
            (DeviceStatus{ .driver = true }).set_bits();

            // Features negociation
            const device_features: self.DeviceFeatures = @bitCast(MmioRegisterLegacy.readDeviceFeatures());
            device_features.logAvailable();
            DeviceStatus.set_bits(DeviceStatus{
                .features_ok = true,
            });
            if (!DeviceStatus.read().features_ok) {
                log.warn("features refused by device", .{});
                return error.DeviceRefusedFeatures;
            }
            log.info("features ok", .{});

            // Device initialization
            const device = try self.device_init();

            (DeviceStatus{ .driver_ok = true }).set_bits();

            return device;
        }
    };
}
