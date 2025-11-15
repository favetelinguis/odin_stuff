package lisp2

import "core:testing"

// When function is called all children of the should have been fully evaluated into a list
builtin_op :: proc(env: ^Environment, args: ^Expression, op: rune) -> (^Expression, Eval_Error) {
	result_expr := new(Expression, context.temp_allocator)
	acc: int
	// init acc with first arg
	if first_arg, ok := car(args.(Cons_Cell)).(Number); ok {
		acc = first_arg.value
	}
	next := cdr(args.(Cons_Cell)) // skip first arg
	for {
		if _, ok := next.(NIL); ok {
			break
		}
		if num, ok := car(next.(Cons_Cell)).(Number); ok {
			switch op {
			case '+':
				acc += num.value
			case '-':
				acc -= num.value
			case '*':
				acc *= num.value
			case '/':
				if num.value == 0 {
					return nil, .Apply_Failure
				} else {
					acc /= num.value
				}
			}
		}
		next = cdr(next.(Cons_Cell))

	}
	result_expr^ = Number {
		value = acc,
	}
	return result_expr, nil
}

builtin_add :: proc(env: ^Environment, expr: ^Expression) -> (^Expression, Eval_Error) {
	return builtin_op(env, expr, '+')
}

builtin_sub :: proc(env: ^Environment, expr: ^Expression) -> (^Expression, Eval_Error) {
	return builtin_op(env, expr, '-')
}

builtin_mul :: proc(env: ^Environment, expr: ^Expression) -> (^Expression, Eval_Error) {
	return builtin_op(env, expr, '*')
}

builtin_div :: proc(env: ^Environment, expr: ^Expression) -> (^Expression, Eval_Error) {
	return builtin_op(env, expr, '/')
}

// Returns the expected number of fns added
builtin_populate_env :: proc(env: ^Environment) -> int {
	// Mathematical Functions
	env_add_builtin(env, "+", builtin_add)
	env_add_builtin(env, "-", builtin_sub)
	env_add_builtin(env, "*", builtin_mul)
	env_add_builtin(env, "/", builtin_div)
	env_add_builtin(env, "eval", eval)
	return 5
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

