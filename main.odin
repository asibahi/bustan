package main

import "core:fmt"

main :: proc() {
	board: Board = {}
	guest, host := hands_init()

	wt_63: Tile
	ok: bool

	if wt_63, ok = hand_get_tile(&guest, 63); !ok {
		panic("couldnt get tile 63")
	} else {
		fmt.printfln("Got Tile 63 from guest hand")
	}

	if _, ok = hand_get_tile(&guest, 63); ok {
		panic("got duplicate tile")
	}

	if ok = board_put_tile(&board, CENTER, wt_63); ok {
		fmt.printfln("Placed tile 63 in Board in Center")
	}

	if ok = board_put_tile(&board, CENTER, wt_63); ok {
		panic("Tried to place tile twice")
	}

	tile_ptr: ^Tile
	if tile_ptr, ok = board_get_tile(&board, CENTER); ok {
		fmt.printfln("Found Tile %V on Board", tile_ptr^)
		tile_flip(tile_ptr)
		fmt.printfln("Found Tile %V on Board", tile_ptr^)
	}
	if tile_ptr, ok = board_get_tile(&board, CENTER); ok {
		fmt.printfln("Found Tile %V on Board", tile_ptr^)
		tile_flip(tile_ptr)
		fmt.printfln("Found Tile %V on Board", tile_ptr^)
	}

}
