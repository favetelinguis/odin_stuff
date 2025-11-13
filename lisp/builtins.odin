package lisp

import "core:testing"
// When function is called all children of the should have been fully evaluated
builtin_op :: proc(env: ^Environment, expr: ^Expr, op: rune) -> ^Expr {
	result_expr := new(Expr, context.temp_allocator)
	acc: int
	sexpr := expr.(SExpr)
	args := sexpr.elements[2:] // skip first since that is the Function
	acc = sexpr.elements[1].(Number).value
	for arg in args {
		switch op {
		case '+':
			acc += arg.(Number).value
		case '-':
			acc -= arg.(Number).value
		case '*':
			acc *= arg.(Number).value
		case '/':
			if arg.(Number).value == 0 {
				return expr_make_error("divison by zero not allowd")
			} else {
				acc /= arg.(Number).value
			}
		}
	}
	result_expr^ = Number {
		value = acc,
	}
	return result_expr
}

builtin_add :: proc(env: ^Environment, expr: ^Expr) -> ^Expr {
	return builtin_op(env, expr, '+')
}

builtin_sub :: proc(env: ^Environment, expr: ^Expr) -> ^Expr {
	return builtin_op(env, expr, '-')
}

builtin_mul :: proc(env: ^Environment, expr: ^Expr) -> ^Expr {
	return builtin_op(env, expr, '*')
}

builtin_div :: proc(env: ^Environment, expr: ^Expr) -> ^Expr {
	return builtin_op(env, expr, '/')
}

// Returns the expected number of fns added
builtin_populate_env :: proc(env: ^Environment) -> int {
	// Mathematical Functions
	env_add_builtin(env, "+", builtin_add)
	env_add_builtin(env, "-", builtin_sub)
	env_add_builtin(env, "*", builtin_mul)
	env_add_builtin(env, "/", builtin_div)
	return 4
}

@(test)
populate_env_test :: proc(t: ^testing.T) {
	env := new(Environment)
	env_init(env)
	defer env_destroy(env)
	defer free_all(context.temp_allocator)
	expected_fns_in_env := builtin_populate_env(env)

	testing.expect(t, len(env.data) == expected_fns_in_env, "env not populated with all builtins")
}

