package lisp2

import "core:log"
import "core:strconv"
import "core:strings"
import "core:testing"
import "core:unicode"
import "core:unicode/utf8"

Read_Error :: struct {
	msg:  string,
	kind: Eval_Error, // TODO different enums for different errors
}

Symbol :: struct {
	name: string,
}

Number :: struct {
	value: int,
}

Builtin :: proc(_: ^Environment, _: ^Expression) -> (^Expression, Eval_Error)
BuiltinFunction :: struct {
	fn: Builtin,
}

Lambda :: struct {
	env:     Environment,
	formals: ^Expression,
	body:    ^Expression,
}

Cons_Cell :: struct {
	car: ^Expression,
	cdr: ^Expression,
}

NIL :: struct {}
T :: struct {}

Expression :: union {
	Symbol, // can be a form or a special form like quote
	Number,
	BuiltinFunction,
	Lambda,
	Cons_Cell, // s-expression
	NIL,
	T,
}

expr_new :: proc(allocator := context.temp_allocator, loc := #caller_location) -> ^Expression {
	return new(Expression, allocator, loc)
}

// TODO this can be called make_closure i think the (parameter, body, current env) is for let and lambda etc this is a more general
// pattern then just lambda
expr_new_lambda :: proc(
	formals: ^Expression,
	body: ^Expression,
	parent_env: ^Environment,
	allocator := context.temp_allocator,
	loc := #caller_location,
) -> ^Expression {
	expr := expr_new(allocator, loc)
	lambda := Lambda {
		formals = formals,
		body    = body,
		env     = Environment{}, // this is pattern i want, this makes the lambda the owner of the environment
	}
	env_init(&lambda.env)
	lambda.env.parent = parent_env
	expr^ = lambda
	return expr
}

cons :: proc(
	car: ^Expression,
	cdr: ^Expression,
	allocator := context.temp_allocator,
	loc := #caller_location,
) -> ^Expression {
	expr: ^Expression = new(Expression, allocator, loc)
	expr^ = Cons_Cell {
		car = car,
		cdr = cdr,
	}
	return expr
}

// Can fail for its no a cons cell
car :: proc(consCell: Cons_Cell) -> ^Expression {
	return consCell.car
}

// Can fail for its no a cons cell
cdr :: proc(consCell: Cons_Cell) -> ^Expression {
	return consCell.cdr
}

// return a quoted cons cell
quote :: proc(
	current: ^Expression,
	allocator := context.temp_allocator,
	loc := #caller_location,
) -> ^Expression {
	expr := new(Expression, allocator, loc)
	expr^ = Symbol {
		name = strings.clone("quote", allocator, loc),
	}
	return cons(expr, current)
}

// Even ngs in Odin is utf-8 arecUTFd iI will only assume my languageage is make updof
// ASCII symbols, this simplify since I just assume all ch takes one byte.
Reader_State :: struct {
	src:         string, // are runes but i dont care

	// Tokenizing state
	ch:          rune,
	offset:      int, // start
	read_offset: int, // current
	line_offset: int,
	line_count:  int,
	error_count: int,
	paren_depth: int, // track nesting level
}

init_reader_state :: proc(state: ^Reader_State, src: string) {
	state.src = src
	state.ch = ' ' // we dont want the null
	advance_rune(state) // init with the first value in src
}

error :: proc(t: ^Reader_State) {
	t.error_count += 1
}

advance_rune :: proc(state: ^Reader_State) {
	if state.read_offset < len(state.src) { 	// if we are not at the end
		state.offset = state.read_offset
		if state.ch == '\n' {
			state.line_offset = state.offset
			state.line_count += 1
		}
		r, w := rune(state.src[state.read_offset]), 1
		switch {
		case r == 0:
			error(state)
		case r >= utf8.RUNE_SELF:
			r, w = utf8.decode_last_rune_in_string(state.src[state.read_offset:]) // get the width of the current rune
			if r == utf8.RUNE_ERROR && w == 1 {
				log.error("illegal UTF-8 encoding")
				error(state)
			} else if r == utf8.RUNE_BOM && state.offset > 0 {
				log.error("illegal byte order mark")
				error(state)
			}
		}
		state.read_offset += w // advance the current position with the witdh of a rune
		state.ch = r
	} else { 	// there is no more to parse we are at the end
		state.offset = len(state.src)
		if state.ch == '\n' {
			state.line_offset = state.offset
			state.line_count += 1
		}
		state.ch = -1 // set special char signaling end of processing
	}
}

skip_whitespace :: proc(state: ^Reader_State) {
	for {
		switch state.ch {
		case ' ', '\t', '\r', '\n':
			advance_rune(state)
		case:
			return
		}
	}
}

is_digit :: proc(ch: rune) -> bool {
	return '0' <= ch && ch <= '9'
}

is_symbol_start :: proc(r: rune) -> bool {
	if r < utf8.RUNE_SELF {
		switch r {
		case '_', '-', '+', '*', '/':
			return true
		case 'A' ..= 'Z', 'a' ..= 'z':
			return true
		}
	}
	return unicode.is_letter(r)
}

