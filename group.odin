package main

Group :: struct {
	// Group is organized in terms of Hexes.
	// This may require some bookkeeping
	tiles:     Bitboard,
	liberties: Bitboard,
}

// Call this when a Tile starts its own Section. 
// Should only be called if the move is known to be legal.
@(private)
group_section_init :: proc(move: Move, game: ^Game) -> (ret: ^Group, ok: bool = true) {
	ret = new(Group) // store it on the heap
	defer if !ok do free(ret)

	// Check that all Connected sides connect to empty tiles.
	// AND find Liberties
	for flag in move.tile & CONNECTION_FLAGS {
		neighbor := move.hex + flag_dir(flag)

		t, in_bounds := board_get_tile(&game.board, neighbor)
		if in_bounds {
			tile_is_empty(t^) or_return
			bb_set_bit(&ret.liberties, hex_to_index(neighbor))
		}
	}

	bb_set_bit(&ret.tiles, hex_to_index(move.hex))

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
