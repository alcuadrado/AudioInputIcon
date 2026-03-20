const std = @import("std");
const objc = @import("objc.zig");
const gcd = @import("gcd.zig");

const log = std.debug;

// SMAppService class — resolved lazily
var sm_class: ?objc.Class = null;
var sm_resolved: bool = false;

fn getSMAppServiceClass() ?objc.Class {
    if (sm_resolved) return sm_class;
    sm_resolved = true;
    sm_class = objc.findClass("SMAppService");
    if (sm_class == null) {
        log.print("  login_item: SMAppService class not found\n", .{});
    }
    return sm_class;
}

// Cached login item state — written from GCD background threads, read from main thread.
// Thread safety: dispatch_async provides a happens-before guarantee, so the main-thread
// read in the dispatch callback always sees the value written by the background block.
var g_login_enabled: bool = false;
var g_update_callback: ?*const fn () void = null;

/// Check cached login item state (non-blocking).
pub fn isLoginItemEnabled() bool {
    return g_login_enabled;
}

/// Query SMAppService.status on a background thread, then call back on main thread.
pub fn queryLoginItemStateAsync(onComplete: *const fn () void) void {
    g_update_callback = onComplete;
    gcd.dispatchToBackground(&bgQueryStatus);
}

fn getService() ?objc.id {
    const cls = getSMAppServiceClass() orelse return null;
    const responds: objc.BOOL = objc.msgSend(objc.BOOL, cls, "respondsToSelector:", .{objc.sel("mainAppService")});
    if (responds == 0) {
        log.print("  login_item: SMAppService does not respond to mainAppService\n", .{});
        return null;
    }
    return objc.msgSend(objc.id, cls, "mainAppService", .{});
}

fn bgQueryStatus(_: ?*anyopaque) callconv(.C) void {
    // GCD background threads have no autorelease pool — push one to avoid leaks.
    const pool = objc.autoreleasePoolPush();
    defer objc.autoreleasePoolPop(pool);

    const service = getService() orelse {
        g_login_enabled = false;
        gcd.dispatchToMainThread(&mainThreadCallback);
        return;
    };
    const status = objc.msgSend(objc.NSInteger, service, "status", .{});
    log.print("  login_item: status = {d}\n", .{status});
    g_login_enabled = (status == objc.SMAppServiceStatusEnabled);
    gcd.dispatchToMainThread(&mainThreadCallback);
}

fn mainThreadCallback(_: ?*anyopaque) callconv(.C) void {
    if (g_update_callback) |cb| cb();
}

/// Toggle login item registration (runs on background thread).
pub fn toggleLoginItem(onComplete: *const fn () void) void {
    g_update_callback = onComplete;
    gcd.dispatchToBackground(&bgToggle);
}

fn bgToggle(_: ?*anyopaque) callconv(.C) void {
    // GCD background threads have no autorelease pool — push one to avoid leaks.
    const pool = objc.autoreleasePoolPush();
    defer objc.autoreleasePoolPop(pool);

    const service = getService() orelse {
        gcd.dispatchToMainThread(&mainThreadCallback);
        return;
    };

    if (g_login_enabled) {
        log.print("  login_item: unregistering\n", .{});
        const ok = objc.msgSend(objc.BOOL, service, "unregisterAndReturnError:", .{@as(?objc.id, null)});
        if (ok == 0) log.print("  login_item: ERROR unregister failed\n", .{});
    } else {
        log.print("  login_item: registering\n", .{});
        const ok = objc.msgSend(objc.BOOL, service, "registerAndReturnError:", .{@as(?objc.id, null)});
        if (ok == 0) log.print("  login_item: ERROR register failed\n", .{});
    }

    // Re-query status
    bgQueryStatus(null);
}
