const sbi = @import("../sbi.zig");
const sbiCall0 = sbi.sbiCall0;

pub fn getSpecVersion() usize {
    return sbiCall0(0, .Base).value;
}

pub fn getImplementationId() usize {
    return sbiCall0(1, .Base).value;
}

pub fn getImplementationName() []const u8 {
    return switch (getImplementationId()) {
        0 => "BBL",
        1 => "OpenSBI",
        2 => "Xvisor",
        3 => "KVM",
        4 => "RustSBI",
        5 => "Diosix",
        6 => "Coffer",
        7 => "Xen Project",
        8 => "PolarFire",
        9 => "coreboot",
        10 => "oreboot",
        11 => "bhyve",
        else => "Unknown",
    };
}

pub fn getImplementationVersion() usize {
    return sbiCall0(2, .Base).value;
}

pub fn probeExtension(ext: sbi.Extension) bool {
    return sbi.sbiCall1(@intCast(@intFromEnum(ext)), 3, .Base).value != 0;
}

pub fn getMachineVendorId() usize {
    return sbiCall0(4, .Base).value;
}

pub fn getMachineArchitectureId() usize {
    return sbiCall0(5, .Base).value;
}

pub fn getMachineImplementationId() usize {
    return sbiCall0(6, .Base).value;
}
