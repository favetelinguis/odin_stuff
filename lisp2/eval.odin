package lisp2

import "core:fmt"
import "core:strings"

// Can evaluate quoted

is_quoted :: proc(expr: ^Expression) -> bool {
	if c, ok := expr.(Cons_Cell); ok {
		if s, ok2 := car(c).(Symbol); ok2 {
			return s.name == "quote"
		}
	}
	return false
}

is_cons_cell :: proc(expr: ^Expression) -> bool {
	_, ok := expr.(Cons_Cell)
	return ok
}

clone :: proc(
	start: ^Expression,
	allocator := context.allocator,
	loc := #caller_location,
) -> ^Expression {
	// Handle nil case
	if start == nil {
		return nil
	}

	// Create new expression
	cloned := new(Expression, allocator, loc)

	// Deep copy based on the type
	switch expr in start^ {
	case Symbol:
		cloned^ = Symbol {
			name = strings.clone(expr.name, allocator, loc), // Deep copy the string
		}

	case Number:
		cloned^ = Number {
			value = expr.value,
		}

	case BuiltinFunction:
		cloned^ = BuiltinFunction {
			fn = expr.fn, // function pointer is copied
		}

	case Lambda:
		lambda := Lambda {
			body    = clone(expr.body, allocator, loc),
			formals = clone(expr.formals, allocator, loc),
		}
		env_clone(expr.env, &lambda.env, allocator, loc)
		cloned^ = lambda

	case Cons_Cell:
		// Recursively clone both car and cdr
		cloned^ = Cons_Cell {
			car = clone(expr.car, allocator, loc),
			cdr = clone(expr.cdr, allocator, loc),
		}
	case NIL:
		cloned^ = NIL{} // TODO this should only ever return the pointer to nil in env put there from stdlib
	case T:
		cloned^ = T{} // TODO this should only ever return the pointer to t in env put there from stdlib
	}

	return cloned
}

expression_free :: proc(
	expr: ^Expression,
	allocator := context.allocator,
	loc := #caller_location,
) {
	// Free string and other stuff
	switch &e in expr {
	case Symbol:
		delete(e.name)
		free(expr)
	case BuiltinFunction, Number, NIL, T:
		free(expr)
	case Lambda:
		expression_free(e.body)
		expression_free(e.formals)
		env_destroy(&e.env)
	case Cons_Cell:
		// Recursively free both car and cdr
		expression_free(e.car, allocator, loc)
		expression_free(e.cdr, allocator, loc)
	}

}

// Add more detailed error in next version
Next_Level_Error :: union {
	Read_Error,
	Eval_Error,
	Print_Error,
}

Eval_Error :: enum {
	Bang,
	Paren_Imbalance,
	Zero_Arguments,
	Head_Is_Not_A_Function,
	Apply_Failure,
	Not_A_Cons_Cell,
	Symbol_Not_Found,
}

// (), nil and '() all evaluate to NIL
// cons cdr is not conscell or nil improper list
// car is conscell we have a tree
//
eval :: proc(env: ^Environment, expr: ^Expression) -> (result: ^Expression, err: Eval_Error) {
	switch e in expr^ {
	case Symbol:
		lookup := env_get(env, e.name) or_return
		return lookup, nil

	case Number, BuiltinFunction, NIL, T:
		// TODO should nil and t be put in env and treated as symbol
		return expr, nil

	case Lambda:
		return expr, nil

	case Cons_Cell:
		head := car(e)

		// handle special forms
		if symbol, ok := head^.(Symbol); ok {
			switch symbol.name {
			case "quote":
				args := cdr(e)
				if args, ok := cdr(e).(NIL); ok {
					return nil, .Zero_Arguments
				}
				return args, nil
			case "if":
				return nil, .Bang //eval_if(env, e)
			case "define":
				binding_name := car(cdr(e).(Cons_Cell)).(Symbol).name // get the name
				binding_expr := eval(env, car(cdr(cdr(e).(Cons_Cell)).(Cons_Cell))) or_return
				env_add(env, binding_name, binding_expr)
				return binding_expr, nil
			case "lambda":
				// important part here is that formals do not lookup in env, we just want them to stay as symbols
				lambda := expr_new_lambda(car(cdr(e).(Cons_Cell)), cdr(cdr(e).(Cons_Cell)), env)
				return lambda, nil
			}
		}

		// evaluate the head (function position)
		evaluated_head := eval(env, head) or_return

		// check so head is a function
		if fn, ok := evaluated_head^.(BuiltinFunction); ok {
			return apply(&fn, cdr(e), env)
		}
		if fn, ok := evaluated_head^.(Lambda); ok {
			return apply(&fn, cdr(e), env)
		}
		return nil, .Head_Is_Not_A_Function // Error. head is not a Function
	}
	return nil, .Bang
	// we should never reach here
}

// always return a cons_cell not sure this is correct,
eval_list :: proc(env: ^Environment, expr: ^Expression) -> (result: ^Expression, err: Eval_Error) {

	if cons_val, ok := expr^.(Cons_Cell); ok {
		first := eval(env, car(cons_val)) or_return
		rest := eval_list(env, cdr(cons_val)) or_return
		return cons(first, rest), nil
	}
	// We have reached the end of the list return NIL
	return expr, nil // TODO assume that this only happen when we reaches the end
}

apply :: proc {
	lambda_apply,
	builtin_function_apply,
}

lambda_apply :: proc(
	fn: ^Lambda,
	arg_exprs: ^Expression,
	env: ^Environment,
) -> (
	result: ^Expression,
	err: Eval_Error,
) {
	// If user function lambda evaluate arguments and bind to parameters
	args := eval_list(env, arg_exprs) or_return
	// TODO could use curry here but right now number of args must match number of formals
	lambda_bind_args(&fn.env, fn.formals, args)
	return eval(&fn.env, car(fn.body.(Cons_Cell))) // TODO dunderstand why i always need to make car here, think i have some fundamental error
}

// bind evaluated_args to formals symbols in env for use by body
lambda_bind_args :: proc(env: ^Environment, formals: ^Expression, evaluated_args: ^Expression) {
	next_formal := car(formals.(Cons_Cell)).(Symbol)
	env_add(env, next_formal.name, car(evaluated_args.(Cons_Cell)))
	if _, ok := cdr(formals.(Cons_Cell)).(NIL); !ok {
		// TODO will fail if number of args do not match number of bindings
		lambda_bind_args(env, cdr(formals.(Cons_Cell)), cdr(evaluated_args.(Cons_Cell)))
	}
}

builtin_function_apply :: proc(
	fn: ^BuiltinFunction,
	arg_exprs: ^Expression,
	env: ^Environment,
) -> (
	result: ^Expression,
	err: Eval_Error,
) {
	// If built-in evaluate all arguments expressions first
	args := eval_list(env, arg_exprs) or_return
	// If user function lambda evaluate arguments and bind to parameters
	// evaled_args = eval_list(args_exprs, env)
	// bind_parameters(func->params, evaled_args, env)
	return fn.fn(env, args)
}

import "core:testing"
@(test)
test_cons_car_cdr :: proc(t: ^testing.T) {
	defer free_all(context.temp_allocator)
	head := expr_new()
	head^ = Number {
		value = 2,
	}
	tail := expr_new()
	tail^ = NIL{}
	next := cons(head, tail)

	cons_cell := next.(Cons_Cell)

	// Assert union type using type assertion
	if number, ok := car(cons_cell).(Number); ok {
		testing.expect(t, number.value == 2)
	} else {
		testing.fail(t)
	}

	_ = cdr(cons_cell).(NIL)
}

