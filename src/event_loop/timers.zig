const std = @import("std");

const DoublyLinkedList = @import("doubly_linked_list.zig").DoublyLinkedList;
const EventLoop = @import("root.zig").EventLoop;
const EventLoopContext = @import("root.zig").EventLoopContext;
const Timestamp = @import("std").Io.Clock.Timestamp;

pub const Timers = struct {
    const TimerQueue = DoublyLinkedList(TimerHandle);

    pub fn schedule(queue: *TimerQueue, t: *TimerQueue.Node, event_loop_ctx: *EventLoopContext) void {
        t.data.schedule_time = event_loop_ctx.time.addDuration(.{ .clock = .boot, .raw = std.Io.Duration.fromMilliseconds(t.data.time_ms) });
        if (queue.is_empty()) {
            queue.add_at_end(&t.queue);
            return;
        }

        var current = queue.peek();
        while (current != queue) {
            // When the current node is longer in time than the t node in time
            // [ 300, 400, 600] | 600, => 300 < 20
            if (TimerQueue.Node.fromQueue(current).data.time_ms > t.data.time_ms or current.next == queue) {
                break;
            }
            current = current.next;
        }

        // Implemenntation to put always t in front of current when current is larger.
        if (TimerQueue.Node.fromQueue(current).data.time_ms > t.data.time_ms) {
            queue.add_before(current, &t.queue);
        } else {
            // Otherwise, t should be larger than current.
            queue.add_after(current, &t.queue);
        }
    }

    pub fn poll_timers(queue: *TimerQueue, event_loop_ctx: *EventLoopContext) !void {
        var ready_timer_queue: TimerQueue = undefined;
        ready_timer_queue.init();
        var node = queue.peek();

        while (!queue.is_empty() and Timestamp.compare(event_loop_ctx.time, .gt, TimerQueue.Node.fromQueue(node).data.schedule_time)) : (node = queue.peek()) {
            const nd = queue.shift();
            if (nd) |d| {
                ready_timer_queue.add_at_end(&d.queue);
                continue;
            }
        }
        while (!ready_timer_queue.is_empty()) {
            const _node = ready_timer_queue.peek();
            _ = ready_timer_queue.shift();
            const handle = TimerQueue.Node.fromQueue(_node).data;
            try handle.handler(handle.handler_args);
        }
    }
};

pub const TimerHandle = struct {
    const Self = @This();

    pub const TimerCallback = *const fn (args: *anyopaque) anyerror!void;

    id: i32 = 0,
    time_ms: i64,
    schedule_time: Timestamp = .{ .raw = .zero, .clock = .boot },
    handler: TimerCallback,
    handler_args: *anyopaque,

    pub fn init(time_ms: i64, handler: TimerCallback, handler_args: *anyopaque) Self {
        return Self{ .handler = handler, .time_ms = time_ms, .handler_args = handler_args };
    }
};

test "init" {
    const HandlerArguments = struct { w: std.Io.Writer, io: std.Io, spyCalled: bool };
    // 1. Setup your testing buffer/writer environment
    var buffer: [128]u8 = undefined;
    const stdout = std.Io.Writer.fixed(&buffer);

    var timerQueue: Timers.TimerQueue = undefined;
    timerQueue.init();
    const handle = struct {
        fn callback(args: *anyopaque) anyerror!void {
            const ctx: *HandlerArguments = @ptrCast(@alignCast(args));
            try ctx.w.print("Hello world!", .{});
        }
    }.callback;

    var wr: HandlerArguments = .{
        .w = stdout,
        .io = std.testing.io, // Assign the global test execution I/O engine
        .spyCalled = false,
    };

    const timer_handler = TimerHandle.init(300, &handle, @ptrCast(&wr));

    var t: Timers.TimerQueue.Node = undefined;
    t.init(timer_handler);
    Timers.schedule(&timerQueue, &t);

    try std.testing.expect(!timerQueue.is_empty());
    try std.testing.expect(timerQueue.size() == 1);
    try std.testing.expect(Timers.TimerQueue.Node.fromQueue(timerQueue.next).data.time_ms == 300);
    // try Timers.TimerQueue.Node.fromQueue(timerQueue.next).data.handler(@ptrCast(&wr));
    // try std.testing.expect(wr.spyCalled);
}

