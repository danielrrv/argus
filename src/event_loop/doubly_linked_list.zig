const std = @import("std");

//Circular Doubly Linked List Type
pub fn DoublyLinkedList(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Node = struct {
            data: T,
            queue: Self,

            pub fn init(self: *Node, data: T) void {
                self.data = data;
                self.queue.init();
            }
            // Recovers the Parent Node given the pointer of queue member.
            pub fn fromQueue(ptr: *Self) *Node {
                return @alignCast(@fieldParentPtr("queue", ptr));
            }
        };

        prev: *Self,
        next: *Self,

        pub fn init(self: *Self) void {
            self.next = self; // head
            self.prev = self; // tail
        }

        pub fn size(self: *Self) i32 {
            var head = self.next;
            var counter: i32 = 0;
            while (head != self) {
                counter += 1;
                head = head.next;
            }
            return counter;
        }

        pub fn peek(self: *Self) *Self {
            return self.next;
        }

        pub fn last_value(self: *Self) *Self {
            return self.prev;
        }

        pub fn add_after(self: *Self, p: *Self, o: *Self) void {
            if (!self.exist(p)) return;
            p.next.prev = o;
            o.next = p.next;
            p.next = o;
            o.prev = p;
        }

        pub fn add_before(self: *Self, p: *Self, o: *Self) void {
            // const name = @typeName(@TypeOf(o));
            // std.log.err("{s}", .{name});
            if (!self.exist(p)) return;
            p.prev.next = o;
            o.next = p;

            p.prev = o;
            o.prev = p.prev;
        }

        // Add a batch/Node to this instance at the end.
        pub fn add_at_end(self: *Self, other: *Self) void {
            const tail = self.prev;
            // The other's head points to the current tail.
            other.prev = tail;
            // The other's tail points back to be current head.
            other.next = self;
            // The current's tail then points to other node.
            tail.next = other;
            // Finally the head of this points to other node since is circular doublyLinked list.
            self.prev = other;
        }
        // Add a batch/Node to this instance at the beggining.
        pub fn add_at_front(self: *Self, other: *Self) void {
            //The first element of other should point to first element of self.
            other.next = self.next;
            // Then, the first element of self should point back to other.
            self.next.prev = other;
            // Then other's tail now should be self.
            other.prev = self;
            // And finally first element of the self should be other.
            self.next = other;
        }
        // Remove the last Node from this queue element.
        pub fn pop(self: *Self) ?*Self.Node {
            if (self.is_empty()) {
                return null;
            }
            const tail = self.prev;
            //Since we are going to remove last Node/queue,
            //1. previous's next should point back to self.
            tail.prev.next = self;
            //2. Self's tail should point to the previous element before it.
            self.prev = tail.prev;
            //Wrap up the queue with itself.
            tail.init();
            return Node.fromQueue(tail);
        }

        // Remove the first Node from this queue element.
        pub fn shift(self: *Self) ?*Self.Node {
            if (self.is_empty()) {
                return null;
            }
            const first = self.peek();
            self.next = first.next;
            first.next.prev = self;
            first.init();
            return Node.fromQueue(first);
        }

        // Insert other queue in this current list.
        // See https://github.com/nodejs/node/blob/main/deps/uv/src/queue.h#L44
        pub fn splice(self: *Self, other: *Self) void {
            if (other.is_empty()) return;
            // Bridge self's tail to other's first element
            self.prev.next = other.next;
            other.next.prev = self.prev;
            // Bridge other's tail to self's head
            other.prev.next = self;
            self.prev = other.prev;
        }

        pub fn visit(self: *Self, visitor_fn: *const fn (_self: *Self) void) void {
            var current = self.next;
            while (current != self) {
                visitor_fn(current);
                current = current.next;
            }
        }

        pub fn delete(self: *Self, o: *Self) bool {
            if (self.is_empty() or o.is_empty()) return false;

            var current = self.next;
            while (current != self) {
                if (current == o) {
                    current.prev.next = current.next;
                    current.next.prev = current.prev;
                    current.init();
                    return true;
                }
                current = current.next;
            }
            return false;
        }

        // Remove a batch of T from Queue.
        pub fn remove(self: *Self, batch: *Self) bool {
            if (self.is_empty() and batch.is_empty()) return false;
            //First element of self.
            var current = self.next;
            // Two pointer sentinels.
            var left: ?*Self = undefined;
            var right: ?*Self = undefined;

            while (current != self) {
                //Finding the head of the batch.
                if (current == batch.next) {
                    left = current;
                }
                // Finding the tail of the batch
                if (current == batch.prev) {
                    right = current;
                }
                current = current.next;
                // std.debug.print("atrapado",.{});
            }
            //See https://github.com/nodejs/node/blob/main/deps/uv/src/queue.h#L85
            if (left) |l| {
                if (right) |r| {
                    // The previous element before the head of batch should point to next vaue after tail.
                    l.prev.next = r.next;
                    // The next value after the tail of batch should point to previous element before the head of batch.
                    r.next.prev = l.prev;
                    //Wrap this node toward it.
                    batch.prev = batch;

                    return true;
                }
            } else unreachable;
            return false;
        }

        pub fn exist(self: *Self, o: *Self) bool {
            if (self.is_empty() or o.is_empty()) return false;
            var current = self.next;
            while (current != self) {
                if (current == o) {
                    return true;
                }
                current = current.next;
            }
            return false;
        }

        pub fn is_empty(self: *Self) bool {
            return self.next == self;
        }

        pub fn print(head: *Self, io: std.Io, writer: std.Io.File) !void {
            var buff: [1024]u8 = undefined;
            if (head.is_empty()) {
                const message = try std.fmt.bufPrint(&buff, "Queue is empty\n", .{});
                try writer.writeStreamingAll(io, message);
                return;
            }

            var current = head.next;
            var first = true;

            while (current != head) {
                const task = Node.fromQueue(current);

                // Add the delimiter arrow if it isn't the first item
                if (!first) {
                    try writer.writeStreamingAll(io, " <-> ");
                }

                const message = try std.fmt.bufPrint(&buff, "{s}", .{task.data});
                try writer.writeStreamingAll(io, message);

                first = false;
                current = current.next;
            }
            try writer.writeStreamingAll(io, "\n");
        }
    };
}

