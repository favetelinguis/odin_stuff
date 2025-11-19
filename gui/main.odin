package gui

import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:os/os2"

main :: proc() {
	game_api_version := 0
	game_api, game_api_ok := load_game_api(game_api_version)

	if !game_api_ok {
		fmt.println("Failed to load Game API")
		return
	}
	game_api_version += 1

	game_api.init()

	for game_api.update() {
		reload: bool
		game_dll_mod, game_dll_mod_err := os.last_write_time_by_name("game.so")
		if game_dll_mod_err == os.ERROR_NONE && game_api.mod_time != game_dll_mod {
			reload = true
		}

		if reload {
			new_game_api, new_game_api_ok := load_game_api(game_api_version)
			if new_game_api_ok {
				// Pointer to memory used by OLD game DLL
				game_memory := game_api.memory()
				// Uload old game DLL obs memory will survive, only deallocated when explicitly freed
				unload_game_api(game_api)

				game_api = new_game_api

				// Point the new game to use the old games memory
				game_api.hot_reloaded(game_memory)
				game_api_version += 1
			}
		}
	}
	// explicit deallocation
	game_api.shutdown()
	unload_game_api(game_api)
}

GameAPI :: struct {
	init:         proc(),
	update:       proc() -> bool,
	shutdown:     proc(),
	memory:       proc() -> rawptr,
	hot_reloaded: proc(_: rawptr),
	lib:          dynlib.Library,
	mod_time:     os.File_Time,
	api_version:  int,
}

load_game_api :: proc(api_version: int) -> (api: GameAPI, ok: bool) {
	mod_time, mod_time_err := os.last_write_time_by_name("game.so")
	if mod_time_err != os.ERROR_NONE {
		fmt.println("Could not fetch last write date of game.so")
		return
	}

	game_dll_name := fmt.tprintf("./game_{0}.so", api_version)
	copy_err := os2.copy_file(game_dll_name, "./game.so")
	if copy_err != nil {
		fmt.printfln("Failed to copy game.so")
		return
	}

	_, ok = dynlib.initialize_symbols(&api, game_dll_name, "game_", "lib")
	if !ok {
		fmt.printfln("Failed initializing symbols: {0}", dynlib.last_error())
	}
	api.api_version = api_version
	api.mod_time = mod_time
	ok = true

	return
}

unload_game_api :: proc(api: GameAPI) {
	if api.lib != nil {
		if !dynlib.unload_library(api.lib) {
			fmt.printfln("Failed unloading lib: {0}", dynlib.last_error())
		}
	}

	if os.remove(fmt.tprintf("game_{0}.so", api.api_version)) != nil {
		fmt.printfln("Failed removing game-xxx.so")
	}
}