test "TimerHandle.init" {
    const HandlerArguments = struct { w: std.Io.Writer, io: std.Io, spyCalled: bool };
    // 1. Setup your testing buffer/writer environment
    var buffer: [128]u8 = undefined;
    const stdout = std.Io.Writer.fixed(&buffer);

    var timerQueue: Timers.TimerQueue = undefined;
    timerQueue.init();
    const handle = struct {
        fn callback(args: *anyopaque) anyerror!void {
            const ctx: *HandlerArguments = @ptrCast(@alignCast(args));
            try ctx.w.print("Hello world!", .{});
        }
    }.callback;

    var wr: HandlerArguments = .{
        .w = stdout,
        .io = std.testing.io, // Assign the global test execution I/O engine
        .spyCalled = false,
    };

    const timer_handler = TimerHandle.init(300, &handle, @ptrCast(&wr));

    var t: Timers.TimerQueue.Node = undefined;
    t.init(timer_handler);

    try std.testing.expect(timer_handler.time_ms == timer_handler.time_ms);
}

test "Timers.schedule" {
    const HandlerArguments = struct { w: std.Io.Writer, io: std.Io, spyCalled: bool };
    // 1. Setup your testing buffer/writer environment
    var buffer: [128]u8 = undefined;
    const stdout = std.Io.Writer.fixed(&buffer);

    var timerQueue: Timers.TimerQueue = undefined;
    timerQueue.init();
    const handle1 = struct {
        fn callback(args: *anyopaque) anyerror!void {
            const ctx: *HandlerArguments = @ptrCast(@alignCast(args));
            try ctx.w.print("Hello world!", .{});
        }
    }.callback;

    var wr: HandlerArguments = .{
        .w = stdout,
        .io = std.testing.io, // Assign the global test execution I/O engine
        .spyCalled = false,
    };

    const timer_handler1 = TimerHandle.init(300, &handle1, @ptrCast(&wr));

    var t1: Timers.TimerQueue.Node = undefined;
    t1.init(timer_handler1);
    Timers.schedule(&timerQueue, &t1);

    try std.testing.expect(!timerQueue.is_empty());
    try std.testing.expect(timerQueue.size() == 1);
    try std.testing.expect(Timers.TimerQueue.Node.fromQueue(timerQueue.next).data.time_ms == timer_handler1.time_ms);

    const handle2 = struct {
        fn callback(args: *anyopaque) anyerror!void {
            const ctx: *HandlerArguments = @ptrCast(@alignCast(args));
            try ctx.w.print("Hello world!", .{});
        }
    }.callback;

    const timer_handler2 = TimerHandle.init(600, &handle2, @ptrCast(&wr));
    var t2: Timers.TimerQueue.Node = undefined;
    t2.init(timer_handler2);

    Timers.schedule(&timerQueue, &t2);

    try std.testing.expect(!timerQueue.is_empty());
    try std.testing.expect(timerQueue.size() == 2);
    try std.testing.expect(Timers.TimerQueue.Node.fromQueue(timerQueue.prev).data.time_ms == timer_handler2.time_ms);

    const handle3 = struct {
        fn callback(args: *anyopaque) anyerror!void {
            const ctx: *HandlerArguments = @ptrCast(@alignCast(args));
            try ctx.w.print("Hello world!", .{});
        }
    }.callback;

    const timer_handler3 = TimerHandle.init(20, &handle3, @ptrCast(&wr));
    var t3: Timers.TimerQueue.Node = undefined;
    t3.init(timer_handler3);

    Timers.schedule(&timerQueue, &t3);

    try std.testing.expect(!timerQueue.is_empty());
    try std.testing.expect(timerQueue.size() == 3);
    // The tail must be the timer_handler2 since is larger.
    try std.testing.expect(Timers.TimerQueue.Node.fromQueue(timerQueue.prev).data.time_ms == timer_handler2.time_ms);
    // The first element must be the timer_handler3 since it is the shorter.
    std.debug.print("{d}\n", .{Timers.TimerQueue.Node.fromQueue(timerQueue.next).data.time_ms});
    try std.testing.expect(Timers.TimerQueue.Node.fromQueue(timerQueue.next).data.time_ms == timer_handler3.time_ms);
}

