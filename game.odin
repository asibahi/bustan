package bustan

import "core:slice"

Player :: enum u8 {
	Guest, // White
	Host, // Black
}

Move :: struct {
	hex:  Hex,
	tile: Tile,
}

Status :: enum u8 {
	Ongoing,
	Guest_Win,
	Host_Win,
	Tie,
}

Game :: struct {
	board:                 Board,
	to_play:               Player,
	status:                Status,
	last_move:             Maybe(Move),
	//
	guest_hand, host_hand: Hand,
	//
	groups_map:            [CELL_COUNT]Sm_Key,
	guest_grps, host_grps: Slot_Map,
	// 
	legal_moves:           [dynamic]Move,
}

game_init :: proc() -> (ret: Game) {
	// All other fields start with zero values except these two.
	ret.guest_hand, ret.host_hand = hands_init()
	ret.guest_grps = slotmap_init()
	ret.host_grps = slotmap_init()
	return
}

game_destroy :: proc(game: Game) {
	// free all the remaining groups
	for key in game.groups_map {
		if slotmap_contains_key(game.guest_grps, key) {
			grp := slotmap_get(game.guest_grps, key)
			free(grp)
		} else if slotmap_contains_key(game.host_grps, key) {
			grp := slotmap_get(game.host_grps, key)
			free(grp)
		}
	}

	// free the slotmaps
	slotmap_destroy(game.guest_grps)
	slotmap_destroy(game.host_grps)

	// delete the dynamic map
	delete(game.legal_moves)

	// Is this enough?
	return
}

game_make_move :: proc(game: ^Game, candidate: Maybe(Move)) -> bool {
	(game.status == .Ongoing) or_return // Game is over. What are you doing?
	move, not_pass := candidate.?

	// legal move check
	// A pass is always legal.
	// any move on an empty board is legal
	// otherwise, game.legal_moves must contain the move
	(!not_pass ||
		slice.contains(game.legal_moves[:], move) ||
		board_is_empty(&game.board)) or_return

	defer if game.status == .Ongoing {
		switch game.to_play {
		case .Guest:
			game.to_play = .Host
		case .Host:
			game.to_play = .Guest
		}
		game.last_move = move
		game_regen_legal_moves(game)
	}

	if !not_pass { 	// Pass
		// Bug here: game immediately ends if the first move is a pass.
		if game.last_move == nil { 	// Game ends
			guest, host := game_get_score(game)

			if guest > host do game.status = .Guest_Win
			else if guest < host do game.status = .Host_Win
			else do game.status = .Tie
		}
		return true
	}

	active_hand: ^Hand

	switch game.to_play {
	case .Guest:
		active_hand = &game.guest_hand
	case .Host:
		active_hand = &game.host_hand
	}

	// Make move. Already known to be legal!!
	hand_tile, removed := hand_remove_tile(active_hand, move.tile)
	assert(removed) // but verify
	game.board[hex_to_index(move.hex)] = hand_tile
	move.tile = hand_tile // might be superfluous, but just to ascertain the Owner flags are set correctly

	game_update_state_inner(move, game)

	return true
}

@(private)
game_regen_legal_moves :: proc(game: ^Game) {
	clear(&game.legal_moves)

	// todo: build them again
}

// A player's territory consists of the number of their pieces on the board minus the number of pieces they didn't place.
game_get_score :: proc(game: ^Game) -> (guest, host: int) {
	// maybe better as struct fields updated as moves are made?
	for tile in game.board {
		if tile_is_empty(tile) do continue
		if .Controller_Is_Host in tile {
			host += 1
		} else {
			guest += 1
		}
	}
	for i in 0 ..< HAND_SIZE {
		if !tile_is_empty(game.guest_hand[i]) do guest -= 1
		if !tile_is_empty(game.host_hand[i]) do host -= 1
	}

	return
}

