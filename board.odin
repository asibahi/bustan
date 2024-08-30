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
import "core:strings"

board_print :: proc(board: Board, grp_map: [CELL_COUNT]Group_Handle) {
	w_on_b :: ansi.CSI + ansi.BG_BLACK + ";" + ansi.FG_WHITE + ansi.SGR
	b_on_w :: ansi.CSI + ansi.BG_WHITE + ";" + ansi.FG_BLACK + ansi.SGR
	end :: ansi.CSI + ansi.RESET + ansi.SGR

	tiles_buffer := strings.builder_make()
	defer strings.builder_destroy(&tiles_buffer)

	grps_buffer := strings.builder_make()
	defer strings.builder_destroy(&grps_buffer)
	
	row := min(i8)
	for tile, idx in board {
		hex := hex_from_index(idx)
		if hex.y > row {
			row = hex.y
			if row != -N {
				strings.write_string(&tiles_buffer, "|")
				strings.write_string(&grps_buffer, "|")

				fmt.println(strings.to_string(tiles_buffer))
				fmt.println(strings.to_string(grps_buffer))

				strings.builder_reset(&tiles_buffer)
				strings.builder_reset(&grps_buffer)
			}
			for i in 0 ..< abs(row) {
				strings.write_string(&tiles_buffer, "  ")
				strings.write_string(&grps_buffer, "  ")
			}
		}
		if tile_is_empty(tile) {
			strings.write_string(&tiles_buffer, "|   ")
			strings.write_string(&grps_buffer, "|   ")
		} else if .Controller_Is_Host in tile {
			strings.write_string(
				&tiles_buffer, 
				fmt.aprintf("|" + w_on_b + "%3o" + end, tile & ~{.Controller_Is_Host})
			)
			strings.write_string(
				&grps_buffer,
				fmt.aprintf("|" + w_on_b + "%3X" + end, transmute(u8)grp_map[idx])
			)
			
		} else {
			strings.write_string(
				&tiles_buffer, 
				fmt.aprintf("|" + b_on_w + "%3o" + end, tile)
			)
			strings.write_string(
				&grps_buffer,
				fmt.aprintf("|" + b_on_w + "%3X" + end, transmute(u8)grp_map[idx])
			)
		}
	}
}