read_number :: proc(state: ^Reader_State) -> (^Expression, Eval_Error) {
	offset := state.offset // offset is where we are before starting scan
	for is_digit(state.ch) {
		advance_rune(state)
	}
	expr := expr_new()
	value := strconv.atoi(string(state.src[offset:state.offset]))
	expr^ = Number {
		value = value,
	}
	return expr, nil
}

read_symbol :: proc(state: ^Reader_State) -> (^Expression, Eval_Error) {
	offset := state.offset

	for is_symbol_start(state.ch) || is_digit(state.ch) {
		advance_rune(state)
	}
	expr := expr_new()
	expr^ = Symbol {
		name = string(state.src[offset:state.offset]), // TODO will point to data in soururce???
	}
	return expr, nil
}

read :: proc(state: ^Reader_State) -> (expression: ^Expression, err: Eval_Error) {
	skip_whitespace(state)

	// TODO support comments skip to end of line

	// Do reader macro expansion - this can be expanded to do lookup in a table for many different macro expansions and user can register there own
	if state.ch == '\'' {
		advance_rune(state) // consume '
		expr := read(state) or_return
		quote_symbol := expr_new()
		quote_symbol^ = Symbol {
			name = "quote",
		}
		nil_symbol := expr_new()
		nil_symbol^ = NIL{}
		return cons(quote_symbol, cons(expr, nil_symbol)), nil
	}
	if state.ch == '(' {
		state.paren_depth += 1
		return read_list(state) // returns cons cells
	}
	if state.ch == -1 && state.paren_depth != 0 {
		return nil, .Paren_Imbalance
	}
	return read_atom(state) // return atoms
}

read_list :: proc(state: ^Reader_State) -> (expression: ^Expression, err: Eval_Error) {
	advance_rune(state) // consume (
	if state.ch == ')' {
		advance_rune(state) // consume )
		return nil, nil // TODO empty list how to handle?
	}

	// Build cons cell chain: (a b c) = cons(a, cons(b, cons(c, nil)))
	first := read(state) or_return
	rest := read_list_tail(state) or_return // TODO need to count down paren imbalance
	return cons(first, rest), nil
}

read_list_tail :: proc(state: ^Reader_State) -> (expression: ^Expression, err: Eval_Error) {
	skip_whitespace(state)

	// Check for closing paren
	if state.ch == ')' {
		advance_rune(state) // consume )
		state.paren_depth -= 1
		nil_expr := expr_new()
		nil_expr^ = NIL{}
		return nil_expr, nil
	}

	// Check for EOF before closing paren
	// TODO maybe i dont need the state to check imbalance this might be all i need?
	if state.ch == -1 {
		return nil, .Paren_Imbalance
	}

	// Read next element and recursively build the tail
	next_expr := read(state) or_return
	tail := read_list_tail(state) or_return

	return cons(next_expr, tail), nil
}

// reads symbol, number, string
read_atom :: proc(state: ^Reader_State) -> (^Expression, Eval_Error) {
	if is_digit(state.ch) {
		return read_number(state)
	}
	// TODO add string and set in_string state to true in state
	return read_symbol(state)
}

@(test)
test_reader_balanced :: proc(t: ^testing.T) {
	state: Reader_State
	init_reader_state(&state, "(+ 2 (- 5 4))")
	expr, err := read(&state)
	testing.expect(t, state.error_count == 0)
	testing.expect(t, err == nil)
}

@(test)
test_reader_inbalanced_close :: proc(t: ^testing.T) {
	state: Reader_State
	init_reader_state(&state, "(+ 2 (- 5 4)")
	expr, err := read(&state)
	testing.expect(t, err == .Paren_Imbalance)
}

@(test)
test_reader_inbalanced_open :: proc(t: ^testing.T) {
	state: Reader_State
	init_reader_state(&state, "(+ 2 - 5 4))")
	expr, err := read(&state)
	testing.expect(t, err == .Paren_Imbalance)
}


@(test)
test_can_scan_single_number :: proc(t: ^testing.T) {
	state: Reader_State
	init_reader_state(&state, "2")
	expr, err := read(&state)
	number, ok := expr.(Number)
	testing.expect(t, number.value == 2)
	testing.expect(t, state.error_count == 0)
	testing.expect(t, err == nil)
}

@(test)
test_can_scan_multiple_numbers :: proc(t: ^testing.T) {
	state: Reader_State
	init_reader_state(&state, "212980")
	expr, err := read(&state)
	number, ok := expr.(Number)
	testing.expect(t, number.value == 212980)
	testing.expect(t, state.error_count == 0)
	testing.expect(t, err == nil)
}

@(test)
test_can_scan_symbol :: proc(t: ^testing.T) {
	state: Reader_State
	init_reader_state(&state, "kk_dl-ls+222")
	expr, err := read(&state)
	symbol, ok := expr.(Symbol)
	testing.expect(t, symbol.name == "kk_dl-ls+222")
	testing.expect(t, state.error_count == 0)
	testing.expect(t, err == nil)
}

@(test)
test_report_error :: proc(t: ^testing.T) {
	state: Reader_State
	init_reader_state(&state, "[")
	expr, err := read(&state)
	testing.expect(t, err == nil)
	testing.expect(t, state.error_count == 1)
}