test "node.init" {
    const QueueOfU8 = DoublyLinkedList([]const u8);
    var city_a: QueueOfU8.Node = undefined;
    city_a.init("NY");
    var city_b: QueueOfU8.Node = undefined;
    city_b.init("MT");
    var city_c: QueueOfU8.Node = undefined;
    city_c.init("DC");
    var city_d: QueueOfU8.Node = undefined;
    city_d.init("WT");

    try std.testing.expectEqualStrings("NY", city_a.data);
    try std.testing.expectEqualStrings("MT", city_b.data);
    try std.testing.expectEqualStrings("DC", city_c.data);
    try std.testing.expectEqualStrings("WT", city_d.data);
}

test "queue.add_at_end" {
    const QueueOfU8 = DoublyLinkedList([]const u8);
    var stops: QueueOfU8 = undefined;
    stops.init();

    var city_a: QueueOfU8.Node = undefined;
    city_a.init("NY");
    var city_b: QueueOfU8.Node = undefined;
    city_b.init("MT");
    var city_c: QueueOfU8.Node = undefined;
    city_c.init("DC");
    var city_d: QueueOfU8.Node = undefined;
    city_d.init("WT");

    stops.add_at_end(&city_a.queue);
    stops.add_at_end(&city_b.queue);
    stops.add_at_end(&city_c.queue);
    stops.add_at_end(&city_d.queue);

    try std.testing.expect(&city_a == QueueOfU8.Node.fromQueue(stops.next));
    try std.testing.expect(&city_d == QueueOfU8.Node.fromQueue(stops.prev));

    try std.testing.expectEqual(stops.size(), 4);
}

