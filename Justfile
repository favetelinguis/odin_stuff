test_lisp:
	odin test ./lisp -define:ODIN_TEST_FANCY=false

check_e_lisp:
	odin check ./lisp \
	-default-to-panic-allocator

debug-build:
	odin build ./lisp2 -out=bin/lisp-debug -o:none -debug

debug-test:
	echo "todo"

run-debug:
	odin run ./lisp2 -debug -sanitize:address
