package lisp

import "base:builtin"
import "core:encoding/base32"
import "core:fmt"
import "core:log"
import "core:strings"
import "core:testing"
/**
*** Expressions have values.
*** Statments have effects
*** Declaration establish binding in the namespace, TODO how do i handle def and defn etc
***/


// Expressions
Expr_Base :: struct {
	isQuoted: bool, // TODO this is not supported anywhere
}


SExpr :: struct {
	using base: Expr_Base,
	elements:   [dynamic]^Expr, // TODO make this a static array and put a limit how many args i can have, slice to a static array?
}
Symbol :: struct {
	using base32: Expr_Base,
	name:         string,
}

Number :: struct {
	using base: Expr_Base,
	value:      int,
}

Builtin :: proc(_: ^Environment, _: ^Expr) -> ^Expr
Function :: struct {
	fn: Builtin,
}

Error :: struct {
	reason: string,
}

Expr :: union {
	Symbol,
	Number,
	SExpr,
	Function,
	Error,
}

expr_make_error :: proc(
	msg: string,
	allocator := context.temp_allocator,
	loc := #caller_location,
) -> ^Expr {
	expr := new(Expr, allocator, loc)
	expr^ = Error {
		reason = strings.clone(msg, allocator, loc),
	}
	return expr
}

expr_init_number :: proc(expr: ^Expr, value: int) {
	expr^ = Number {
		value = value,
	}
}

expr_init_function :: proc(expr: ^Expr, builtin: Builtin) {
	expr^ = Function {
		fn = builtin,
	}
}

// On get it should copy to temp_allocator since one repl cycle owns data
// On add it should copy to allocator since env owns data
// TODO do i need better error reporting here or just use expression error
expr_copy :: proc(expr: ^Expr, allocator := context.allocator, loc := #caller_location) -> ^Expr {

	#partial switch e in expr {
	case Error:
		return expr_make_error(e.reason, allocator)
	case Function:
		new_expr := new(Expr, allocator, loc)
		expr_init_function(new_expr, e.fn)
		return new_expr
	case Number:
		new_expr := new(Expr, allocator, loc)
		expr_init_number(new_expr, e.value)
		return new_expr
	}
	panic("")
}

expr_print :: proc(expr: ^Expr, depth := 0) {
	if expr == nil {
		fmt.println("nil")
		return
	}

	// TODO need to check if quoted and print that also
	switch e in expr {
	case Number:
		fmt.printf("%d", e.value)
	case Symbol:
		fmt.printf("%s", e.name)
	case SExpr:
		fmt.print("(")
		for element, i in e.elements {
			if i > 0 do fmt.print(" ")
			expr_print(element, depth + 1)
		}
		fmt.print(")")
	case Error:
		fmt.print(e.reason)
	case Function:
		fmt.print("<function>")
	}
}

@(test)
test_copy :: proc(t: ^testing.T) {
	expr: Expr
	expr_init_number(&expr, 33)
	defer free_all(context.temp_allocator)
	expr2 := expr_copy(&expr)
	free(expr2)
	// expect no memory le
}