test "queue.add_at_front" {
    const QueueOfU8 = DoublyLinkedList([]const u8);
    var stops: QueueOfU8 = undefined;
    stops.init();

    var city_a: QueueOfU8.Node = undefined;
    city_a.init("NY");
    var city_b: QueueOfU8.Node = undefined;
    city_b.init("MT");
    var city_c: QueueOfU8.Node = undefined;
    city_c.init("DC");
    var city_d: QueueOfU8.Node = undefined;
    city_d.init("WT");

    stops.add_at_front(&city_a.queue);
    stops.add_at_front(&city_b.queue);
    stops.add_at_front(&city_c.queue);
    stops.add_at_front(&city_d.queue);

    try std.testing.expect(&city_d == QueueOfU8.Node.fromQueue(stops.next));
    try std.testing.expect(&city_a == QueueOfU8.Node.fromQueue(stops.prev));

    try std.testing.expectEqual(stops.size(), 4);
}
test "queue.add_after" {
    const QueueOfU8 = DoublyLinkedList([]const u8);
    var stops: QueueOfU8 = undefined;
    stops.init();

    var city_a: QueueOfU8.Node = undefined;
    city_a.init("NY");
    var city_b: QueueOfU8.Node = undefined;
    city_b.init("MT");
    var city_c: QueueOfU8.Node = undefined;
    city_c.init("DC");
    var city_d: QueueOfU8.Node = undefined;
    city_d.init("WT");

    stops.add_at_end(&city_a.queue);
    stops.add_at_end(&city_b.queue);
    stops.add_at_end(&city_c.queue);
    stops.add_at_end(&city_d.queue);

    try std.testing.expectEqual(stops.size(), 4);
    var city_emergency: QueueOfU8.Node = undefined;
    city_emergency.init("EM");

    stops.add_after(&city_b.queue, &city_emergency.queue);
    try std.testing.expectEqual(stops.size(), 5);

    try std.testing.expect(city_b.queue.next == &city_emergency.queue);
    try std.testing.expect(&city_emergency.queue == city_c.queue.prev);
}
test "queue.add_before" {
    const QueueOfU8 = DoublyLinkedList([]const u8);
    var stops: QueueOfU8 = undefined;
    stops.init();

    var city_a: QueueOfU8.Node = undefined;
    city_a.init("NY");
    var city_b: QueueOfU8.Node = undefined;
    city_b.init("MT");
    var city_c: QueueOfU8.Node = undefined;
    city_c.init("DC");
    var city_d: QueueOfU8.Node = undefined;
    city_d.init("WT");

    stops.add_at_end(&city_a.queue);
    stops.add_at_end(&city_b.queue);
    stops.add_at_end(&city_c.queue);
    stops.add_at_end(&city_d.queue);

    try std.testing.expectEqual(stops.size(), 4);

    var city_emergency: QueueOfU8.Node = undefined;
    city_emergency.init("EM");

    stops.add_before(&city_b.queue, &city_emergency.queue);
    try std.testing.expectEqual(stops.size(), 5);

    try std.testing.expect(city_b.queue.prev == &city_emergency.queue);
    try std.testing.expect(&city_emergency.queue == city_a.queue.next);

    var city_fuel: QueueOfU8.Node = undefined;
    city_fuel.init("FL");

    stops.add_before(&city_d.queue, &city_fuel.queue);
    try std.testing.expectEqual(stops.size(), 6);

    try std.testing.expect(city_d.queue.prev == &city_fuel.queue);
    try std.testing.expect(city_d.queue.prev == &city_fuel.queue);
}

test "queue.empty" {
    const QueueOfU8 = DoublyLinkedList([]const u8);
    var queue: QueueOfU8 = undefined;
    queue.init();
    try std.testing.expect(queue.is_empty());
}

