package main

HAND_SIZE :: 63
Hand :: distinct [HAND_SIZE]Tile

hands_init :: proc() -> (guest: Hand, host: Hand) {
	#unroll for i in 0 ..< u8(HAND_SIZE) {
		guest[i] = transmute(Tile)(i + 0b00_000_001)
		host[i] = transmute(Tile)(i + 0b11_000_001)
	}

	return
}

hand_has_tile :: proc(hand: Hand, id: u8) -> bool {
	assert(0 < id, "Blank Tile is not playable")
	assert(id <= HAND_SIZE, "Tile is impossible")

	return !tile_is_empty(hand[id - 1])
}

hand_get_tile :: proc(hand: ^Hand, id: u8) -> (Tile, bool) {
	if !hand_has_tile(hand^, id) do return nil, false

	ret := hand[id - 1]
	hand[id - 1] = {}
	return ret, true
}

// tests 

import "core:testing"

@(test)
test_hand_init :: proc(t: ^testing.T) {
	w, b := hands_init()

	for tile in w {
		testing.expect(t, !tile_is_empty(tile))
	}

	for tile in b {
		testing.expect(t, !tile_is_empty(tile))
	}
}

@(test)
test_hand_get_tile :: proc(t: ^testing.T) {
	w, _ := hands_init()

	tile: Tile
	ok: bool

	// should be successful
	tile, ok = hand_get_tile(&w, 63)
	testing.expect(t, !tile_is_empty(tile))
	testing.expect(t, ok)

	// should fail. tile was emptied
	tile, ok = hand_get_tile(&w, 63)
	testing.expect(t, tile_is_empty(tile))
	testing.expect(t, !ok)
}
