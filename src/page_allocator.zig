const std = @import("std");
const root = @import("root");
const lib = std.lib;

const mem = std.mem;
const Allocator = mem.Allocator;
const Alignment = mem.Alignment;
const panic = lib.panic;

pub const PageSize = 4096;
const Page = [PageSize]u8;

var next_page: [*]Page = @ptrCast(root.FreeRamStart);
const PageEnd: [*]Page = @ptrCast(root.FreeRamEnd);
var next_free_page: ?*FreePageListEntry = null;

const log = std.log.scoped(.page_allocator);

pub const PageAllocator = Allocator{
    .ptr = undefined,
    .vtable = &Allocator.VTable{
        .alloc = allocPage,
        .free = freePage,
        .remap = Allocator.noRemap,
        .resize = Allocator.noResize,
    },
};

pub fn allocPage(data: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
    _ = data;
    _ = len;
    _ = alignment;
    _ = ret_addr;

    if (next_free_page) |free_page_list_entry| {
        next_free_page = free_page_list_entry.next;
        log.info("reusing page at {*}", .{free_page_list_entry});
        return free_page_list_entry.getPage();
    }
    const page = &next_page[0];
    next_page += 1;
    if (next_page == PageEnd) {
        log.warn("out of memory", .{});
        return null;
    }
    log.info("allocated new page {*}", .{page});
    return page;
}

pub fn freePage(data: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
    _ = data;
    _ = alignment;
    _ = ret_addr;

    const page: *Page = @ptrCast(memory);

    if (&(next_page - 1)[0] == page) {
        next_page -= 1;
        log.info("next_page successfully decremented from {*}", .{page});
    } else {
        const free_page_list_entry = FreePageListEntry.from(page, next_free_page);
        next_free_page = free_page_list_entry;
        log.info("page {*} added to free list", .{free_page_list_entry});
    }
}

const FreePageListEntry = struct {
    next: ?*FreePageListEntry,

    fn getPage(self: *FreePageListEntry) *Page {
        return @ptrCast(self);
    }

    fn from(page: *Page, next: ?*FreePageListEntry) *FreePageListEntry {
        var entry: *FreePageListEntry = @ptrCast(@alignCast(page));
        entry.next = next;

        return entry;
    }
};
