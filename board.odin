package main

Board :: distinct [CELL_COUNT]Tile

// returns a pointer to said tile and whether the cell is in bounds.
board_get_tile :: proc(board: ^Board, hex: Hex) -> (tile: ^Tile, valid: bool) {
	idx := hex_to_index(hex) or_return

	return &board[idx], true
}

board_is_empty :: proc(board: ^Board) -> bool {
	for t in board {
		if !tile_is_empty(t) do return false
	}
	return true
}
