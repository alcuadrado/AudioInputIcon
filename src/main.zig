const std = @import("std");
const objc = @import("objc.zig");
const audio = @import("audio.zig");
const statusbar = @import("statusbar.zig");
const login_item = @import("login_item.zig");
const gcd = @import("gcd.zig");

const log = std.debug;

// --- Delegate instance (global so callbacks can find it) ---
var g_delegate: ?objc.id = null;

pub fn main() void {
    log.print("AudioInputIcon: starting\n", .{});

    const pool = objc.autoreleasePoolPush();
    defer objc.autoreleasePoolPop(pool);

    log.print("AudioInputIcon: getting NSApplication\n", .{});
    const NSApp = objc.msgSend(objc.id, objc.getClass("NSApplication"), "sharedApplication", .{});

    log.print("AudioInputIcon: setting activation policy\n", .{});
    objc.msgSend(void, NSApp, "setActivationPolicy:", .{objc.NSApplicationActivationPolicyAccessory});

    // Reduce tooltip delay so the device name appears quickly on hover (default is ~1500ms).
    const defaults = objc.msgSend(objc.id, objc.getClass("NSUserDefaults"), "standardUserDefaults", .{});
    objc.msgSend(void, defaults, "setInteger:forKey:", .{ @as(objc.NSInteger, 500), objc.nsString("NSInitialToolTipDelay") });

    log.print("AudioInputIcon: registering delegate class\n", .{});
    const DelegateClass = registerDelegateClass();

    log.print("AudioInputIcon: creating delegate instance\n", .{});
    const delegate = objc.msgSend(objc.id, objc.alloc(DelegateClass), "init", .{});
    g_delegate = delegate;

    log.print("AudioInputIcon: setting delegate\n", .{});
    objc.msgSend(void, NSApp, "setDelegate:", .{delegate});

    log.print("AudioInputIcon: calling run\n", .{});
    objc.msgSend(void, NSApp, "run", .{});

    log.print("AudioInputIcon: run returned (unexpected)\n", .{});
}

fn registerDelegateClass() objc.Class {
    const NSObject = objc.getClass("NSObject");
    const cls = objc.allocateClassPair(NSObject, "AIDAppDelegate") orelse
        @panic("Failed to allocate delegate class");

    // ObjC type encoding: v=void return, @=object(self), :=selector(_cmd), @=object(arg)
    objc.addMethod(cls, "applicationDidFinishLaunching:", &appDidFinishLaunching, "v@:@");
    objc.addMethod(cls, "quit:", &quitAction, "v@:@");
    objc.addMethod(cls, "toggleLogin:", &toggleLoginAction, "v@:@");

    objc.registerClassPair(cls);
    return cls;
}

fn appDidFinishLaunching(_: objc.id, _: objc.SEL, _: objc.id) callconv(.C) void {
    log.print("AudioInputIcon: appDidFinishLaunching called!\n", .{});
    const delegate = g_delegate orelse {
        log.print("AudioInputIcon: ERROR delegate is null\n", .{});
        return;
    };
    statusbar.setup(delegate);
    log.print("AudioInputIcon: statusbar setup complete\n", .{});
    audio.registerDefaultInputDeviceListener(&onDeviceChanged, null);
    log.print("AudioInputIcon: audio listener registered\n", .{});
}

fn quitAction(_: objc.id, _: objc.SEL, _: objc.id) callconv(.C) void {
    log.print("AudioInputIcon: quitting\n", .{});
    const NSApp = objc.msgSend(objc.id, objc.getClass("NSApplication"), "sharedApplication", .{});
    objc.msgSend(void, NSApp, "terminate:", .{@as(?objc.id, null)});
}

fn toggleLoginAction(_: objc.id, _: objc.SEL, _: objc.id) callconv(.C) void {
    login_item.toggleLoginItem(&statusbar.updateLoginMenuItemState);
}

fn onDeviceChanged(
    _: audio.AudioObjectID,
    _: u32,
    _: [*]const audio.AudioObjectPropertyAddress,
    _: ?*anyopaque,
) callconv(.C) audio.OSStatus {
    gcd.dispatchToMainThread(&updateStatusBarCallback);
    return 0;
}

fn updateStatusBarCallback(_: ?*anyopaque) callconv(.C) void {
    statusbar.update();
}
