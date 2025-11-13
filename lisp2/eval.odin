package lisp2

import "core:fmt"
import "core:strings"

// Can evaluate quoted
eval :: proc(env: ^Environment, expr: ^Expression) -> (^Expression, Eval_Error) {
	if is_quoted(expr) {
		// remove car which is quoted special form and evaluate cdr
		return eval_expression(env, cdr(expr.(Cons_Cell)))
	}
	return eval_expression(env, expr)
}

is_quoted :: proc(expr: ^Expression) -> bool {
	if c, ok := expr.(Cons_Cell); ok {
		if s, ok2 := car(c).(Symbol); ok2 {
			return s.name == "quoted"
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

	case Function:
		cloned^ = Function {
			fn = expr.fn, // function pointer is copied
		}

	case Cons_Cell:
		// Recursively clone both car and cdr
		cloned^ = Cons_Cell {
			car = clone(expr.car, allocator, loc),
			cdr = clone(expr.cdr, allocator, loc),
		}
	case NIL:
		cloned^ = NIL{}
	case T:
		cloned^ = T{}
	}

	return cloned
}

expression_free :: proc(
	expr: ^Expression,
	allocator := context.allocator,
	loc := #caller_location,
) {
	// Free string and other stuff
	#partial switch e in expr {
	case Symbol:
		delete(e.name)
	case Cons_Cell:
		// Recursively free both car and cdr
		expression_free(e.car, allocator, loc)
		expression_free(e.cdr, allocator, loc)
	}
	free(expr)
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
eval_expression :: proc(
	env: ^Environment,
	expr: ^Expression,
) -> (
	result: ^Expression,
	err: Eval_Error,
) {
	// handle nil expressions
	if expr == nil {
		return nil, .Bang
	}

	switch e in expr^ {
	case Symbol:
		lookup := env_get(env, e.name) or_return
		return lookup, nil

	case Number, Function, NIL, T:
		// TODO should nil and t be put in env and treated as symbol
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
				return nil, .Bang //eval_define(env, e)
			case "lambda":
				return nil, .Bang //eval_lambda(env, e)
			}
		}

		// evaluate the head (function position)
		evaluated_head := eval_expression(env, head) or_return

		// check so head is a function
		if fn, ok := evaluated_head^.(Function); ok {
			return apply(&fn, cdr(e), env)
		}
		return nil, .Head_Is_Not_A_Function // Error. head is not a Function
	}
	return nil, .Bang
	// we should never reach here
}

eval_list :: proc(env: ^Environment, expr: ^Expression) -> (result: ^Expression, err: Eval_Error) {

	if cons_val, ok := expr^.(Cons_Cell); ok {
		first := eval_expression(env, car(cons_val)) or_return
		rest := eval_list(env, cdr(cons_val)) or_return
		return cons(first, rest), nil
	}
	// We have reached the end of the list return NIL
	return expr, nil // TODO assume that this only happen when we reaches the end
}

apply :: proc(
	fn: ^Function,
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

