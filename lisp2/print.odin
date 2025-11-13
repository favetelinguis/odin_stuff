package lisp2

import "core:fmt"

Print_Error :: struct {
	msg:  string,
	kind: Eval_Error, // TODO different enums for different errors
}

expr_print :: proc(start: ^Expression) {
	if start == nil {
		fmt.eprint("can not print nil expressions")
	}
	switch expr in start^ {
	case Symbol:
		fmt.print(" ", expr.name)
	case Number:
		fmt.print(" ", expr.value)
	case Function:
		fmt.print(" <function>")
	case Cons_Cell:
		// Recursively clone both car and cdr
		fmt.print("(")
		expr_print(expr.car)
		expr_print(expr.cdr)
		fmt.print(")")
	case NIL:
		fmt.print("nil ")
	case T:
		fmt.print("t ")
	}
}

