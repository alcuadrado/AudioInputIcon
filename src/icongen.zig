const std = @import("std");
const objc = @import("objc.zig");

const NSRect = extern struct { x: f64, y: f64, w: f64, h: f64 };
extern "c" fn NSRectFill(rect: NSRect) void;

pub fn main() !void {
    const pool = objc.autoreleasePoolPush();
    defer objc.autoreleasePoolPop(pool);

    _ = objc.msgSend(objc.id, objc.getClass("NSApplication"), "sharedApplication", .{});

    const base_sym = objc.msgSend(?objc.id, objc.getClass("NSImage"), "imageWithSystemSymbolName:accessibilityDescription:", .{
        objc.nsString("mic.fill"),
        @as(?objc.id, null),
    }) orelse {
        std.debug.print("Failed to load mic.fill SF Symbol\n", .{});
        return;
    };

    const IconSpec = struct { px: u32, ty: [4]u8 };
    const specs = [_]IconSpec{
        .{ .px = 128, .ty = .{ 'i', 'c', '0', '7' } },
        .{ .px = 256, .ty = .{ 'i', 'c', '0', '8' } },
        .{ .px = 256, .ty = .{ 'i', 'c', '1', '3' } },
        .{ .px = 512, .ty = .{ 'i', 'c', '0', '9' } },
        .{ .px = 512, .ty = .{ 'i', 'c', '1', '4' } },
        .{ .px = 1024, .ty = .{ 'i', 'c', '1', '0' } },
    };

    const Entry = struct { data: ?objc.id = null, len: u32 = 0 };
    var entries = [_]Entry{.{}} ** specs.len;
    var total: u32 = 8; // icns header

    for (specs, 0..) |spec, i| {
        if (renderPNG(base_sym, spec.px)) |data| {
            const len: u32 = @intCast(objc.msgSend(objc.NSUInteger, data, "length", .{}));
            entries[i] = .{ .data = data, .len = len };
            total += 8 + len;
            std.debug.print("  {d}x{d}: {d} bytes\n", .{ spec.px, spec.px, len });
        } else {
            std.debug.print("  {d}x{d}: FAILED\n", .{ spec.px, spec.px });
        }
    }

    const path = "AppIcon.icns";
    var file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const w = file.writer();

    try w.writeAll("icns");
    try w.writeInt(u32, total, .big);

    for (specs, 0..) |spec, i| {
        if (entries[i].data) |data| {
            try w.writeAll(&spec.ty);
            try w.writeInt(u32, 8 + entries[i].len, .big);
            const bytes: [*]const u8 = @ptrCast(objc.msgSend(objc.id, data, "bytes", .{}));
            try w.writeAll(bytes[0..entries[i].len]);
        }
    }

    std.debug.print("Created {s} ({d} bytes)\n", .{ path, total });
}

fn renderPNG(sym: objc.id, px: u32) ?objc.id {
    const fpx: f64 = @floatFromInt(px);

    // Configure symbol at appropriate point size
    const config = objc.msgSend(objc.id, objc.getClass("NSImageSymbolConfiguration"), "configurationWithPointSize:weight:", .{ fpx * 0.45, @as(f64, 0.0) });
    const configured = objc.msgSend(?objc.id, sym, "imageWithSymbolConfiguration:", .{config}) orelse return null;

    // Create canvas image
    const canvas = objc.msgSend(objc.id, objc.alloc(objc.getClass("NSImage")), "initWithSize:", .{ fpx, fpx });

    // Draw into canvas
    objc.msgSend(void, canvas, "lockFocus", .{});

    // White background
    objc.msgSend(void, objc.msgSend(objc.id, objc.getClass("NSColor"), "whiteColor", .{}), "set", .{});
    NSRectFill(.{ .x = 0, .y = 0, .w = fpx, .h = fpx });

    // Set fill color to #313131 — template images use the current fill color
    const grey = objc.msgSend(objc.id, objc.getClass("NSColor"), "colorWithSRGBRed:green:blue:alpha:", .{
        @as(f64, 0x31) / @as(f64, 0xFF),
        @as(f64, 0x31) / @as(f64, 0xFF),
        @as(f64, 0x31) / @as(f64, 0xFF),
        @as(f64, 1.0),
    });
    objc.msgSend(void, grey, "set", .{});

    // Draw symbol centered with padding
    const padding = fpx * 0.18;
    const sz = fpx - padding * 2;
    // On aarch64, NSRect {f64,f64,f64,f64} is passed in d0-d3,
    // identical to passing 4 separate f64 args.
    // NOTE: This trick is aarch64-specific — x86_64 would require objc_msgSend_stret for structs >16 bytes.
    objc.msgSend(void, configured, "drawInRect:", .{ padding, padding, sz, sz });

    objc.msgSend(void, canvas, "unlockFocus", .{});

    // Convert to PNG via TIFF intermediate
    const tiff = objc.msgSend(?objc.id, canvas, "TIFFRepresentation", .{}) orelse return null;
    const rep = objc.msgSend(?objc.id, objc.getClass("NSBitmapImageRep"), "imageRepWithData:", .{tiff}) orelse return null;
    const empty_dict = objc.msgSend(objc.id, objc.getClass("NSDictionary"), "dictionary", .{});
    return objc.msgSend(?objc.id, rep, "representationUsingType:properties:", .{ objc.NSBitmapImageFileTypePNG, empty_dict });
}
