const std = @import("std");
const objc = @import("objc.zig");
const audio = @import("audio.zig");

/// Map a device (or null = no device) to an SF Symbol name.
pub fn sfSymbolForDevice(info: ?audio.DeviceInfo) [*:0]const u8 {
    const dev = info orelse return "mic.slash";

    const name = dev.name[0..dev.name_len];

    // Name-based matching (case-insensitive, most specific first)
    if (containsCI(name, "airpods max")) return "airpodsmax";
    if (containsCI(name, "airpods pro")) return "airpodspro";
    if (containsCI(name, "airpods")) return "airpods";
    if (containsCI(name, "beats")) return "beats.headphones";

    if (containsCI(name, "webcam") or containsCI(name, "facetime") or containsCI(name, "camera"))
        return "web.camera";

    if (containsCI(name, "display") or containsCI(name, "monitor") or
        containsCI(name, "hdmi") or containsCI(name, "displayport"))
        return "display";

    if (containsCI(name, "macbook") or containsCI(name, "built-in") or containsCI(name, "internal"))
        return "laptopcomputer";

    if (containsCI(name, "usb mic") or containsCI(name, "yeti") or
        containsCI(name, "blue") or containsCI(name, "rode") or
        containsCI(name, "shure") or containsCI(name, "at2020") or
        containsCI(name, "scarlett"))
        return "mic.fill";

    if (containsCI(name, "earpods") or containsCI(name, "earbud"))
        return "earpods";

    // Transport type fallback
    return switch (dev.transport_type) {
        audio.kAudioDeviceTransportTypeBuiltIn => "laptopcomputer",
        audio.kAudioDeviceTransportTypeBluetooth, audio.kAudioDeviceTransportTypeBluetoothLE => "headphones",
        audio.kAudioDeviceTransportTypeUSB => "mic.fill",
        audio.kAudioDeviceTransportTypeDisplayPort, audio.kAudioDeviceTransportTypeHDMI => "display",
        audio.kAudioDeviceTransportTypeVirtual => "mic.badge.xmark",
        else => "mic",
    };
}

/// Unicode-aware case-insensitive substring search via NSString.
fn containsCI(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    if (needle.len == 0) return true;

    const NSStringClass = objc.getClass("NSString");

    // initWithBytesNoCopy:length:encoding:freeWhenDone: avoids copying the buffers.
    // @constCast is safe: NSString does not mutate the buffer when freeWhenDone is NO.
    const hay_ns = objc.msgSend(?objc.id, objc.alloc(NSStringClass), "initWithBytesNoCopy:length:encoding:freeWhenDone:", .{
        @constCast(haystack.ptr),
        @as(objc.NSUInteger, haystack.len),
        objc.NSUTF8StringEncoding,
        @as(objc.BOOL, 0), // NO
    }) orelse return false;
    defer objc.msgSend(void, hay_ns, "release", .{});

    const needle_ns = objc.msgSend(?objc.id, objc.alloc(NSStringClass), "initWithBytesNoCopy:length:encoding:freeWhenDone:", .{
        @constCast(needle.ptr),
        @as(objc.NSUInteger, needle.len),
        objc.NSUTF8StringEncoding,
        @as(objc.BOOL, 0),
    }) orelse return false;
    defer objc.msgSend(void, needle_ns, "release", .{});

    const range = objc.msgSend(objc.NSRange, hay_ns, "rangeOfString:options:", .{
        needle_ns,
        objc.NSCaseInsensitiveSearch,
    });
    return range.location != @as(objc.NSUInteger, @bitCast(objc.NSNotFound));
}
