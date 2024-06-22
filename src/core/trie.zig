const std = @import("std");
const print = std.debug.print;

const Node = struct {
    value: u8,
    children: std.AutoHashMap(u8, *Node),
    end: bool,
};

fn newNode(value: u8) !*Node {
    const node = try std.heap.page_allocator.create(Node);

    node.* = Node{
        .value = value,
        .children = std.AutoHashMap(u8, *Node).init(std.heap.page_allocator),
        .end = false,
    };

    return node;
}

pub fn newTrie(value: u8) !Trie {
    const head = try newNode(value);
    return Trie{
        .root = head,
    };
}

const Trie = struct {
    const Self = @This();
    root: ?*Node,

    pub fn insert(self: *Self, str: []const u8) !void {
        var node = self.root;
        for (str) |c| {
            if (node == null) return;
            const exists = node.?.children.get(c);
            if (exists == null) {
                const new_node = try newNode(c);
                try node.?.children.put(c, new_node);
            }

            node = node.?.children.get(c);
        }
        node.?.end = true;
    }

    pub fn search(self: *Self, str: []const u8) bool {
        var node = self.root;
        for (str) |token| {
            if (node == null) return false;

            const exists = node.?.children.get(token);

            if (exists == null) {
                return false;
            }

            node = node.?.children.get(token);
        }
        return node.?.end;
    }

    fn addNode(self: *Self, char: u8) !void {
        const exists = self.root.children.get(char);

        if (exists == null) {
            return false;
        }
        return true;
    }
};

test "Create trie" {
    var trie = try newTrie('V');
    try trie.insert("hello");
    print("\n{c}\n", .{trie.root.?.*.children.get('h').?.value});

    const isThere = trie.search("hell");

    print("\n Is there {any}\n", .{isThere});
}
