package bustan

// Base Cell type
Hex :: distinct [2]i8

BOARD_SIZE: i8 : 9

// 9-side board means 8-length diameter
N :: BOARD_SIZE - 1

// Center is (0, 0). If we switch to a rectangular erray it would be (N, N)
CENTER :: Hex{0, 0}

// Formula ripped off Red Blob article.
CELL_COUNT :: 1 + 3 * int(N) * (int(N) + 1)

hex_distance :: proc(h1, h2: Hex) -> i8 {
	vec := h1 - h2
	return max(abs(vec.x), abs(vec.x + vec.y), abs(vec.y))
}

hex_to_index :: proc(hex: Hex) -> (idx: int, ok: bool) #optional_ok {
	if hex_distance(hex, CENTER) > N do return 0, false

	hex  := hex + {N, N} // offset for 0, 0 center
	q, r := hex.x, hex.y

	switch r { 	// Hardcoded values for N == 8
	case  0:	
	case  1: idx =   9
	case  2: idx =  19
	case  3: idx =  30
	case  4: idx =  42
	case  5: idx =  55
	case  6: idx =  69
	case  7: idx =  84
	case  8: idx = 100
	case  9: idx = 117
	case 10: idx = 133
	case 11: idx = 148
	case 12: idx = 162
	case 13: idx = 175
	case 14: idx = 187
	case 15: idx = 198
	case 16: idx = 208
	}

	idx += int(q - max(0, N - r))
	return idx, true
}

hex_from_index :: proc(idx: int) -> (ret: Hex, ok: bool) #optional_ok {
	if idx < 0 || idx >= CELL_COUNT do return {}, false

	r:     i8
	r_len: int

	switch idx { 	// Hardcoded values for N == 8	
	case   0 ..<   9:
	case   9 ..<  19: r =  1; r_len =   9
	case  19 ..<  30: r =  2; r_len =  19
	case  30 ..<  42: r =  3; r_len =  30
	case  42 ..<  55: r =  4; r_len =  42
	case  55 ..<  69: r =  5; r_len =  55
	case  69 ..<  84: r =  6; r_len =  69
	case  84 ..< 100: r =  7; r_len =  84
	case 100 ..< 117: r =  8; r_len = 100
	case 117 ..< 133: r =  9; r_len = 117
	case 133 ..< 148: r = 10; r_len = 133
	case 148 ..< 162: r = 11; r_len = 148
	case 162 ..< 175: r = 12; r_len = 162
	case 175 ..< 187: r = 13; r_len = 175
	case 187 ..< 198: r = 14; r_len = 187
	case 198 ..< 208: r = 15; r_len = 198
	case:		  r = 16; r_len = 208
	}

	// q_offset = q - max(0, N-r)
	// q = q_offset + max(0, N-r)
	// q = idx - r_len + max(0, N-r)
	//
	// this *should* be correct

	q  := i8(idx - r_len + int(max(0, N - r)))
	ret = {q, r} - {N, N} // offset for {0, 0} center

	return ret, true
}

// tests 

import "core:fmt"
import "core:testing"

@(test)
test_hex_to_index_and_back :: proc(t: ^testing.T) {
	input, out: Hex
	idx: int

	input = CENTER
	idx, _ = hex_to_index(input)
	out, _ = hex_from_index(idx)

	testing.expect(t, out == input)

	// ===
	input  = CENTER + BTM_LEFT
	idx, _ = hex_to_index(input)
	out, _ = hex_from_index(idx)

	testing.expect(t, out == input)

	// ===

	input  = {0, N}
	idx, _ = hex_to_index(input)
	out, _ = hex_from_index(idx)

	testing.expect(t, out == input)

}

@(test)
test_hex_from_idx_failure :: proc(t: ^testing.T) {
	idx: int
	ok: bool

	idx = CELL_COUNT
	_, ok = hex_from_index(idx)

	testing.expect(t, !ok)

}
