//! A simple page allocator for physical memory.
//! It exposes both function to allocate and release a number of pages,
//! as well as a context-less Allocator implementation for use as backing allocator to the
//! GeneralPurposeAllocator.
//!
//! Freed pages are kept inside a free list if not released in order.
//! The size of the free list is not considered important, as the goal is to allocate physical
//! memory anyways. As a result, releasing pages is a meaningless operation.
//! The only caveat is that large allocations could eventually become impossible due to memory fragmentation. A future improvement would see the kernel attempt to reclaim the free list in this case.
const std = @import("std");
const root = @import("root");
const lib = root.lib;

const mem = std.mem;
const Allocator = mem.Allocator;
const Alignment = mem.Alignment;
const panic = lib.panic;

const PageSize = lib.PageSize;
const Page = [PageSize]u8;

var next_page: [*]Page = @ptrCast(lib.segmentation.FreeRam);
const PageEnd: [*]Page = @ptrCast(lib.segmentation.FreeRamEnd);
var free_list_start: ?*FreePageListEntry = null;

const log = std.log.scoped(.page_allocator);

fn lenToPageCount(len: usize) usize {
    return std.math.divCeil(usize, len, PageSize) catch lib.panic("div", .{}, @src());
}

fn allocNewPages(count: usize) ?[*]u8 {
    const new_next_page = next_page + count;
    const page = &next_page[0];
    if (@intFromPtr(new_next_page) >= @intFromPtr(PageEnd)) {
        log.warn("out of memory", .{});
        return null;
    }
    next_page = new_next_page;
    log.debug("allocated new page {*}", .{page});
    return page;
}

pub fn allocPages(count: usize) std.mem.Allocator.Error![*]u8 {
    if (count > 1) return allocNewPages(count) orelse error.OutOfMemory;
    if (free_list_start) |free_page_list_entry| {
        free_list_start = free_page_list_entry.next;
        log.debug("reusing page at {*}", .{free_page_list_entry});
        return free_page_list_entry.getPage();
    }
    return allocNewPages(count) orelse error.OutOfMemory;
}

pub fn freePages(pages: [*]u8, count: usize) void {
    const page: [*]Page = @ptrCast(pages);
    if (&(page[count - 1]) == &(next_page - 1)[0]) {
        next_page -= count;
        log.debug("next_page successfully decremented by {d}", .{count});
    } else {
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const free_page_list_entry = FreePageListEntry.from(&page[i], free_list_start);
            free_list_start = free_page_list_entry;
        }
        log.debug("{d} pages added to free list", .{count});
    }
}

pub fn allocPagesFromLen(len: usize) std.mem.Allocator.Error![]u8 {
    const count = lenToPageCount(len);
    return (try allocPages(count))[0..len];
}

pub fn freePagesFromLen(pages: [*]u8, len: usize) void {
    const count = lenToPageCount(len);
    return freePages(pages, count);
}

/// Only meant for use by the GeneralPurposeAllocator
pub const PageAllocator = Allocator{
    .ptr = undefined,
    .vtable = &Allocator.VTable{
        .alloc = allocPage,
        .free = freePage,
        .remap = Allocator.noRemap,
        .resize = Allocator.noResize,
    },
};

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

fn allocPage(data: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
    _ = data;
    _ = alignment;
    _ = ret_addr;

    const page_count = lenToPageCount(len);
    return allocPages(page_count) catch null;
}

fn freePage(data: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
    _ = data;
    _ = alignment;
    _ = ret_addr;

    const page_count = lenToPageCount(memory.len);
    freePages(memory.ptr, page_count);
}