test "queue.pop" {
    const QueueOfU8 = DoublyLinkedList([]const u8);
    var city_a: QueueOfU8.Node = undefined;
    city_a.init("NY");
    var city_b: QueueOfU8.Node = undefined;
    city_b.init("MT");
    var city_c: QueueOfU8.Node = undefined;
    city_c.init("DC");
    var city_d: QueueOfU8.Node = undefined;
    city_d.init("WT");

    var stops: QueueOfU8 = undefined;
    stops.init();
    stops.add_at_end(&city_a.queue);
    stops.add_at_end(&city_b.queue);
    stops.add_at_end(&city_c.queue);
    stops.add_at_end(&city_d.queue);

    const removed = stops.pop();
    try std.testing.expect(removed == &city_d);
    try std.testing.expect(QueueOfU8.Node.fromQueue(stops.prev) == &city_c);
    try std.testing.expect(QueueOfU8.Node.fromQueue(stops.next) == &city_a);
    try std.testing.expect(stops.prev.next == &stops);
    try std.testing.expectEqualStrings(city_b.data, QueueOfU8.Node.fromQueue(stops.prev.prev).data);
    try std.testing.expectEqual(QueueOfU8.Node.fromQueue(stops.prev.prev), &city_b);
}

test "queue.splice" {
    const QueueOfU8 = DoublyLinkedList([]const u8);
    var city_a: QueueOfU8.Node = undefined;
    city_a.init("NY");
    var city_b: QueueOfU8.Node = undefined;
    city_b.init("MT");
    var city_c: QueueOfU8.Node = undefined;
    city_c.init("DC");
    var city_d: QueueOfU8.Node = undefined;
    city_d.init("WT");

    var main_queue: QueueOfU8 = undefined;

    main_queue.init();

    main_queue.add_at_end(&city_a.queue);
    main_queue.add_at_end(&city_b.queue);
    main_queue.add_at_end(&city_c.queue);
    main_queue.add_at_end(&city_d.queue);

    //Batch 2
    var city_e: QueueOfU8.Node = undefined;
    city_e.init("QC");
    var city_f: QueueOfU8.Node = undefined;
    city_f.init("AL");
    var city_g: QueueOfU8.Node = undefined;
    city_g.init("FL");
    var city_h: QueueOfU8.Node = undefined;
    city_h.init("NE");

    var batch_queue: QueueOfU8 = undefined;
    batch_queue.init();

    batch_queue.add_at_end(&city_e.queue);
    batch_queue.add_at_end(&city_f.queue);
    batch_queue.add_at_end(&city_g.queue);
    batch_queue.add_at_end(&city_h.queue);

    main_queue.splice(&batch_queue);

    try std.testing.expect(main_queue.prev == batch_queue.prev);
}

