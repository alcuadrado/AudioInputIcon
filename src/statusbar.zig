const std = @import("std");
const objc = @import("objc.zig");
const audio = @import("audio.zig");
const device_icon = @import("device_icon.zig");
const login_item = @import("login_item.zig");

const log = std.debug;

// --- Global state ---
var g_status_item: ?objc.id = null;
var g_login_menu_item: ?objc.id = null;

/// Load an SF Symbol as an NSImage.
fn loadSFSymbol(name: [*:0]const u8) ?objc.id {
    const NSImage = objc.getClass("NSImage");
    const symbol_name = objc.nsString(name);
    const image: ?objc.id = objc.msgSend(?objc.id, NSImage, "imageWithSystemSymbolName:accessibilityDescription:", .{ symbol_name, @as(?objc.id, null) });

    if (image) |img| {
        objc.msgSend(void, img, "setTemplate:", .{@as(objc.BOOL, 1)});
        log.print("  loadSFSymbol: '{s}' OK\n", .{name});
        return img;
    }
    log.print("  loadSFSymbol: '{s}' returned nil\n", .{name});
    return null;
}

fn loadSFSymbolWithFallback(name: [*:0]const u8) ?objc.id {
    return loadSFSymbol(name) orelse loadSFSymbol("mic.fill") orelse loadSFSymbol("mic");
}

/// Update the button's icon and tooltip from a DeviceInfo.
fn applyDeviceToButton(button: objc.id, dev: ?audio.DeviceInfo) void {
    const symbol = device_icon.sfSymbolForDevice(dev);
    if (loadSFSymbolWithFallback(symbol)) |image| {
        objc.msgSend(void, button, "setImage:", .{image});
    }

    if (dev) |d| {
        // Safety: d.name is zero-initialized and CFStringGetCString null-terminates,
        // so d.name[d.name_len] == 0 holds — see audio.zig buffer handling.
        const tooltip: [*:0]const u8 = @ptrCast(d.name[0..d.name_len :0]);
        objc.msgSend(void, button, "setToolTip:", .{objc.nsString(tooltip)});
    } else {
        objc.msgSend(void, button, "setToolTip:", .{objc.nsString("No Input Device")});
    }
}

/// Set up the status bar item, menu, and initial icon.
pub fn setup(delegate: objc.id) void {
    log.print("  statusbar.setup: getting systemStatusBar\n", .{});
    const NSStatusBar = objc.getClass("NSStatusBar");
    const status_bar = objc.msgSend(objc.id, NSStatusBar, "systemStatusBar", .{});

    log.print("  statusbar.setup: creating status item\n", .{});
    const status_item = objc.msgSend(objc.id, status_bar, "statusItemWithLength:", .{@as(objc.CGFloat, -1.0)});
    _ = objc.msgSend(objc.id, status_item, "retain", .{});
    g_status_item = status_item;

    log.print("  statusbar.setup: getting button\n", .{});
    const button = objc.msgSend(objc.id, status_item, "button", .{});

    log.print("  statusbar.setup: querying audio device\n", .{});
    const dev = audio.getDefaultInputDevice();
    if (dev) |d| {
        log.print("  statusbar.setup: device = '{s}', transport = 0x{x}\n", .{ d.name[0..d.name_len], d.transport_type });
    } else {
        log.print("  statusbar.setup: no audio device found\n", .{});
    }

    applyDeviceToButton(button, dev);

    // Create menu
    log.print("  statusbar.setup: creating menu\n", .{});
    const NSMenu = objc.getClass("NSMenu");
    // alloc/init returns +1 — no extra retain needed; setMenu: retains again.
    const menu = objc.msgSend(objc.id, objc.alloc(NSMenu), "init", .{});

    // "Start at Login" item
    log.print("  statusbar.setup: adding menu items\n", .{});
    const login_item_mi = createMenuItem("Start at Login", "toggleLogin:", delegate);
    g_login_menu_item = login_item_mi;
    login_item.queryLoginItemStateAsync(&updateLoginMenuItemState);
    objc.msgSend(void, menu, "addItem:", .{login_item_mi});

    // Separator
    const NSMenuItem = objc.getClass("NSMenuItem");
    const separator = objc.msgSend(objc.id, NSMenuItem, "separatorItem", .{});
    objc.msgSend(void, menu, "addItem:", .{separator});

    // "Quit" item
    const quit_item = createMenuItem("Quit AudioInputIcon", "quit:", delegate);
    objc.msgSend(void, menu, "addItem:", .{quit_item});

    // Assign menu to status item
    objc.msgSend(void, status_item, "setMenu:", .{menu});
    log.print("  statusbar.setup: done\n", .{});
}

/// Update the status bar icon and tooltip based on current device.
pub fn update() void {
    const status_item = g_status_item orelse return;

    const pool = objc.autoreleasePoolPush();
    defer objc.autoreleasePoolPop(pool);

    const button = objc.msgSend(objc.id, status_item, "button", .{});
    applyDeviceToButton(button, audio.getDefaultInputDevice());
}

/// Update the "Start at Login" menu item checkmark.
pub fn updateLoginMenuItemState() void {
    const login_menu_item = g_login_menu_item orelse return;
    const state: objc.NSInteger = if (login_item.isLoginItemEnabled()) 1 else 0;
    objc.msgSend(void, login_menu_item, "setState:", .{state});
}

fn createMenuItem(title: [*:0]const u8, action: [*:0]const u8, target: objc.id) objc.id {
    const NSMenuItem = objc.getClass("NSMenuItem");
    const item = objc.msgSend(objc.id, objc.alloc(NSMenuItem), "initWithTitle:action:keyEquivalent:", .{
        objc.nsString(title),
        objc.sel(action),
        objc.nsString(""),
    });
    objc.msgSend(void, item, "setTarget:", .{target});
    return item;
}
