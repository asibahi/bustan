package main

// to track groups, we need bitboards. (or do we?)
// to make bitboards for our board size, we need 217 bits
// the largest bit_set in Odin is "currently 128"
// so we need to make our own bitboard 

Bitboard :: distinct [7]bit_set[0 ..< 32;u32] // 7 * 32 = 224
HexMap :: distinct map[Hex]struct {}

@(private = "file")
bit_to_col_row :: proc(bit: int) -> (col, row: int) {
	assert(0 <= bit && bit < CELL_COUNT)
	col = bit % 32
	row = bit / 32
	return
}

bb_flip_bit :: proc(bb: ^Bitboard, bit: int) {
	col, row := bit_to_col_row(bit)
	bb^[row] ~= {col}
}

bb_set_bit :: proc(bb: ^Bitboard, bit: int) {
	col, row := bit_to_col_row(bit)
	bb^[row] |= {col}
}

bb_get_bit :: proc(bb: Bitboard, bit: int) -> bool {
	col, row := bit_to_col_row(bit)
	return col in bb[row]
}

bb_to_hexes :: proc(bb: Bitboard) -> (ret: HexMap) {
	#unroll for i in 0 ..< CELL_COUNT {
		if bb_get_bit(bb, i) do ret[hex_from_index(i)] = {}
	}
	return
}

bb_from_hexes :: proc(hexes: HexMap) -> (ret: Bitboard) {
	for hex in hexes do bb_set_bit(&ret, hex_to_index(hex))
	delete(hexes) // is this correct?

	return
}
