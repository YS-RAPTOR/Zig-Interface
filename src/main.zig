const Interface = @import("interface.zig");
const std = @import("std");

const Shape = Interface.Init(struct {
    fn Create(Self: type) type {
        return struct {
            // function gets added to vtable
            pub fn perimeter(self: Self) isize {
                return self.vtab.perimeter(self.ptr);
            }

            pub fn area(self: Self) isize {
                return self.vtab.area(self.ptr);
            }

            // underscore at the end of the function idicates that it is not added to the vtable
            pub fn printInfo_(self: Self) void {
                std.debug.print("Shape. Area: {}. Perimeter: {}.\n", .{ self.area(), self.perimeter() });
            }
        };
    }
}.Create);

const Rectangle = struct {
    width: isize,
    height: isize,

    pub fn area(self: *@This()) isize {
        return self.width * self.height;
    }

    pub fn perimeter(self: *@This()) isize {
        return 2 * (self.width + self.height);
    }

    pub fn shape(self: *@This()) Shape {
        return Shape.init(self);
    }
};

const Square = struct {
    side: isize,

    pub fn area(self: *@This()) isize {
        return self.side * self.side;
    }

    pub fn perimeter(self: *@This()) isize {
        return 4 * self.side;
    }

    pub fn shape(self: *@This()) Shape {
        return Shape.init(self);
    }
};

pub fn main() !void {
    var rect = Rectangle{ .width = 10, .height = 20 };
    var square = Square{ .side = 10 };

    var shape1 = rect.shape();
    var shape2 = square.shape();

    std.debug.print("Rectangle. Area: {}. Perimeter: {}.\n", .{ shape1.area(), shape1.perimeter() });
    std.debug.print("Square. Area: {}. Perimeter: {}.\n", .{ shape2.area(), shape2.perimeter() });

    shape1.printInfo_();
    shape2.printInfo_();
}
