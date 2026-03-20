// Grand Central Dispatch helpers — shared across modules.

// We only need the address of this linker symbol; anyopaque lets us take &_dispatch_main_q.
extern "c" var _dispatch_main_q: anyopaque;
extern "c" fn dispatch_async_f(queue: *anyopaque, context: ?*anyopaque, work: *const fn (?*anyopaque) callconv(.C) void) void;
extern "c" fn dispatch_get_global_queue(identifier: c_long, flags: c_ulong) *anyopaque;

pub fn mainQueue() *anyopaque {
    return @ptrCast(&_dispatch_main_q);
}

pub fn globalQueue() *anyopaque {
    return dispatch_get_global_queue(0, 0); // QOS_CLASS_DEFAULT
}

pub fn dispatchToMainThread(work: *const fn (?*anyopaque) callconv(.C) void) void {
    dispatch_async_f(mainQueue(), null, work);
}

pub fn dispatchToBackground(work: *const fn (?*anyopaque) callconv(.C) void) void {
    dispatch_async_f(globalQueue(), null, work);
}
