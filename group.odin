package main

import "core:slice"

Hex_State :: enum u8 {
	Empty            = 0x00, // numbers chosen for a reason
	Liberty          = 0x01,
	Member_Tile      = 0x11,
	Enemy_Connection = 0x21,
}

Group :: struct {
	state:      [CELL_COUNT]Hex_State,
	extendable: bool,
}

// When a Tile starts its own Section. 
// Should only be called if the move is known to be legal.
@(private)
group_section_init :: proc(move: Move, game: ^Game) -> (ret: Group, ok: bool = true) {
	// Check that all Connected sides connect to empty tiles.
	// AND find Liberties
	for flag in move.tile & CONNECTION_FLAGS {
		neighbor := move.hex + flag_dir(flag)
		nbr_tile := board_get_tile(&game.board, neighbor) or_continue

		tile_is_empty(nbr_tile^) or_return
		ret.state[hex_to_index(neighbor)] = .Liberty
	}
	ret.state[hex_to_index(move.hex)] = .Member_Tile
	ret.extendable = true

	return
}

// When a Tile extends a Group or merges two Groups (NO SUICIDE)
// Should only be called if the move is known to be legal.
@(private)
group_extend_or_merge :: proc(move: Move, game: ^Game) -> (ok: bool = true) {
	// Bug tracker
	tile_liberties_count := card(move.tile & CONNECTION_FLAGS)

	// Friendliness tracker
	tile_control := move.tile & {.Controller_Is_Host}

	// Scratchpad: Found Groups
	found_grps_set: [6]Sm_Key
	fgs_cursor: int

	// Scratchpad: New Liberties
	new_libs: [6]Hex
	libs_cursor: int

	for flag in move.tile & CONNECTION_FLAGS {
		neighbor := move.hex + flag_dir(flag)
		nbr_tile := board_get_tile(&game.board, neighbor) or_continue

		if tile_is_empty(nbr_tile^) {
			new_libs[libs_cursor] = neighbor
			libs_cursor += 1
		} else if nbr_tile^ & {.Controller_Is_Host} == tile_control {
			// Same Controller
			tile_liberties_count -= 1

			// record Group of neighbor tile.
			key := game.groups_map[hex_to_index(neighbor)]
			if !slice.contains(found_grps_set[:], key) {
				found_grps_set[fgs_cursor] = key
				fgs_cursor += 1
			}
		} else {
			// Different Controller
			return false
		}

	}
	assert(tile_liberties_count >= 0) // if this is broken we have a legality bug
	assert(fgs_cursor > 0) // This proc should not be called with no friendly neighbors
	(tile_liberties_count > 0) or_return // if this is broken then this might be a Suicide

	// == Are we the Baddies?
	friendly_grps: Slot_Map
	if tile_control == {} {
		friendly_grps = game.guest_grps
	} else {
		friendly_grps = game.host_grps
	}

	// == Identify first group
	assert(slotmap_contains_key(friendly_grps, found_grps_set[0]))
	fst_grp := slotmap_get(friendly_grps, found_grps_set[0])
	fst_grp.state[hex_to_index(move.hex)] = .Member_Tile

	// == Merge other groups with first group
	for i in 1 ..< fgs_cursor {
		assert(slotmap_contains_key(friendly_grps, found_grps_set[i]))
		grp := slotmap_remove(friendly_grps, found_grps_set[i])
		defer free(grp)

		fst_grp.state |= grp.state
		fst_grp.extendable &= grp.extendable
	}

	// == Update liberties
	for l in 0 ..< libs_cursor {
		fst_grp.state[hex_to_index(new_libs[l])] |= .Liberty
	}

	// == Update the groupmap
	for _, idx in fst_grp.state {
		game.groups_map[idx] = found_grps_set[0]
	}

	// this should be all.

	return
}

group_size :: proc(grp: ^Group) -> (ret: int) {
	for t in grp.state {
		if t == .Member_Tile do ret += 1
	}
	return
}

group_life :: proc(grp: ^Group) -> (ret: int) {
	for t in grp.state {
		if t == .Liberty do ret += 1
	}
	return
}