test "queue.remove" {
    const QueueOfU8 = DoublyLinkedList([]const u8);
    var city_a: QueueOfU8.Node = undefined;
    city_a.init("NY");
    var city_b: QueueOfU8.Node = undefined;
    city_b.init("MT");
    var city_c: QueueOfU8.Node = undefined;
    city_c.init("DC");
    var city_d: QueueOfU8.Node = undefined;
    city_d.init("WT");

    var main_queue: QueueOfU8 = undefined;

    main_queue.init();

    main_queue.add_at_end(&city_a.queue);
    main_queue.add_at_end(&city_b.queue);
    main_queue.add_at_end(&city_c.queue);
    main_queue.add_at_end(&city_d.queue);

    //Batch 2
    var city_e: QueueOfU8.Node = undefined;
    city_e.init("QC");
    var city_f: QueueOfU8.Node = undefined;
    city_f.init("AL");
    var city_g: QueueOfU8.Node = undefined;
    city_g.init("FL");
    var city_h: QueueOfU8.Node = undefined;
    city_h.init("NE");

    var batch_1_queue: QueueOfU8 = undefined;
    batch_1_queue.init();

    batch_1_queue.add_at_end(&city_e.queue);
    batch_1_queue.add_at_end(&city_f.queue);
    batch_1_queue.add_at_end(&city_g.queue);
    batch_1_queue.add_at_end(&city_h.queue);

    main_queue.splice(&batch_1_queue);

    //Batch 3
    var city_i: QueueOfU8.Node = undefined;
    city_i.init("AN");
    var city_j: QueueOfU8.Node = undefined;
    city_j.init("AT");
    var city_k: QueueOfU8.Node = undefined;
    city_k.init("CR");
    var city_l: QueueOfU8.Node = undefined;
    city_l.init("TX");

    var batch_2_queue: QueueOfU8 = undefined;
    batch_2_queue.init();

    batch_2_queue.add_at_end(&city_i.queue);
    batch_2_queue.add_at_end(&city_j.queue);
    batch_2_queue.add_at_end(&city_k.queue);
    batch_2_queue.add_at_end(&city_l.queue);

    main_queue.splice(&batch_2_queue);

    //Case 1:
    // Make sure the tail is the batch_2_queue tail.
    try std.testing.expect(main_queue.prev == batch_2_queue.prev);

    var removed = main_queue.remove(&batch_2_queue);
    //Should have removed
    try std.testing.expect(removed);
    try std.testing.expect(main_queue.prev == batch_1_queue.prev);

    //Case 2: Now remove the one in the middle.
    main_queue.splice(&batch_2_queue);
    // Make sure the tail is the batch_2_queue tail.
    try std.testing.expect(main_queue.prev == batch_2_queue.prev);

    removed = main_queue.remove(&batch_1_queue);

    //Should have removed
    try std.testing.expect(removed);
    // The main tail should the batch_2_queue tail.
    try std.testing.expect(main_queue.prev == batch_2_queue.prev);

    try std.testing.expect(batch_1_queue.prev == &batch_1_queue);

    try std.testing.expectEqualStrings(city_a.data, QueueOfU8.Node.fromQueue(main_queue.next).data);
}

test "queue.shift" {
    const QueueOfU8 = DoublyLinkedList([]const u8);
    var city_a: QueueOfU8.Node = undefined;
    city_a.init("NY");
    var city_b: QueueOfU8.Node = undefined;
    city_b.init("MT");
    var city_c: QueueOfU8.Node = undefined;
    city_c.init("DC");
    var city_d: QueueOfU8.Node = undefined;
    city_d.init("WT");

    var main_queue: QueueOfU8 = undefined;

    main_queue.init();

    main_queue.add_at_end(&city_a.queue);
    main_queue.add_at_end(&city_b.queue);
    main_queue.add_at_end(&city_c.queue);
    main_queue.add_at_end(&city_d.queue);

    const first = main_queue.shift();
    if (first) |f| {
        try std.testing.expectEqualStrings(f.data, city_a.data);
        try std.testing.expect(&city_b.queue == main_queue.next);
        try std.testing.expect(main_queue.size() == 3);
    }
}


test "queue.delete" {
    const QueueOfU8 = DoublyLinkedList([]const u8);
    var city_a: QueueOfU8.Node = undefined;
    city_a.init("NY");
    var city_b: QueueOfU8.Node = undefined;
    city_b.init("MT");
    var city_c: QueueOfU8.Node = undefined;
    city_c.init("DC");
    var city_d: QueueOfU8.Node = undefined;
    city_d.init("WT");

    var main_queue: QueueOfU8 = undefined;

    main_queue.init();

    main_queue.add_at_end(&city_a.queue);
    main_queue.add_at_end(&city_b.queue);
    main_queue.add_at_end(&city_c.queue);
    main_queue.add_at_end(&city_d.queue);
    try std.testing.expect(main_queue.exist(&city_b.queue));
    _ = main_queue.delete(&city_b.queue);
    try std.testing.expect(!main_queue.exist(&city_b.queue));
    
}