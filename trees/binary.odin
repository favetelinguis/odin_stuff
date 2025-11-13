package trees

import "core:mem"
import "core:slice"
import "core:testing"
// post-order traversal
// in-order traversal
// pre-order traversal

// Linked representation
Node :: struct {
	data:  int,
	left:  ^Node,
	right: ^Node,
}

Root :: ^Node

// also know as depth-first
pre_order_traversal :: proc(tree: Root, result: ^[dynamic]int) {
	if tree == nil {
		return
	}
	append(result, tree.data)
	pre_order_traversal(tree.left, result)
	pre_order_traversal(tree.right, result)
}

in_order_traversal :: proc(tree: Root, result: ^[dynamic]int) {
	if tree == nil {
		return
	}
	in_order_traversal(tree.left, result)
	append(result, tree.data)
	in_order_traversal(tree.right, result)
}

post_order_traversal :: proc(tree: Root, result: ^[dynamic]int) {
	if tree == nil {
		return
	}
	post_order_traversal(tree.left, result)
	post_order_traversal(tree.right, result)
	append(result, tree.data)
}

@(test)
traversal_test :: proc(t: ^testing.T) {
	result: [dynamic]int
	defer delete(result)
	left := Node {
		data = 1,
	}
	right := Node {
		data = 3,
	}
	root_node := Node {
		data  = 2,
		left  = &left,
		right = &right,
	}
	root: Root = &root_node

	clear(&result)
	pre_order_traversal(root, &result)
	testing.expect(t, slice.equal(result[:], ([]int{2, 1, 3})), "pre_order_traversal")

	clear(&result)
	in_order_traversal(root, &result)
	testing.expect(t, slice.equal(result[:], ([]int{1, 2, 3})), "in_order_traversal")

	clear(&result)
	post_order_traversal(root, &result)
	testing.expect(t, slice.equal(result[:], ([]int{1, 3, 2})), "post_order_traversal")
}
