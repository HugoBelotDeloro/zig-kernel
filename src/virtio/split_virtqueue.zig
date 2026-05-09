const MmioRegisterLegacy = @import("mmio_register_legacy.zig").MmioRegisterLegacy;
const std = @import("std");
const lib = @import("../lib.zig");
const log = std.log.scoped(.splitvirtq);

pub const SplitVirtqueue = extern struct {
    descriptors: [VirtqEntrySize]Descriptor,
    avail: Available,
    used: Used align(lib.PageSize),
    queue_index: u32,
    used_index: *volatile u16,
    last_used_index: u16,

    /// Hardcoded for now
    pub const VirtqEntrySize: u32 = 16;

    const Descriptor = packed struct(u128) {
        /// Physical address
        addr: u64,

        /// Length
        len: u32,

        flags: packed struct(u16) {
            /// Buffer continues via the `next` field
            next: bool = false,
            /// How can the device access the buffer
            device_access: enum(u1) {
                read_only = 0,
                write_only = 1,
            } = .read_only,
            indirect: bool = false,
            _unused: u13 = 0,
        },

        next: u16,
    };

    const Available = extern struct {
        flags: u16,
        idx: u16,
        ring: [VirtqEntrySize]u16,
        used_event: u16,
    };

    const UsedElement = packed struct(u64) {
        /// Index of start of used descriptor chain
        id: u32,
        /// Number of bytes written into the device-writable portion of the
        /// buffer described by the descriptor chain
        len: u32,
    };

    const Used = extern struct {
        flags: packed struct(u16) {
            no_notify: bool,
            _unused: u15,
        },
        idx: u16,
        ring: [VirtqEntrySize]UsedElement,
        avail_event: u16,
    };

    pub fn kick(self: *SplitVirtqueue, desc_index: u32) void {
        self.avail.ring[self.avail.idx % VirtqEntrySize] = @intCast(desc_index);
        self.avail.idx += 1;
        asm volatile ("sfence.vma");
        MmioRegisterLegacy.queue_notify.write(self.queue_index);
        self.last_used_index += 1;
    }

    pub fn isBusy(self: *SplitVirtqueue) bool {
        return self.last_used_index != self.used_index.*;
    }

    pub fn init(index: u32) !*SplitVirtqueue {
        var vq: *SplitVirtqueue = @ptrCast(@alignCast(try lib.allocPagesFromLen(@sizeOf(SplitVirtqueue))));
        vq.queue_index = index;
        vq.used_index = &vq.used.idx;
        MmioRegisterLegacy.queue_sel.write(index);
        const pfn = MmioRegisterLegacy.queue_pfn.read();
        if (pfn != 0) {
            log.warn("Queue already in use (queue_pfn={d})", .{pfn});
            return error.QueueAlreadyInUse;
        }
        const queue_size_max = MmioRegisterLegacy.queue_size_max.read();
        if (queue_size_max == 0) {
            log.warn("Queue not available (queue_size_max=0)", .{});
            return error.QueueNotAvailable;
        }
        MmioRegisterLegacy.queue_size.write(SplitVirtqueue.VirtqEntrySize);
        MmioRegisterLegacy.queue_align.write(lib.PageSize);
        MmioRegisterLegacy.queue_pfn.write(@as(u32, @intFromPtr(vq)) / lib.PageSize);

        return vq;
    }
};
