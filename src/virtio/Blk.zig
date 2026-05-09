pub const Paddr: u32 = 0x10001000;

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
