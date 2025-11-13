package lisp

import "core:fmt"
import "core:testing"

eval_sexpr :: proc(env: ^Environment, expr: ^Expr) -> ^Expr {
	sexpr := expr.(SExpr)
	// Evaluate Children
	for child, i in sexpr.elements {
		sexpr.elements[i] = eval_expr(env, child)
	}

	// Error checking, if any child is an error the whole sexpr is an error
	for child, i in sexpr.elements {
		if err, ok := child.(Error); ok {
			return sexpr.elements[i]
		}
	}

	// Empty S-Expression
	if len(sexpr.elements) == 0 {
		return expr
	}

	// Single expresson
	if len(sexpr.elements) == 1 {
		return sexpr.elements[0]
	}

	// Ensure first element is a function after evaluation
	if _, ok := sexpr.elements[0].(Function); !ok {
		return expr_make_error("S-Expression do not start with function symbol")
	}

	// Evaluate function and return result
	fn_expr := sexpr.elements[0].(Function)
	return fn_expr.fn(env, expr)
}

eval_expr :: proc(env: ^Environment, expr: ^Expr) -> ^Expr {
	#partial switch e in expr {
	case Number, Error:
		return expr
	case Symbol:
		// Look up symbol value (could be a variable or build-in function)
		return env_get(env, e.name, context.temp_allocator)
	case SExpr:
		return eval_sexpr(env, expr)
	}
	return expr_make_error("unknown error")
}

