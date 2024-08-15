package bustan

// Hex Connection directions
TOP_RIGHT :: Hex{1, -1}
RIGHT :: Hex{1, 0}
BTM_RIGHT :: Hex{0, 1}
BTM_LEFT :: Hex{-1, 1}
LEFT :: Hex{-1, 0}
TOP_LEFT :: Hex{0, -1}

// Bustan Tiles
//
// 0b 0 0 _ 0 0 0 _ 0 0 0
//    | |   | | |   | | | 
//    | |   | | |   | | Top_Right
//    | |   | | |   | Right
//    | |   | | |   Btm_Right
//    | |   | | Btm_Left
//    | |   | Left
//    | |   Top_Left
//    | Owner_Is_Host
//    Controller_Is_Host
// 
// the two players are Guest and Host. Guest starts.

Tile_Flag :: enum u8 {
	Top_Right,
	Right,
	Btm_Right,
	Btm_Left,
	Left,
	Top_Left,
	Owner_Is_Host,
	Controller_Is_Host,
}
Tile :: distinct bit_set[Tile_Flag;u8]

// 00300
HOST_FLAGS :: Tile{.Owner_Is_Host, .Controller_Is_Host}
// 0o077
CONNECTION_FLAGS :: ~HOST_FLAGS

flag_dir :: proc(flag: Tile_Flag) -> (ret: Hex) {
	#partial switch flag {
	case .Top_Right:
		ret = TOP_RIGHT
	case .Right:
		ret = RIGHT
	case .Btm_Right:
		ret = BTM_RIGHT
	case .Btm_Left:
		ret = BTM_LEFT
	case .Left:
		ret = LEFT
	case .Top_Left:
		ret = TOP_LEFT
	}
	return
}

tile_flip :: proc(t: ^Tile) {
	t^ ~= {.Controller_Is_Host}
}

tile_is_empty :: proc(t: Tile) -> bool {
	return t & CONNECTION_FLAGS == {}
}

tile_from_id :: proc(id: u8, player: Player) -> (ret: Tile) {
	assert(0 < id, "Blank Tile is not playable")
	assert(id <= HAND_SIZE, "Tile is impossible")

	ret = transmute(Tile)id
	switch player {
	case .Host:
		ret |= HOST_FLAGS
	case .Guest:
	}

	return
}

// tests 

import "core:testing"

@(test)
test_tile_is_empty :: proc(t: ^testing.T) {
	testing.expect(t, tile_is_empty(HOST_FLAGS))
	testing.expect(t, tile_is_empty({.Controller_Is_Host}))
	testing.expect(t, tile_is_empty({.Owner_Is_Host}))
	testing.expect(t, tile_is_empty({}))

	testing.expect(t, !tile_is_empty({.Top_Left}))
	testing.expect(t, !tile_is_empty(HOST_FLAGS | {.Top_Left}))
	testing.expect(t, !tile_is_empty({.Top_Right, .Btm_Left}))
}
