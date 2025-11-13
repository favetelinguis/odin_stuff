package lisp

import "core:strings"
import "core:testing"

// TODO i would like the environment to own all data

Environment :: struct {
	data: map[string]^Expr,
}

env_init :: proc(env: ^Environment, allocator := context.allocator) {
	data := make(map[string]^Expr)
	env.data = data
}

// Clear all entries in the environment
env_clear :: proc(env: ^Environment) {
	for key, expr in env.data {
		delete(key) // delete all string keys
		switch e in expr {
		case Function, Number:
			free(expr)
		case Symbol:
			delete(e.name)
			free(expr)
		case Error:
			delete(e.reason)
			free(expr)
		case SExpr:
			panic("no implemented")
		}
	}
}

// Dellocate the whole env so it no longer exist
env_destroy :: proc(env: ^Environment) {
	env_clear(env)
	delete(env.data)
	free(env)
}

// Copy the provided expr into the environment
env_add :: proc(env: ^Environment, k: string, v: ^Expr) {
	if env_contains(env^, k) {
		env_delete(env, k)
	}
	// TODO i dont have to delete the key since its the same key, i coule just change the value
	env.data[strings.clone(k)] = expr_copy(v) // use the default allcoator since the map owns data
}

// Remove an entry and deallocate its key and value
env_delete :: proc(env: ^Environment, k: string) {
	k, v := delete_key(&env.data, k)
	if k != "" {
		delete(k)
		free(v)
	}
}

// Copy the associated value or return an error if no key found
env_get :: proc(
	env: ^Environment,
	k: string,
	allocator := context.temp_allocator,
	loc := #caller_location,
) -> ^Expr {
	if env_contains(env^, k) {
		return expr_copy(env.data[k], allocator, loc)
	}
	return expr_make_error("unbound symbol")
}

env_contains :: proc(env: Environment, k: string) -> bool {
	return k in env.data
}

env_add_builtin :: proc(env: ^Environment, k: string, fn: Builtin) {
	expr: Expr
	func_expr: Function
	func_expr.fn = fn
	expr = func_expr
	env_add(env, k, &expr)
}

@(test)
test_can_add_and_get_number :: proc(t: ^testing.T) {
	expr: Expr
	expr_init_number(&expr, 33)
	defer free_all(context.temp_allocator)
	env := new(Environment)
	env_init(env)
	defer env_destroy(env)
	env_add(env, "number", &expr)
	result := env_get(env, "number")
	if num, ok := result.(Number); ok {
		testing.expect(t, num.value == 33)
	} else {
		expr_print(result)
		testing.expect(t, false)
	}

}

