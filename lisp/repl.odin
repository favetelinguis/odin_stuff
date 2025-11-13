package lisp

import sa "core:container/small_array"
import "core:fmt"
import "core:log"
import "core:strconv"
import "core:testing"

Repl :: struct {
	env:  ^Environment,
	last: ^Expr,
}

repl_init :: proc(repl: ^Repl) {
	env := new(Environment)
	env_init(env)
	builtin_populate_env(env)
	repl.env = env
}

// TODO should prob send in allocator here since repl_init seperate alloc and init
repl_destroy :: proc(repl: ^Repl) {
	env_destroy(repl.env)
	free(repl.last)
	free(repl)
}

repl_swap_last :: proc(repl: ^Repl, expr: ^Expr) {
	free(repl.last)
	repl.last = expr_copy(expr)
}

// Result in last after eval
repl_step :: proc(repl: ^Repl, src: string) {
	expressions := parse_string(src, context.temp_allocator)
	defer free_all(context.temp_allocator)

	if len(expressions) == 0 {
		log.error("No expressions parsed")
		return
	}

	for expr in expressions {
		result := eval_expr(repl.env, expr)
		repl_swap_last(repl, result)
	}
}

@(test)
repl_test :: proc(t: ^testing.T) {
	repl := new(Repl)
	repl_init(repl)
	defer repl_destroy(repl)

	repl_step(repl, "(+ 4 2)")
	repl_step(repl, "(+ 2 2 (* 2 4) (- 2 12) (/ 10 2))")
	if result, ok := repl.last.(Number); ok {
		testing.expect(t, result.value == 7)
	} else {
		testing.fail(t)
	}
}

