const std = @import("std");

// --- Core ObjC types ---
pub const id = *anyopaque;
pub const Class = *anyopaque;
pub const SEL = *anyopaque;
pub const IMP = *anyopaque;
pub const BOOL = i8;
pub const NSUInteger = u64;
pub const NSInteger = i64;
pub const CGFloat = f64;

pub const nil: ?id = null;

/// NSRange — returned by methods like rangeOfString:options:.
pub const NSRange = extern struct { location: NSUInteger, length: NSUInteger };

// --- AppKit / Foundation constants ---
pub const NSApplicationActivationPolicyAccessory: NSInteger = 1;
pub const NSUTF8StringEncoding: NSUInteger = 4;
pub const NSCaseInsensitiveSearch: NSUInteger = 1;
pub const SMAppServiceStatusEnabled: NSInteger = 1;
pub const NSBitmapImageFileTypePNG: NSUInteger = 4;
pub const NSNotFound: NSInteger = std.math.maxInt(NSInteger);

// --- ObjC runtime externs ---
extern "c" fn objc_getClass(name: [*:0]const u8) ?Class;
extern "c" fn sel_registerName(name: [*:0]const u8) SEL;
extern "c" fn objc_msgSend() void;
extern "c" fn objc_allocateClassPair(superclass: ?Class, name: [*:0]const u8, extra_bytes: usize) ?Class;
extern "c" fn objc_registerClassPair(cls: Class) void;
extern "c" fn class_addMethod(cls: Class, name: SEL, imp: IMP, types: [*:0]const u8) bool;
extern "c" fn objc_autoreleasePoolPush() ?*anyopaque;
extern "c" fn objc_autoreleasePoolPop(pool: ?*anyopaque) void;

// --- Convenience functions ---

pub fn getClass(name: [*:0]const u8) Class {
    return objc_getClass(name) orelse @panic("objc_getClass returned null");
}

/// Like `getClass`, but returns null instead of panicking when the class doesn't exist.
/// Useful for optional framework classes (e.g. SMAppService on older macOS).
pub fn findClass(name: [*:0]const u8) ?Class {
    return objc_getClass(name);
}

pub fn sel(name: [*:0]const u8) SEL {
    return sel_registerName(name);
}

/// Type-safe wrapper around objc_msgSend.
/// Casts objc_msgSend to the correct function pointer type based on
/// ReturnType and the types of args, then calls it.
pub fn msgSend(comptime ReturnType: type, target: anytype, sel_name: [*:0]const u8, args: anytype) ReturnType {
    const s = sel(sel_name);
    const target_val: *anyopaque = switch (@typeInfo(@TypeOf(target))) {
        .Optional => target orelse @panic("msgSend on null target"),
        .Pointer => @ptrCast(target),
        else => @compileError("msgSend target must be a pointer or optional pointer"),
    };
    return msgSendDirect(ReturnType, target_val, s, args);
}

/// Zig comptime cannot construct function types with variable arity via a loop —
/// each arm must be a distinct compile-time-known type, hence the explicit switch.
pub fn msgSendDirect(comptime ReturnType: type, target: *anyopaque, s: SEL, args: anytype) ReturnType {
    const ArgsType = @TypeOf(args);
    const args_info = @typeInfo(ArgsType).Struct;

    const FnType = switch (args_info.fields.len) {
        0 => *const fn (*anyopaque, SEL) callconv(.C) ReturnType,
        1 => *const fn (*anyopaque, SEL, args_info.fields[0].type) callconv(.C) ReturnType,
        2 => *const fn (*anyopaque, SEL, args_info.fields[0].type, args_info.fields[1].type) callconv(.C) ReturnType,
        3 => *const fn (*anyopaque, SEL, args_info.fields[0].type, args_info.fields[1].type, args_info.fields[2].type) callconv(.C) ReturnType,
        4 => *const fn (*anyopaque, SEL, args_info.fields[0].type, args_info.fields[1].type, args_info.fields[2].type, args_info.fields[3].type) callconv(.C) ReturnType,
        else => @compileError("msgSend supports up to 4 extra args"),
    };

    const func: FnType = @ptrCast(&objc_msgSend);

    return switch (args_info.fields.len) {
        0 => func(target, s),
        1 => func(target, s, args[0]),
        2 => func(target, s, args[0], args[1]),
        3 => func(target, s, args[0], args[1], args[2]),
        4 => func(target, s, args[0], args[1], args[2], args[3]),
        else => unreachable,
    };
}

/// Create an NSString from a UTF-8 sentinel-terminated string.
pub fn nsString(str: [*:0]const u8) id {
    const NSString = getClass("NSString");
    return msgSend(id, NSString, "stringWithUTF8String:", .{str});
}

/// Allocate a new instance of a class.
pub fn alloc(class: Class) id {
    return msgSend(id, class, "alloc", .{});
}

// --- Dynamic class creation ---

pub fn allocateClassPair(superclass: Class, name: [*:0]const u8) ?Class {
    return objc_allocateClassPair(superclass, name, 0);
}

pub fn registerClassPair(cls: Class) void {
    objc_registerClassPair(cls);
}

pub fn addMethod(cls: Class, sel_name: [*:0]const u8, imp: anytype, types: [*:0]const u8) void {
    // @constCast needed: IMP is *anyopaque but our function pointers are const; the ObjC runtime never mutates them.
    _ = class_addMethod(cls, sel(sel_name), @constCast(@ptrCast(imp)), types);
}

// --- Autorelease pool ---

pub fn autoreleasePoolPush() ?*anyopaque {
    return objc_autoreleasePoolPush();
}

pub fn autoreleasePoolPop(pool: ?*anyopaque) void {
    objc_autoreleasePoolPop(pool);
}