test "Timers.poll_timers" {
    const HandlerArguments = struct { w: std.Io.Writer, io: std.Io};
    // 1. Setup your testing buffer/writer environment
    var buffer: [128]u8 = undefined;
    const stdout = std.Io.Writer.fixed(&buffer);

    var timerQueue: Timers.TimerQueue = undefined;
    timerQueue.init();
    const handle1 = struct {
        fn callback(args: *anyopaque) anyerror!void {
            const ctx: *HandlerArguments = @ptrCast(@alignCast(args));
            try ctx.w.print("Hello world!", .{});
        }
    }.callback;

    var wr: HandlerArguments = .{
        .w = stdout,
        .io = std.testing.io, // Assign the global test execution I/O engine
    };

    const timer_handler1 = TimerHandle.init(300, &handle1, @ptrCast(&wr));

    var t1: Timers.TimerQueue.Node = undefined;
    t1.init(timer_handler1);
    var cxt: EventLoopContext = .{
        .io = std.testing.io,
        .time = Timestamp.now(std.testing.io, .boot),
    };
    Timers.schedule(&timerQueue, &t1, &cxt);

    try std.testing.expect(!timerQueue.is_empty());
    try std.testing.expect(timerQueue.size() == 1);
    try std.testing.expect(Timers.TimerQueue.Node.fromQueue(timerQueue.next).data.time_ms == timer_handler1.time_ms);

    const handle2 = struct {
        fn callback(args: *anyopaque) anyerror!void {
            const ctx: *HandlerArguments = @ptrCast(@alignCast(args));
            try ctx.w.print("Hello world!", .{});
        }
    }.callback;

    const timer_handler2 = TimerHandle.init(600, &handle2, @ptrCast(&wr));
    var t2: Timers.TimerQueue.Node = undefined;
    t2.init(timer_handler2);

    Timers.schedule(&timerQueue, &t2, &cxt);

    try std.testing.expect(!timerQueue.is_empty());
    try std.testing.expect(timerQueue.size() == 2);
    try std.testing.expect(Timers.TimerQueue.Node.fromQueue(timerQueue.prev).data.time_ms == timer_handler2.time_ms);

    const handle3 = struct {
        fn callback(args: *anyopaque) anyerror!void {
            const ctx: *HandlerArguments = @ptrCast(@alignCast(args));
            try ctx.w.print("Hello world!", .{});
        }
    }.callback;

    const timer_handler3 = TimerHandle.init(20, &handle3, @ptrCast(&wr));
    var t3: Timers.TimerQueue.Node = undefined;
    t3.init(timer_handler3);

    Timers.schedule(&timerQueue, &t3, &cxt);

    try std.testing.expect(!timerQueue.is_empty());
    try std.testing.expect(timerQueue.size() == 3);
    // The tail must be the timer_handler2 since is larger.
    try std.testing.expect(Timers.TimerQueue.Node.fromQueue(timerQueue.prev).data.time_ms == timer_handler2.time_ms);
    // The first element must be the timer_handler3 since it is the shorter.
    try std.testing.expect(Timers.TimerQueue.Node.fromQueue(timerQueue.next).data.time_ms == timer_handler3.time_ms);

    cxt.time = cxt.time.addDuration(.{ .raw = std.Io.Duration.fromMilliseconds(1000), .clock = .boot });
    try std.testing.expect(t3.data.schedule_time.raw.toMilliseconds() > 0);

    try Timers.poll_timers(&timerQueue, &cxt);
}
