package main

Board :: distinct [CELL_COUNT]Tile

// returns a pointer to said tile and whether the cell is in bounds.
board_get_tile :: proc(board: ^Board, hex: Hex) -> (tile: ^Tile, valid: bool) {
	idx := hex_to_index(hex) or_return

	return &board[idx], true
}

board_put_tile :: proc(board: ^Board, hex: Hex, tile: Tile) -> (success: bool) {
	// check if valid hex
	idx := hex_to_index(hex) or_return

	// check if location is empty
	tile_is_empty(board[idx]) or_return

	/*
	
	here you would check for legal moves
	
	1. check if surrounding cells can connect
	 	a. if neighbor cell is empty: YES
		b. if neighbor cell is full, and has a connection at that direction: YES
		c. if neighbor cell is full, but NO connection at that direction: NO
		d. if neighbor cell is out of bounds: NO
	
	2. check if it causes oscillation: (fuzzy logic)
		a. for each surrounding group , check how many liberties it has
		b. for each surrounding group , check how many connections we connect to it
		c. compare the two numbers. diverge logic based on different colors.
	*/

	board[idx] = tile

	//
	// here you'd update groups
	// 
	// need a group struct somewhere with a .. dynamic array and a liberty count.
	// Are groups better as bit sets or maps ?
	//

	return true
}
