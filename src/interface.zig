const builtin = @import("std").builtin;
const debug = struct {
    pub inline fn comptimeAssert(comptime assertion: bool, comptime message: []const u8, comptime args: anytype) !void {
        if (assertion) {} else {
            @compileLog(message, args);
            @compileError(message);
        }
    }
};

pub fn Init(comptime makeTypeFn: fn (type) type) type {
    const Dummy = struct {
        vtab: *anyopaque,
        ptr: *anyopaque,
        pub usingnamespace makeTypeFn(@This());
    };

    const VTable = CreateVTable(Dummy);
    return struct {
        vtab: *const VTable,
        ptr: *anyopaque,
        const Self = @This();
        pub usingnamespace makeTypeFn(Self);

        pub fn init(obj: anytype) Self {
            const Ptr = @TypeOf(obj);
            const ptr_info = @typeInfo(Ptr);
            comptime try debug.comptimeAssert(
                ptr_info == .Pointer,
                "Init must be passed a pointer",
                .{ptr_info},
            );
            comptime try debug.comptimeAssert(
                ptr_info.Pointer.size == .One,
                "Init must be passed a pointer of size one",
                .{ptr_info.Pointer.size},
            );
            comptime try debug.comptimeAssert(
                @typeInfo(ptr_info.Pointer.child) == .Struct,
                "Init must be passed a pointer of which points to a struct",
                .{ptr_info.Pointer.child},
            );

            const v_table_type_info = @typeInfo(VTable);
            comptime var v_table: VTable = undefined;

            inline for (v_table_type_info.Struct.fields) |field| {
                comptime try debug.comptimeAssert(
                    @hasDecl(ptr_info.Pointer.child, field.name),
                    "Does not implement " ++ field.name,
                    .{},
                );

                const decl = @field(ptr_info.Pointer.child, field.name);
                const decl_type_info = @typeInfo(@TypeOf(decl));

                comptime try debug.comptimeAssert(
                    decl_type_info == .Fn,
                    "Must implement the function " ++ field.name,
                    .{},
                );

                const impl_fn = decl_type_info.Fn;
                const interface_fn = @typeInfo(@typeInfo(field.type).Pointer.child).Fn;
                const standard_error = ". Function signature of " ++ field.name ++ " does not match";

                comptime try debug.comptimeAssert(
                    impl_fn.calling_convention == interface_fn.calling_convention,
                    "The Calling Conventions of the functions do not match" ++ standard_error,
                    .{},
                );
                comptime try debug.comptimeAssert(
                    impl_fn.is_var_args == interface_fn.is_var_args,
                    "One of the functions accept Variable Arguements" ++ standard_error,
                    .{},
                );
                comptime try debug.comptimeAssert(
                    impl_fn.is_generic == interface_fn.is_generic,
                    "One of the functions is generic" ++ standard_error,
                    .{},
                );
                comptime try debug.comptimeAssert(
                    impl_fn.params.len == interface_fn.params.len,
                    "The function Parameter Count does not match" ++ standard_error,
                    .{},
                );

                inline for (impl_fn.params, interface_fn.params, 0..) |impl_param, interface_param, index| {
                    const standard_param_error = "Function Parameters do not match for field " ++ field.name;
                    comptime try debug.comptimeAssert(
                        impl_param.is_generic == interface_param.is_generic,
                        standard_param_error,
                        .{index},
                    );
                    comptime try debug.comptimeAssert(
                        impl_param.is_noalias == interface_param.is_noalias,
                        standard_param_error,
                        .{index},
                    );

                    if (interface_param.type == *anyopaque) {
                        comptime try debug.comptimeAssert(
                            impl_param.type != null,
                            "Implemented parameter type is null. " ++ standard_param_error,
                            .{index},
                        );
                        comptime try debug.comptimeAssert(
                            @typeInfo(impl_param.type.?) == .Pointer,
                            "Parameter is not a Pointer. " ++ standard_param_error,
                            .{index},
                        );
                    } else {
                        comptime try debug.comptimeAssert(
                            impl_param.type == interface_param.type,
                            standard_param_error,
                            .{index},
                        );
                    }
                }

                @field(v_table, field.name) = @ptrCast(&decl);
            }
            const vtab = v_table;
            return .{ .ptr = obj, .vtab = &vtab };
        }
    };
}

fn CreateVTable(InterfaceType: type) type {
    const type_info = @typeInfo(InterfaceType);
    comptime try debug.comptimeAssert(
        type_info == .Struct,
        "Must pass a Struct into the CreateInterfaceType function",
        .{type_info},
    );

    var v_table_fields: []const builtin.Type.StructField = &[_]builtin.Type.StructField{};

    inline for (type_info.Struct.decls) |decl| {
        const is_static = decl.name[decl.name.len - 1] == '_';

        if (!is_static) {
            const name = decl.name;
            const actual_decl = @field(InterfaceType, decl.name);
            const DeclType = @TypeOf(actual_decl);
            const decl_type_info = @typeInfo(DeclType);

            if (decl_type_info == .Fn) {
                const f = decl_type_info.Fn;
                if (f.params[0].type != InterfaceType) continue;

                const VTableField = @Type(builtin.Type{
                    .Fn = .{
                        .calling_convention = switch (f.calling_convention) {
                            .Inline => .Unspecified,
                            else => f.calling_convention,
                        },
                        .is_generic = f.is_generic,
                        .is_var_args = f.is_var_args,
                        .params = Blk: {
                            var params: []const builtin.Type.Fn.Param = &[_]builtin.Type.Fn.Param{};
                            inline for (f.params) |param| {
                                params = params ++ .{.{
                                    .is_generic = param.is_generic,
                                    .is_noalias = param.is_noalias,
                                    .type = if (param.type == InterfaceType) *anyopaque else param.type,
                                }};
                            }
                            break :Blk params;
                        },
                        .return_type = if (f.return_type == InterfaceType) *anyopaque else f.return_type,
                    },
                });

                v_table_fields = v_table_fields ++ .{.{
                    .alignment = @alignOf(VTableField),
                    .default_value = null,
                    .is_comptime = false,
                    .name = name,
                    .type = *const VTableField,
                }};
            }
        }
    }

    return @Type(builtin.Type{
        .Struct = .{
            .decls = &[_]builtin.Type.Declaration{},
            .fields = v_table_fields,
            .is_tuple = false,
            .layout = type_info.Struct.layout,
        },
    });
}
