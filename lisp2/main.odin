package lisp2

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"

main :: proc() {
	when ODIN_DEBUG { 	// need to run with -debug
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				for _, entry in track.allocation_map {
					fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	repl := new(Repl)
	repl_init(repl)
	defer repl_destroy(repl)

	fmt.println("\nLispy Version 0.0.0.0.1")
	fmt.println("Press Ctrl+c to Exit")
	buffer: [1024]byte
	for {
		fmt.print("lispy> ")
		n, err := os.read(os.stdin, buffer[:])
		if err != nil {
			break
		}
		input: string = string(buffer[:n])
		repl_step(repl, input)
		expr_print(repl.last)
		fmt.print("\n")

		buffer = {} // make sure to clear the buffer not sure this is even needed
	}
}

