const Interface = @import("interface.zig");
const std = @import("std");

const ActualInterface = Interface.Init(struct {
    fn Create(Self: type) type {
        return struct {
            // function gets added to vtable
            pub fn func1(self: Self) void {
                self.vtab.func1(self.ptr);
            }

            pub fn func2(self: Self, number: isize) void {
                self.vtab.func2(self.ptr, number);
            }

            // underscore at the end of the function idicates that it is not added to the vtable
            pub fn func3_(self: Self, number: isize) void {
                self.func1();
                self.func2(number);
            }
        };
    }
}.Create);

const Implementor = struct {
    val: i32,

    pub fn func1(self: *@This()) void {
        std.debug.print("Hello World {}\n", .{self.val});
    }

    pub fn func2(self: *@This(), number: isize) void {
        std.debug.print("Number: {} {}\n", .{ self.val, number });
    }

    pub fn actualInterface(self: *@This()) ActualInterface {
        return ActualInterface.init(self);
    }
};

pub fn main() !void {
    var someStruct = Implementor{ .val = 10 };

    const interface = someStruct.actualInterface();
    interface.func1();
    interface.func2(20);
    interface.func3_(10);
}
