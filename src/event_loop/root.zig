// https://github.com/nodejs/node/blob/main/deps/uv/src/unix/core.c#L427
// https://github.com/nodejs/node/blob/main/deps/uv/include/uv.h#L1941-L1956
//https://github.com/nodejs/node/blob/main/deps/uv/src/unix/core.c#L427-L492
const std = @import("std");
const LinkedList = @import("doubly_linked_list.zig");
const TimerHandle = @import("timers.zig").TimerHandle;
const Timers = @import("timers.zig").Timers;

pub const Callback = *const fn (ctx: *anyopaque, allocator: std.mem.Allocator, args: *anyopaque) anyerror!void;
pub const EventLoopContext = struct {
    io: std.Io,
    time: std.Io.Clock.Timestamp,
};
const EventLoopError = error{UnallocatedEventLoopError} || std.mem.Allocator.Error;

pub const EventLoop = struct {
    const Self = @This();
    var current_event_loop: ?*Self = undefined;

    pub fn get_event_loop(allocator: std.mem.Allocator, io: std.Io) !*Self {
        if (current_event_loop) |loop|{
            return loop;
        }
        const new_event_loop = try allocator.create(EventLoop);
        new_event_loop.timers.init();
        new_event_loop.pending_queue.init();
        new_event_loop.event_loop_context = .{ .io = io };

        current_event_loop = new_event_loop;
        return current_event_loop.?;
    }

    pub fn deinit(self: *EventLoop, allocator: std.mem.Allocator) void {
        if (current_event_loop) |loop| {
            loop.timers.init();
        }
        // Clear the global singleton if it points to us
        if (current_event_loop == self) {
            current_event_loop = null;
        }
        // Fixed: Use destroy() without try/orelse for single item pointers
        allocator.destroy(self);
    }
    pub fn schedule_timer(self: *EventLoop, t: *TimerHandle) void {
        Timers.insert(self.timers, t);
    }

    event_loop_context: EventLoopContext = undefined,
    running: bool = false,
    timers: *Timers.TimerQueue = undefined,
    pending_queue: *LinkedList.DoublyLinkedList(Callback) = undefined,
};

test "Event Loop" {
    const event_loop = try EventLoop.get_event_loop(std.testing.allocator, std.testing.io);
    defer event_loop.deinit(std.testing.allocator);
    try std.testing.expect(!event_loop.running);
}
