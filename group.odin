package main

Group :: struct {
	// Group is organized in terms of Hexes.
	// This may require some bookkeeping
	tiles:     Bitboard,
	liberties: Bitboard,
}

group_init :: proc(tile: Tile, hex: Hex, board: ^Board) -> (ret: Group, ok: bool = true) {
	idx := hex_to_index(hex) or_return
	bb_set_bit(&ret.tiles, idx)

	// liberties 
	// this is currently incorrect: does not look at friendliness of neighbors
	for flag in tile & CONNECTION_FLAGS {
		nbr := hex + flag_dir(flag)

		t, in_bounds := board_get_tile(board, nbr)
		if in_bounds && tile_is_empty(t^) {
			bb_set_bit(&ret.liberties, hex_to_index(nbr))
		}
	}

	return
}

// does not check for whether the capture is illegal (causes oscillation)
group_capture :: proc(winner, loser: ^Group, board: ^Board) {
	bbi := bb_make_iter(loser.tiles)
	for hex in bb_hexes(&bbi) {
		tile, _ := board_get_tile(board, hex)
		tile_flip(tile)
	}

	winner.tiles |= loser.tiles
	winner.liberties = {}

	bbi = bb_make_iter(winner.tiles)
	for hex in bb_hexes(&bbi) {
		tile, _ := board_get_tile(board, hex)
		for flag in tile^ & CONNECTION_FLAGS {
			nbr := hex + flag_dir(flag)

			t, in_bounds := board_get_tile(board, nbr)
			if in_bounds && tile_is_empty(t^) {
				bb_set_bit(&winner.liberties, hex_to_index(nbr))
			}
		}
	}

}

group_size :: proc(grp: ^Group) -> int {
	return bb_card(grp.tiles)
}

group_life :: proc(grp: ^Group) -> int {
	return bb_card(grp.liberties)
}
