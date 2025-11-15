package lisp2

import "core:strings"
import "core:testing"

Environment :: struct {
	parent: ^Environment,
	data:   map[string]^Expression,
}

env_init :: proc(env: ^Environment, allocator := context.allocator, loc := #caller_location) {
	data := make(map[string]^Expression, allocator, loc)
	env.data = data
}

// clone all values and takes keeps the same reference for the parent
env_clone :: proc(
	from: Environment,
	to: ^Environment,
	allocator := context.allocator,
	loc := #caller_location,
) {
	for key, expr in from.data {
		to.data[strings.clone(key, allocator, loc)] = clone(expr)
	}
	to.parent = from.parent
}

// Clear all entries in the environment
env_clear :: proc(env: ^Environment) {
	for key, expr in env.data {
		delete(key) // delete all string keys
		expression_free(expr) // TODO wonder how this will work, will not stuff depend on each other
	}
}

// Dellocate the whole env so it no longer exist
env_destroy :: proc(env: ^Environment) {
	env_clear(env)
	delete(env.data)
	free(env)
}

// Copy the provided expr into the environment
env_add :: proc(env: ^Environment, k: string, v: ^Expression) {
	if env_contains(env^, k) {
		env_delete(env, k)
	}
	// TODO i dont have to delete the key since its the same key, i coule just change the value
	env.data[strings.clone(k)] = clone(v) // use the default allcoator since the map owns data
}

// Remove an entry and deallocate its key and value
env_delete :: proc(env: ^Environment, k: string) {
	k, v := delete_key(&env.data, k)
	if k != "" {
		delete(k)
		expression_free(v)
	}
}

// Copy the associated value or return an error if no key found
// Check if not find in env contionue checking parent
env_get :: proc(
	env: ^Environment,
	k: string,
	allocator := context.temp_allocator,
	loc := #caller_location,
) -> (
	^Expression,
	Eval_Error,
) {
	if env_contains(env^, k) {
		return clone(env.data[k], allocator, loc), nil
	} else if env.parent != nil {
		return env_get(env.parent, k)
	}
	return nil, .Symbol_Not_Found
}

env_contains :: proc(env: Environment, k: string) -> bool {
	return k in env.data
}

env_add_builtin :: proc(env: ^Environment, k: string, fn: Builtin) {
	expr: Expression
	func_expr: BuiltinFunction
	func_expr.fn = fn
	expr = func_expr
	env_add(env, k, &expr)
}

@(test)
test_can_add_and_get_number :: proc(t: ^testing.T) {
	expr := new(Expression)
	expr^ = Number {
		value = 33,
	}
	defer free_all(context.temp_allocator)
	env := new(Environment)
	env_init(env)
	defer env_destroy(env)
	env_add(env, "number", expr)
	result, _ := env_get(env, "number")
	if num, ok := result.(Number); ok {
		testing.expect(t, num.value == 33)
	} else {
		expr_print(result)
		testing.expect(t, false)
	}

}

