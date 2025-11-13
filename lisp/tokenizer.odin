package lisp

import "core:unicode"
// tokenizer check balancing of s-expressions

import sa "core:container/small_array"
import "core:fmt"
import "core:log"
import "core:testing"
import "core:unicode/utf8"

Token :: struct {
	kind:  Token_Kind,
	lexme: string,
}

// lisp only have atoms? so this would only be atom and sexpr?
Token_Kind :: enum u32 {
	Invalid,
	EOF,
	Open_Paren,
	Close_Paren,
	Symbol,
	Number,
}

// Even ngs in Odin is utf-8 arecUTFd iI will only assume my languageage is make updof
// ASCII symbols, this simplify since I just assume all ch takes one byte.
Tokenizer :: struct {
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

init_tokenizer :: proc(t: ^Tokenizer, src: string) {
	t.src = src
	t.ch = ' ' // we dont want the null
	advance_rune(t) // init with the first value in src
}

error :: proc(t: ^Tokenizer) {
	t.error_count += 1
}

advance_rune :: proc(t: ^Tokenizer) {
	if t.read_offset < len(t.src) { 	// if we are not at the end
		t.offset = t.read_offset
		if t.ch == '\n' {
			t.line_offset = t.offset
			t.line_count += 1
		}
		r, w := rune(t.src[t.read_offset]), 1
		switch {
		case r == 0:
			error(t)
		case r >= utf8.RUNE_SELF:
			r, w = utf8.decode_last_rune_in_string(t.src[t.read_offset:]) // get the width of the current rune
			if r == utf8.RUNE_ERROR && w == 1 {
				log.error("illegal UTF-8 encoding")
				error(t)
			} else if r == utf8.RUNE_BOM && t.offset > 0 {
				log.error("illegal byte order mark")
				error(t)
			}
		}
		t.read_offset += w // advance the current position with the witdh of a rune
		t.ch = r
	} else { 	// there is no more to parse we are at the end
		t.offset = len(t.src)
		if t.ch == '\n' {
			t.line_offset = t.offset
			t.line_count += 1
		}
		t.ch = -1 // set special char signaling end of processing
	}
}

skip_whitespace :: proc(t: ^Tokenizer) {
	for {
		switch t.ch {
		case ' ', '\t', '\r', '\n':
			advance_rune(t)
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

scan_number :: proc(t: ^Tokenizer) -> (Token_Kind, string) {
	offset := t.offset // offset is where we are before starting scan
	kind := Token_Kind.Number
	for is_digit(t.ch) {
		advance_rune(t)
	}
	return kind, string(t.src[offset:t.offset])
}

scan_symbol :: proc(t: ^Tokenizer) -> (Token_Kind, string) {
	offset := t.offset
	kind := Token_Kind.Symbol

	for is_symbol_start(t.ch) || is_digit(t.ch) {
		advance_rune(t)
	}
	return kind, string(t.src[offset:t.offset])
}

scan :: proc(t: ^Tokenizer) -> Token {
	skip_whitespace(t)

	offset := t.offset // set current to where last scan ended, t.offset represent end

	kind: Token_Kind
	lexme: string

	switch ch := t.ch; true {
	case is_digit(ch):
		kind, lexme = scan_number(t)
	case is_symbol_start(ch):
		kind, lexme = scan_symbol(t)
	case:
		advance_rune(t) // step forward for next iteration and increase t.offset
		switch ch {
		case -1:
			// special end value we set in advance_rune
			kind = .EOF
		case '(':
			kind = .Open_Paren
			t.paren_depth += 1
		case ')':
			kind = .Close_Paren
			t.paren_depth -= 1
			if t.paren_depth < 0 {
				// To many closing parentesis
				error(t)
			}
		case:
			if ch != utf8.RUNE_BOM {
				error(t)
			}
			kind = .Invalid
			lexme = string(t.src[offset:t.offset])
		}
	}
	if kind == .EOF && t.paren_depth > 0 { 	// check when parsing done
		// missing closing paren, to many opening parentesis
		error(t)
	}
	return Token{kind, lexme}
}

@(test)
test_tokenize_balanced :: proc(t: ^testing.T) {
	tokenizer: Tokenizer
	init_tokenizer(&tokenizer, "(+ 2 (- 5 4))")
	tokens: sa.Small_Array(30, Token)
	token: Token
	for token.kind != .EOF {
		token = scan(&tokenizer)
		sa.append(&tokens, token)
	}
	testing.expect(t, tokenizer.error_count == 0)
}

@(test)
test_tokenize_inbalanced_close :: proc(t: ^testing.T) {
	tokenizer: Tokenizer
	init_tokenizer(&tokenizer, "(+ 2 (- 5 4)")
	tokens: sa.Small_Array(30, Token)
	token: Token
	for token.kind != .EOF {
		token = scan(&tokenizer)
		sa.append(&tokens, token)
	}
	testing.expect(t, tokenizer.error_count == 1)
}

@(test)
test_tokenize_inbalanced_open :: proc(t: ^testing.T) {
	tokenizer: Tokenizer
	init_tokenizer(&tokenizer, "(+ 2 - 5 4))")
	tokens: sa.Small_Array(30, Token)
	token: Token
	for token.kind != .EOF {
		token = scan(&tokenizer)
		sa.append(&tokens, token)
	}
	testing.expect(t, tokenizer.error_count == 1)
}


@(test)
test_can_scan_single_number :: proc(t: ^testing.T) {
	tokenizer: Tokenizer
	init_tokenizer(&tokenizer, "2")
	token: Token = scan(&tokenizer)
	testing.expect(t, token.kind == .Number)
	testing.expect(t, token.lexme == "2")
	testing.expect(t, tokenizer.error_count == 0)
}

@(test)
test_can_scan_multiple_numbers :: proc(t: ^testing.T) {
	tokenizer: Tokenizer
	init_tokenizer(&tokenizer, "212980")
	token: Token = scan(&tokenizer)
	testing.expect(t, token.kind == .Number)
	testing.expect(t, token.lexme == "212980")
	testing.expect(t, tokenizer.error_count == 0)
}

@(test)
test_can_scan_open_paren :: proc(t: ^testing.T) {
	tokenizer: Tokenizer
	init_tokenizer(&tokenizer, "(")
	token: Token = scan(&tokenizer)
	testing.expect(t, token.kind == .Open_Paren)
	testing.expect(t, token.lexme == "")
	testing.expect(t, tokenizer.error_count == 0) // will produce error only at EOF
}

@(test)
test_can_scan_closing_paren :: proc(t: ^testing.T) {
	tokenizer: Tokenizer
	init_tokenizer(&tokenizer, ")")
	token: Token = scan(&tokenizer)
	testing.expect(t, token.kind == .Close_Paren)
	testing.expect(t, token.lexme == "")
	testing.expect(t, tokenizer.error_count == 1)
}

@(test)
test_can_scan_symbol :: proc(t: ^testing.T) {
	tokenizer: Tokenizer
	init_tokenizer(&tokenizer, "kk_dl-ls+222")
	token: Token = scan(&tokenizer)
	testing.expect(t, token.kind == .Symbol)
	testing.expect(t, token.lexme == "kk_dl-ls+222")
	testing.expect(t, tokenizer.error_count == 0)
}

@(test)
test_report_error :: proc(t: ^testing.T) {
	tokenizer: Tokenizer
	init_tokenizer(&tokenizer, "[")
	token: Token = scan(&tokenizer)
	testing.expect(t, token.kind == .Invalid)
	testing.expect(t, token.lexme == "[")
	testing.expect(t, tokenizer.error_count == 1)
}

