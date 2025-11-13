package lisp

import "core:container/small_array"
import "core:fmt"
import "core:log"
import "core:strconv"
import "core:testing"
import "core:text/match"
// Assumes balanced parenthesis, this is done in the tokenizer

Parser :: struct {
	tokens:      []Token,
	current:     int,
	error_count: int,
}

init_parser :: proc(p: ^Parser, tokens: []Token) {
	p.tokens = tokens
	p.current = 0
	p.error_count = 0
}

parser_error :: proc(p: ^Parser, msg: string) {
	log.errorf("Parser error at token %d: %s", p.current, msg)
	p.error_count += 1
}

// Check next token without advancing
peek :: proc(p: ^Parser) -> Token {
	if p.current >= len(p.tokens) {
		return Token{kind = .EOF, lexme = ""} // TODO this can be dont with check if i am at EOF now?
	}
	return p.tokens[p.current] // TODO should this not be current + 1
}

advance_token :: proc(p: ^Parser) -> Token {
	if p.current < len(p.tokens) {
		token := p.tokens[p.current]
		p.current += 1
		return token
	}
	return Token{kind = .EOF, lexme = ""}
}

match :: proc(p: ^Parser, kind: Token_Kind) -> bool {
	if peek(p).kind == kind {
		advance_token(p)
		return true
	}
	return false
}

expect :: proc(p: ^Parser, kind: Token_Kind, msg: string) -> bool {
	if peek(p).kind == kind {
		advance_token(p)
		return true
	}
	parser_error(p, msg)
	return false
}

parse_expr :: proc(p: ^Parser, allocator := context.allocator) -> ^Expr {
	token := peek(p)

	#partial switch token.kind { 	// TODO should not need parial
	case .Number:
		return parse_number(p, allocator)
	case .Symbol:
		return parse_symbol(p, allocator)
	case .Open_Paren:
		return parse_list(p, allocator)
	case .EOF:
		return nil
	case:
		parser_error(p, "unexpected token")
		return nil
	}
}

parse_number :: proc(p: ^Parser, allocator := context.allocator) -> ^Expr {
	token := advance_token(p)
	value := strconv.atoi(token.lexme)

	expr := new(Expr, allocator)
	number: Number
	number.value = value
	expr^ = number

	return expr
}

parse_symbol :: proc(p: ^Parser, allocator := context.allocator) -> ^Expr {
	token := advance_token(p)

	expr := new(Expr, allocator)
	symbol: Symbol
	symbol.name = token.lexme
	expr^ = symbol

	return expr
}

parse_list :: proc(p: ^Parser, allocator := context.allocator) -> ^Expr {
	if !expect(p, .Open_Paren, "expected '('") {
		return nil
	}

	expr := new(Expr, allocator)
	list: SExpr
	list.elements = make([dynamic]^Expr, allocator)

	// Parse elements until we hit a closing paren
	for peek(p).kind != .Close_Paren && peek(p).kind != .EOF {
		expr := parse_expr(p, allocator)
		if expr != nil {
			append(&list.elements, expr)
		} else {
			// Error already reported by parse_expr
			break
		}
	}
	if !expect(p, .Close_Paren, "expected ')'") {
		return nil
	}

	expr^ = list
	return expr
}

// Parse a full program (multiple expressions)
parse :: proc(p: ^Parser, allocator := context.allocator) -> [dynamic]^Expr {
	expressions := make([dynamic]^Expr, allocator)

	for peek(p).kind != .EOF {
		expr := parse_expr(p, allocator)
		if expr != nil {
			append(&expressions, expr)
		} else {
			// skip to next expr on error
			advance_token(p)
		}
	}
	return expressions
}

// TODO this should be extended to work with multiple expressions as is now it only support one expression so the list will always just contain one expr
// this is the wrong name it do not parse a sting i do much more
parse_string :: proc(src: string, allocator := context.allocator) -> [dynamic]^Expr {
	// Tokenize
	tokenizer: Tokenizer
	init_tokenizer(&tokenizer, src)
	tokens: small_array.Small_Array(MAX_RUNES / 3, Token)
	token: Token

	for token.kind != .EOF {
		token = scan(&tokenizer)
		small_array.append(&tokens, token)
	}
	if tokenizer.error_count > 0 {
		log.error("There where errors tokenizing: ", tokenizer.error_count)
		return {}
	}

	// Parse
	parser: Parser
	init_parser(&parser, small_array.slice(&tokens))
	expressions := parse(&parser, allocator)
	if parser.error_count > 0 {
		log.errorf("Parser errors: %d", parser.error_count)
	}
	return expressions
}

@(test)
test_parse_simple :: proc(t: ^testing.T) {
	expressions := parse_string("42", context.temp_allocator)
	testing.expect(t, len(expressions) == 1)

	expr := expressions[0]
	number, ok := expr.(Number)
	testing.expect(t, ok)
	testing.expect(t, number.value == 42)
}

@(test)
test_parse_list :: proc(t: ^testing.T) {
	expressions := parse_string("(+ 1 2)", context.temp_allocator)
	testing.expect(t, len(expressions) == 1)

	expr := expressions[0]
	list, ok := expr.(SExpr)
	testing.expect(t, ok)
	testing.expect(t, len(list.elements) == 3)

	// Check operator
	op, ok2 := list.elements[0].(Symbol)
	testing.expect(t, ok2)
	testing.expect(t, op.name == "+")
}