// Should only be called if the move is known to be legal.
@(private)
game_update_state_inner :: proc(move: Move, game: ^Game) {
	// Bug tracker
	tile_liberties := card(move.tile & CONNECTION_FLAGS)
	tile_liberties_countdown := tile_liberties

	// Friendliness tracker
	tile_control := move.tile & {.Controller_Is_Host}

	// Scratchpad: Found friendly Groups
	nbr_friend_grps: [6]Sm_Key
	nfg_counter: uint

	// Scratchpad: Found Enemy Groups
	nbr_enemy_tiles: [6]Hex
	net_counter: uint

	// Scratchpad: New Liberties
	new_libs: [6]Hex
	libs_counter: uint

	for flag in move.tile & CONNECTION_FLAGS {
		neighbor := move.hex + flag_dir(flag)
		nbr_tile := board_get_tile(&game.board, neighbor) or_continue

		if tile_is_empty(nbr_tile^) {
			new_libs[libs_counter] = neighbor
			libs_counter += 1
		} else if nbr_tile^ & {.Controller_Is_Host} == tile_control {
			// Same Controller
			tile_liberties_countdown -= 1

			// record Group of neighbor tile.
			key := game.groups_map[hex_to_index(neighbor)]
			if !slice.contains(nbr_friend_grps[:], key) {
				nbr_friend_grps[nfg_counter] = key
				nfg_counter += 1
			}
		} else {
			// Different Controller
			tile_liberties_countdown -= 1

			nbr_enemy_tiles[net_counter] = neighbor
			net_counter += 1
		}
	}

	assert(tile_liberties_countdown >= 0, "if this is broken there is a legality bug")

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

	// The placed Tile's Group
	blessed_key: Sm_Key
	blessed_grp: Sm_Item
	if nfg_counter == 0 {
		blessed_grp = new(Group)
		blessed_key = slotmap_insert(friendly_grps, blessed_grp)

		if net_counter == 0 {
			blessed_grp.extendable = true
		}
	} else {
		blessed_key = nbr_friend_grps[0]
		assert(
			slotmap_contains_key(friendly_grps, blessed_key),
			"Friendly slotmap does not have friendly Key",
		)
		blessed_grp = slotmap_get(friendly_grps, blessed_key)

		// == Merge other groups with blessed group
		for i in 1 ..< nfg_counter {
			assert(
				slotmap_contains_key(friendly_grps, nbr_friend_grps[i]),
				"Friendly slotmap does not have friendly Key",
			)
			temp_grp := slotmap_remove(friendly_grps, nbr_friend_grps[i])
			defer free(temp_grp)

			blessed_grp.state |= temp_grp.state
			blessed_grp.extendable &= temp_grp.extendable
		}
	}
	blessed_grp.state[hex_to_index(move.hex)] |= .Member_Tile

	defer {
		// == Update the groupmap
		for _, idx in blessed_grp.state {
			game.groups_map[idx] = blessed_key
		}
	}

	// == Update liberties
	for i in 0 ..< libs_counter {
		blessed_grp.state[hex_to_index(new_libs[i])] |= .Liberty
	}
	// == Update Enemy neighbors for blessed group
	for i in 0 ..< net_counter {
		blessed_grp.state[hex_to_index(nbr_enemy_tiles[i])] |= .Enemy_Connection
	}

	// == register surrounding Enemy Groups of blessed Group
	surrounding_enemy_grps := make([dynamic]Sm_Key)
	defer delete(surrounding_enemy_grps)

	for slot, idx in blessed_grp.state {
		(slot == .Enemy_Connection) or_continue
		key := game.groups_map[idx]
		if !slice.contains(surrounding_enemy_grps[:], key) {
			append(&surrounding_enemy_grps, key)
		}
	}

	// == if there are no surrounding enemy groups there is nothing more to do
	if len(surrounding_enemy_grps) == 0 {
		assert(
			group_life(blessed_grp) > 0,
			"newly formed groups must have liberites or enemy connections",
		)
		blessed_grp.extendable = true
		return
	}

	// == these are the friendly groups that surround the dead enemy groups.
	level_2_surrounding_friendlies := make([dynamic]Sm_Key)
	defer delete(level_2_surrounding_friendlies)

	// == go over surrounding enemy groups to see if they're dead.
	capture_occurance := false
	for key in surrounding_enemy_grps {
		assert(slotmap_contains_key(enemy_grps, key), "Enemy slotmap does not have enemy Key")
		temp_grp := slotmap_get(enemy_grps, key)
		temp_grp.state[hex_to_index(move.hex)] |= .Enemy_Connection // this is probably correct

		// Enemy Group is dead
		(group_life(temp_grp) == 0) or_continue
		capture_occurance = true

		cursed_grp := slotmap_remove(enemy_grps, key)
		defer free(cursed_grp)

		for slot, idx in cursed_grp.state {
			#partial switch slot {
			case .Member_Tile:
				tile_flip(&game.board[idx])
			case .Enemy_Connection:
				key := game.groups_map[idx]
				if !slice.contains(level_2_surrounding_friendlies[:], key) {
					append(&level_2_surrounding_friendlies, key)
				}
			}
		}

		// CAPTURE
		blessed_grp.state |= cursed_grp.state
		blessed_grp.extendable &= cursed_grp.extendable
	}

	// == merge level 2 surrounding friendlies into blessed group
	for key in level_2_surrounding_friendlies {
		assert(slotmap_contains_key(friendly_grps, key))
		temp_grp := slotmap_remove(friendly_grps, key)
		defer free(temp_grp)

		blessed_grp.state |= temp_grp.state
		blessed_grp.extendable &= temp_grp.extendable
	}

	// == if there is a capture, it is done.
	if capture_occurance do return

	// == if blessed group's liberties larger than 0, it is done capturing
	if group_life(blessed_grp) > 0 do return

	// == Now the blessed group has converted.

	cursed_grp := slotmap_remove(friendly_grps, blessed_key)
	defer free(cursed_grp)

	new_family := make([dynamic]Sm_Key)
	defer delete(new_family)

	for loc, idx in blessed_grp.state {
		#partial switch loc {
		case .Member_Tile:
			tile_flip(&game.board[idx])
		case .Enemy_Connection:
			key := game.groups_map[idx]
			if !slice.contains(new_family[:], key) {
				append(&new_family, key)
			}
		}
	}

	assert(len(new_family) > 0, "Oscillation")

	blessed_key = new_family[0]
	assert(slotmap_contains_key(enemy_grps, blessed_key), "Enemy key is not in enemy map")

	blessed_grp = slotmap_get(enemy_grps, blessed_key)
	blessed_grp.state |= cursed_grp.state

	for i in 1 ..< len(new_family) {
		assert(slotmap_contains_key(enemy_grps, new_family[i]))
		temp_grp := slotmap_remove(enemy_grps, new_family[i])
		defer free(temp_grp)

		blessed_grp.state |= temp_grp.state
	}

	// check if new blessed group is extendable
	extendable := true
	for loc in blessed_grp.state {
		if loc == .Enemy_Connection {
			extendable = false
			break
		}
	}
	blessed_grp.extendable = extendable

	return
}
