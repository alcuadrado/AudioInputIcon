const std = @import("std");
const objc = @import("objc.zig");

const log = std.debug;

// --- CoreAudio types ---
pub const AudioObjectID = u32;
pub const AudioObjectPropertyAddress = extern struct {
    mSelector: u32,
    mScope: u32,
    mElement: u32,
};
pub const OSStatus = i32;

// --- CoreAudio constants ---
const kAudioObjectSystemObject: AudioObjectID = 1;
const kAudioObjectPropertyScopeGlobal: u32 = 0x676C6F62; // 'glob'
const kAudioObjectPropertyElementMain: u32 = 0;
const kAudioHardwarePropertyDefaultInputDevice: u32 = 0x64496E20; // 'dIn '
const kAudioDevicePropertyDeviceNameCFString: u32 = 0x6C6E616D; // 'lnam'
const kAudioDevicePropertyTransportType: u32 = 0x7472616E; // 'tran'
const kAudioObjectUnknown: AudioObjectID = 0;

// --- Transport type constants ---
pub const kAudioDeviceTransportTypeBuiltIn: u32 = 0x626C746E; // 'bltn'
pub const kAudioDeviceTransportTypeBluetooth: u32 = 0x626C7565; // 'blue'
pub const kAudioDeviceTransportTypeBluetoothLE: u32 = 0x626C6561; // 'blea'
pub const kAudioDeviceTransportTypeUSB: u32 = 0x75736220; // 'usb '
pub const kAudioDeviceTransportTypeDisplayPort: u32 = 0x64707274; // 'dprt'
pub const kAudioDeviceTransportTypeHDMI: u32 = 0x68646D69; // 'hdmi'
pub const kAudioDeviceTransportTypeVirtual: u32 = 0x76697274; // 'virt'
pub const kAudioDeviceTransportTypeAggregate: u32 = 0x67727570; // 'grup'

// --- CoreFoundation externs ---
const CFStringRef = *anyopaque;
extern "c" fn CFStringGetCString(theString: CFStringRef, buffer: [*]u8, bufferSize: i64, encoding: u32) u8;
extern "c" fn CFRelease(cf: *anyopaque) void;
const kCFStringEncodingUTF8: u32 = 0x08000100;

// --- CoreAudio externs ---
extern "c" fn AudioObjectGetPropertyData(
    inObjectID: AudioObjectID,
    inAddress: *const AudioObjectPropertyAddress,
    inQualifierDataSize: u32,
    inQualifierData: ?*const anyopaque,
    ioDataSize: *u32,
    outData: *anyopaque,
) OSStatus;

extern "c" fn AudioObjectAddPropertyListener(
    inObjectID: AudioObjectID,
    inAddress: *const AudioObjectPropertyAddress,
    inListener: *const fn (AudioObjectID, u32, [*]const AudioObjectPropertyAddress, ?*anyopaque) callconv(.C) OSStatus,
    inClientData: ?*anyopaque,
) OSStatus;

// --- Device info ---

pub const DeviceInfo = struct {
    device_id: AudioObjectID,
    name: [256]u8,
    name_len: usize,
    transport_type: u32,
};

/// Get the current default input device info.
/// Returns null if no input device is available.
pub fn getDefaultInputDevice() ?DeviceInfo {
    // 1. Get default input device ID
    var address = AudioObjectPropertyAddress{
        .mSelector = kAudioHardwarePropertyDefaultInputDevice,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMain,
    };

    var device_id: AudioObjectID = kAudioObjectUnknown;
    var size: u32 = @sizeOf(AudioObjectID);

    var status = AudioObjectGetPropertyData(
        kAudioObjectSystemObject,
        &address,
        0,
        null,
        &size,
        @ptrCast(&device_id),
    );

    if (status != 0 or device_id == kAudioObjectUnknown) {
        return null;
    }

    var info = DeviceInfo{
        .device_id = device_id,
        .name = [_]u8{0} ** 256,
        .name_len = 0,
        .transport_type = 0,
    };

    // 2. Get device name (CFString)
    address.mSelector = kAudioDevicePropertyDeviceNameCFString;
    var cf_name: CFStringRef = undefined;
    size = @sizeOf(CFStringRef);

    status = AudioObjectGetPropertyData(
        device_id,
        &address,
        0,
        null,
        &size,
        @ptrCast(&cf_name),
    );

    if (status == 0) {
        const ok = CFStringGetCString(cf_name, &info.name, 256, kCFStringEncodingUTF8);
        if (ok != 0) {
            info.name_len = std.mem.indexOfScalar(u8, &info.name, 0) orelse info.name.len - 1;
        }
        CFRelease(cf_name);
    }

    // 3. Get transport type
    address.mSelector = kAudioDevicePropertyTransportType;
    size = @sizeOf(u32);

    status = AudioObjectGetPropertyData(
        device_id,
        &address,
        0,
        null,
        &size,
        @ptrCast(&info.transport_type),
    );

    if (status != 0) {
        info.transport_type = 0;
    }

    return info;
}

/// Register a callback for when the default input device changes.
pub fn registerDefaultInputDeviceListener(
    callback: *const fn (AudioObjectID, u32, [*]const AudioObjectPropertyAddress, ?*anyopaque) callconv(.C) OSStatus,
    context: ?*anyopaque,
) void {
    const address = AudioObjectPropertyAddress{
        .mSelector = kAudioHardwarePropertyDefaultInputDevice,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMain,
    };

    const status = AudioObjectAddPropertyListener(
        kAudioObjectSystemObject,
        &address,
        callback,
        context,
    );
    if (status != 0) {
        log.print("AudioInputIcon: ERROR AudioObjectAddPropertyListener failed: {d}\n", .{status});
    }
}
