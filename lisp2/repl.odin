package lisp2

import "core:testing"
Repl :: struct {
	env:  ^Environment,
	last: ^Expression,
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

repl_swap_last :: proc(repl: ^Repl, expr: ^Expression) {
	free(repl.last)
	repl.last = clone(expr)
}

// Result in last after eval
repl_step :: proc(repl: ^Repl, src: string) -> Eval_Error {
	defer free_all(context.temp_allocator)

	reader: Reader_State
	reader.src = src

	rexpr := read(&reader) or_return
	eexpr := eval(repl.env, rexpr) or_return
	repl_swap_last(repl, eexpr)
	return nil
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

