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

hand_remove_tile :: proc(hand: ^Hand, tile: Tile) -> (ret: Tile, ok: bool = true) {
	(!tile_is_empty(tile)) or_return

	id := transmute(u8)(tile & CONNECTION_FLAGS)
	(!tile_is_empty(hand[id - 1])) or_return

	ret = hand[id - 1]
	hand[id - 1] = {}
	return
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
	_, b := hands_init()

	ok: bool

	// should be successful
	_, ok = hand_remove_tile(&b, CONNECTION_FLAGS | HOST_FLAGS)
	testing.expect(t, ok)

	// should fail. already removed
	_, ok = hand_remove_tile(&b, CONNECTION_FLAGS)
	testing.expect(t, !ok)

	// should fail. Tail requested is empty
	_, ok = hand_remove_tile(&b, {})
	testing.expect(t, !ok)
}
