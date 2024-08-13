package main

// to track groups, we need bitboards. (or do we?)
// to make bitboards for our board size, we need 217 bits
// the largest bit_set in Odin is "currently 128"
// so we need to make our own bitboard 

Bitboard :: distinct [7]bit_set[0 ..< 32;u32] // 7 * 32 = 224
PLAY_AREA: Bitboard : {~{}, ~{}, ~{}, ~{}, ~{}, ~{}, ~{25, 26, 27, 28, 29, 30, 31}}
DATA_AREA: Bitboard : {{}, {}, {}, {}, {}, {}, {25, 26, 27, 28, 29, 30, 31}}

@(private = "file")
bit_to_col_row :: proc(bit: int) -> (col, row: int) {
	col = bit % 32
	row = bit / 32
	return
}

bb_flip_bit :: proc(bb: ^Bitboard, bit: int) {
	assert(0 <= bit && bit < CELL_COUNT)
	col, row := bit_to_col_row(bit)
	bb^[row] ~= {col}
}

bb_flip_bit_unchecked :: proc(bb: ^Bitboard, bit: int) {
	col, row := bit_to_col_row(bit)
	bb^[row] ~= {col}
}

bb_set_bit :: proc(bb: ^Bitboard, bit: int) {
	assert(0 <= bit && bit < CELL_COUNT)
	col, row := bit_to_col_row(bit)
	bb^[row] |= {col}
}

bb_set_bit_unchecked :: proc(bb: ^Bitboard, bit: int) {
	col, row := bit_to_col_row(bit)
	bb^[row] |= {col}
}

bb_unset_bit :: proc(bb: ^Bitboard, bit: int) {
	assert(0 <= bit && bit < CELL_COUNT)
	col, row := bit_to_col_row(bit)
	bb^[row] &~= {col}
}

bb_unset_bit_unchecked :: proc(bb: ^Bitboard, bit: int) {
	col, row := bit_to_col_row(bit)
	bb^[row] &~= {col}
}

bb_get_bit :: proc(bb: Bitboard, bit: int) -> bool {
	col, row := bit_to_col_row(bit)
	return col in bb[row]
}

bb_card :: proc(bb: Bitboard) -> (ret: int) {
	temp := bb & PLAY_AREA // ignore special flags
	#unroll for i in 0 ..< 7 {
		ret += card(temp[i])
	}
	return
}

Bitboard_Iterator :: struct {
	bb:   Bitboard,
	next: int,
}

bb_make_iter :: proc(bb: Bitboard) -> (it: Bitboard_Iterator) {
	it.bb = bb & PLAY_AREA
	return
}

bb_hexes :: proc(it: ^Bitboard_Iterator) -> (item: Hex, idx: int, ok: bool) {
	for i in it.next ..< CELL_COUNT {
		if bb_get_bit(it.bb, i) {
			item = hex_from_index(i)
			it.next = i + 1
			idx += 1
			ok = true
			return
		}
	}

	return
}
