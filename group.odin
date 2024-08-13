package main

import "core:slice"

Hex_State :: enum u8 {
	Empty            = 0x00, // numbers chosen for a reason
	Liberty          = 0x01,
	Enemy_Connection = 0x11,
	Member_Tile      = 0x13,
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
group_attach_to_friendlies :: proc(move: Move, game: ^Game) -> (ok: bool = true) {
	// Bug tracker
	tile_liberties_count := card(move.tile & CONNECTION_FLAGS)

	// Friendliness tracker
	tile_control := move.tile & {.Controller_Is_Host}

	// Scratchpad: Found Groups
	nbr_friend_grps: [6]Sm_Key
	nfg_cursor: int

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
			if !slice.contains(nbr_friend_grps[:], key) {
				nbr_friend_grps[nfg_cursor] = key
				nfg_cursor += 1
			}
		} else {
			// Different Controller
			return false
		}

	}
	assert(tile_liberties_count >= 0) // if this is broken we have a legality bug
	assert(nfg_cursor > 0) // This proc should not be called with no friendly neighbors

	// == Are we the Baddies?
	friendly_grps: Slot_Map
	enemy_grps: Slot_Map
	if tile_control == {} {
		// Guest Controller
		friendly_grps = game.guest_grps
		enemy_grps = game.host_grps
	} else {
		// Host Controller
		friendly_grps = game.host_grps
		enemy_grps = game.guest_grps
	}

	// == Identify first group
	blessed_key := nbr_friend_grps[0]

	assert(slotmap_contains_key(friendly_grps, blessed_key))
	blessed_grp := slotmap_get(friendly_grps, blessed_key)
	blessed_grp.state[hex_to_index(move.hex)] = .Member_Tile

	// == Merge other groups with first group
	for i in 1 ..< nfg_cursor {
		assert(slotmap_contains_key(friendly_grps, nbr_friend_grps[i]))
		grp := slotmap_remove(friendly_grps, nbr_friend_grps[i])
		defer free(grp)

		blessed_grp.state |= grp.state
		blessed_grp.extendable &= grp.extendable
	}

	// == Update liberties
	for l in 0 ..< libs_cursor {
		blessed_grp.state[hex_to_index(new_libs[l])] |= .Liberty
	}

	if tile_liberties_count == 0 && group_life(blessed_grp) == 0 {
		// no insertion into the enemy slotmap .. there is merging to be done!
		cursed_grp := slotmap_remove(friendly_grps, blessed_key)
		defer free(cursed_grp)

		// Scratchpad 
		nbr_enemy_grps := make([dynamic]Sm_Key)
		defer delete(nbr_enemy_grps)

		for loc, idx in cursed_grp.state {
			#partial switch loc {
			case .Member_Tile:
				tile_flip(&game.board[idx])
			case .Enemy_Connection:
				key := game.groups_map[idx]
				if !slice.contains(nbr_enemy_grps[:], key) {
					append(&nbr_enemy_grps, key)
				}
			}
		}
		// == same steps as before
		assert(len(nbr_enemy_grps) > 0) // or there is Oscillation
		blessed_key = nbr_enemy_grps[0]

		assert(slotmap_contains_key(enemy_grps, blessed_key))
		blessed_grp = slotmap_get(enemy_grps, blessed_key)

		blessed_grp.state |= cursed_grp.state

		for i in 1 ..< len(nbr_enemy_grps) {
			assert(slotmap_contains_key(enemy_grps, nbr_enemy_grps[i]))
			grp := slotmap_remove(enemy_grps, nbr_enemy_grps[i])
			defer free(grp)

			blessed_grp.state |= grp.state
		}

		// check if blessed_grp is extendable
		extendable := true
		for loc in blessed_grp.state {
			if loc == .Enemy_Connection {
				extendable = false
				break
			}
		}
		blessed_grp.extendable = extendable
	}

	// == Update the groupmap
	for _, idx in blessed_grp.state {
		game.groups_map[idx] = blessed_key
	}

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
