const BlkPaddr = @import("../virtio.zig").Blk.Paddr;

fn read32(offset: u32) u32 {
    return @as(*volatile u32, @ptrFromInt(BlkPaddr + offset)).*;
}

fn read64(offset: u32) u64 {
    return @as(*volatile u64, @ptrFromInt(BlkPaddr + offset)).*;
}

fn write32(offset: u32, value: u32) void {
    @as(*volatile u32, @ptrFromInt(BlkPaddr + offset)).* = value;
}

fn fetchAndOr32(offset: u32, value: u32) void {
    write32(offset, read32(offset) | value);
}

pub const MmioRegisterLegacy = enum(u32) {
    /// Magic value
    magic_value = 0x0,
    /// Device version number
    /// Legacy device returns value 0x1.
    version = 0x4,
    /// Virtio Subsystem Device ID
    device_id = 0x8,
    /// Virtio Subsystem Vendor ID
    vendor_id = 0xc,
    /// Flags representing features the device supports
    host_features = 0x10,
    /// Device (host) features word selection.
    host_features_sel = 0x14,
    /// Flags representing device features understood and activated by the driver
    guest_features = 0x20,
    /// Activated (guest) features word selection
    guest_features_sel = 0x24,
    /// Guest page size
    /// The driver writes the guest page size in bytes to the register during initialization, before any queues are used. This value should be a power of 2 and is used by the device to calculate the Guest address of the first queue page (see QueuePFN).
    guest_page_size = 0x28,
    /// Virtqueue index
    /// Writing to this register selects the virtqueue that the following operations on the QueueSizeMax, QueueSize, QueueAlign and QueuePFN registers apply to.
    queue_sel = 0x30,
    /// Maximum virtqueue size
    /// Reading from the register returns the maximum size of the queue the device is ready to process or zero (0x0) if the queue is not available. This applies to the queue selected by writing to QueueSel and is allowed only when QueuePFN is set to zero (0x0), so when the queue is not actively used. Note: QueueSizeMax was previously known as QueueNumMax.
    queue_size_max = 0x34,
    /// Virtqueue size
    /// Queue size is the number of elements in the queue. Writing to this register notifies the device what size of the queue the driver will use. This applies to the queue selected by writing to QueueSel. Note: QueueSize was previously known as QueueNum.
    queue_size = 0x38,
    /// Used Ring alignment in the virtqueue
    /// Writing to this register notifies the device about alignment boundary of the Used Ring in bytes. This value should be a power of 2 and applies to the queue selected by writing to QueueSel.
    queue_align = 0x3c,
    /// Guest physical page number of the virtqueue
    /// Writing to this register notifies the device about location of the virtqueue in the Guest’s physical address space. This value is the index number of a page starting with the queue Descriptor Table. Value zero (0x0) means physical address zero (0x00000000) and is illegal. When the driver stops using the queue it writes zero (0x0) to this register. Reading from this register returns the currently used page number of the queue, therefore a value other than zero (0x0) means that the queue is in use. Both read and write accesses apply to the queue selected by writing to QueueSel.
    queue_pfn = 0x40,
    /// Queue notifier
    queue_notify = 0x50,
    /// Interrupt status
    interrupt_status = 0x60,
    /// Interrupt acknowledge
    interrupt_ack = 0x64,
    /// Device status
    /// Reading from this register returns the current device status flags. Writing non-zero values to this register sets the status flags, indicating the OS/driver progress. Writing zero (0x0) to this register triggers a device reset. The device sets QueuePFN to zero (0x0) for all queues in the device.
    status = 0x70,
    /// Configuration space
    config_start = 0x100,

    pub fn read(comptime reg: MmioRegisterLegacy) u32 {
        return switch (reg) {
            .host_features_sel,
            .guest_features,
            .guest_features_sel,
            .guest_page_size,
            .queue_sel,
            .queue_size,
            .interrupt_ack,
            => @compileError("register " ++ @tagName(reg) ++ "is not readable"),
            else => read32(@intFromEnum(reg)),
        };
    }

    pub fn write(comptime reg: MmioRegisterLegacy, value: u32) void {
        return switch (reg) {
            .magic_value,
            .version,
            .device_id,
            .vendor_id,
            .host_features,
            .queue_size_max,
            .interrupt_status,
            => @compileError("register " ++ @tagName(reg) ++ "is not writable"),
            else => write32(@intFromEnum(reg), value),
        };
    }

    pub fn readConfig(offset: usize) u64 {
        return read64(@intFromEnum(MmioRegisterLegacy.config_start) + offset);
    }
};
