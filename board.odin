package bustan

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

import "core:encoding/ansi"
import "core:fmt"

board_print :: proc(board: Board) {
	w_on_b :: ansi.CSI + ansi.BG_BLACK + ";" + ansi.FG_WHITE + ansi.SGR
	b_on_w :: ansi.CSI + ansi.BG_WHITE + ";" + ansi.FG_BLACK + ansi.SGR
	end :: ansi.CSI + ansi.RESET + ansi.SGR
	
	row := min(i8)
	for tile, idx in board {
		hex := hex_from_index(idx)
		if hex.y > row {
			row = hex.y
			if row != -N do fmt.println("|")
			for i in 0 ..< abs(row) {
				fmt.print("  ")
			}
		}
		if tile_is_empty(tile) {
			fmt.print("|   ")
		} else if .Controller_Is_Host in tile {
			fmt.printf("|" + w_on_b + "%3o" + end, tile & ~{.Controller_Is_Host})
		} else {
			fmt.printf("|" + b_on_w + "%3o" + end, tile)
		}
	}
	fmt.println("|")
}
