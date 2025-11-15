package lisp2

import "core:fmt"

Print_Error :: struct {
	msg:  string,
	kind: Eval_Error, // TODO different enums for different errors
}

expr_print :: proc(start: ^Expression) {
	switch expr in start^ {
	case Symbol:
		fmt.print(" ", expr.name)
	case Number:
		fmt.print(" ", expr.value)
	case BuiltinFunction:
		fmt.print(" <function>")
	case Lambda:
		fmt.print(" <lambda>") // TODO can imrove this printing with actual sexpr
	case Cons_Cell:
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

