package bustan

import sa "core:container/small_array"
import "core:slice"

Player :: enum u8 {
	Guest, // White
	Host,  // Black
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

	guest_hand, host_hand: Hand,

	groups_map:            [CELL_COUNT]Group_Handle,
	guest_grps, host_grps: Group_Store,

	legal_moves:           [dynamic]Move,
}

game_init :: proc() -> (ret: Game) {
	// All other fields start with zero values except these
	ret.guest_grps.player = .Guest
	ret.host_grps.player  = .Host

	ret.guest_hand, ret.host_hand = hands_init()
	return
}

game_destroy :: proc(game: Game) {
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
		case .Guest: game.to_play = .Host
		case .Host:  game.to_play = .Guest
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
	case .Guest: active_hand = &game.guest_hand
	case .Host:  active_hand = &game.host_hand
	}

	// Make move. Already known to be legal!!
	hand_tile, removed := hand_remove_tile(active_hand, move.tile)
	assert(removed) // but verify
	game.board[hex_to_index(move.hex)] = hand_tile
	move.tile = hand_tile // might be superfluous, but just to ascertain the Owner flags are set correctly

	game_inner_update_state(move, game)

	return true
}

// Should only be called if the move is known to be legal.
@(private)
game_inner_update_state :: proc(move: Move, game: ^Game) {

	// Friendliness tracker
	tile_control := move.tile & {.Controller_Is_Host}
	assert(
		(game.to_play == .Guest && move.tile & HOST_FLAGS == {}) ||
		(game.to_play == .Host  && move.tile & HOST_FLAGS == HOST_FLAGS),
	)

	// Scratchpad: Found friendly Groups
	nbr_friend_grps: sa.Small_Array(6, Group_Handle)

	// Scratchpad: Found Enemy Groups
	nbr_enemy_tiles: sa.Small_Array(6, Hex)

	// Scratchpad: New Liberties
	new_libs: sa.Small_Array(6, Hex)

	// Bug tracker
	tile_liberties := card(move.tile & CONNECTION_FLAGS)
	tile_liberties_countdown := tile_liberties

	for flag in move.tile & CONNECTION_FLAGS {
		neighbor := move.hex + flag_dir(flag)
		nbr_tile := board_get_tile(&game.board, neighbor) or_continue

		if tile_is_empty(nbr_tile^) {
			sa.push(&new_libs, neighbor)
		} else if nbr_tile^ & {.Controller_Is_Host} == tile_control {
			// Same Controller
			tile_liberties_countdown -= 1

			// record Group of neighbor tile.
			key := game.groups_map[hex_to_index(neighbor)]
			if !slice.contains(nbr_friend_grps.data[:], key) {
				ok := sa.push(&nbr_friend_grps, key)
				assert(ok)
			}
		} else {
			// Different Controller
			tile_liberties_countdown -= 1

			sa.push(&nbr_enemy_tiles, neighbor)
		}
	}
	assert(tile_liberties_countdown >= 0, "if this is broken there is a legality bug")

	// == Are we the Baddies?
	friendly_grps, enemy_grps: ^Group_Store
	if tile_control == {} {
		// Guest Controller
		friendly_grps = &game.guest_grps
		enemy_grps    = &game.host_grps
	} else {
		// Host Controller
		friendly_grps = &game.host_grps
		enemy_grps    = &game.guest_grps
	}

	// The placed Tile's Group, init and add new liberties and enemy connections
	blessed_grp: ^Group
	blessed_key: Group_Handle
	if sa.len(nbr_friend_grps) == 0 {
		blessed_key = store_insert(friendly_grps, Group{ alive = true })
		blessed_grp, _ = store_get(friendly_grps, blessed_key)

		if sa.len(nbr_enemy_tiles) == 0 {
			blessed_grp.extendable = true
		}
	} else {
		ok: bool
		blessed_key = sa.get(nbr_friend_grps, 0)
		blessed_grp, ok = store_get(friendly_grps, blessed_key)
		assert(ok, "Friendly slotmap does not have friendly blessed Key")

		// == Merge other groups with blessed group
		for i in 1 ..< nbr_friend_grps.len {
			temp_grp, ok := store_remove(friendly_grps, sa.get(nbr_friend_grps, i))
			assert(ok, "Friendly slotmap does not have friendly Key")

			blessed_grp.state      |= temp_grp.state
			blessed_grp.extendable &= temp_grp.extendable
		}
	}
	blessed_grp.state[hex_to_index(move.hex)] |= .Member_Tile

	// == Update liberties
	for i in 0 ..< new_libs.len {
		h   := sa.get(new_libs, i)
		idx := hex_to_index(h)
		blessed_grp.state[idx] |= .Liberty
	}
	// == Update Enemy neighbors for blessed group
	for i in 0 ..< nbr_enemy_tiles.len {
		h   := sa.get(nbr_enemy_tiles, i)
		idx := hex_to_index(h)
		blessed_grp.state[idx] |= .Enemy_Connection
	}

	// == Update the groupmap. deferred because other captures may happen
	defer {
		blessed_grp.extendable = true
		for slot, idx in blessed_grp.state {
			#partial switch slot {
			case .Member_Tile:
				game.groups_map[idx] = blessed_key
			case .Enemy_Connection:
				blessed_grp.extendable = false
			}
		}
	}

	// == register surrounding Enemy Groups of blessed Group
	surrounding_enemy_grps := make([dynamic]Group_Handle)
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
	level_2_surrounding_friendlies := make([dynamic]Group_Handle)
	defer delete(level_2_surrounding_friendlies)

	// == go over surrounding enemy groups to see if they're dead.
	capture_occurance := false
	for key in surrounding_enemy_grps {
		temp_grp, ok := store_get(enemy_grps, key)
		assert(ok, "Enemy slotmap does not have enemy Key")
		temp_grp.state[hex_to_index(move.hex)] |= .Enemy_Connection // this is probably correct

		// Enemy Group is dead
		(group_life(temp_grp) == 0) or_continue
		capture_occurance = true

		cursed_grp, _ := store_remove(enemy_grps, key)

		for slot, idx in cursed_grp.state {
			#partial switch slot {
			case .Member_Tile:
				tile_flip(&game.board[idx])
			case .Enemy_Connection:
				fkey := game.groups_map[idx]
				if !slice.contains(level_2_surrounding_friendlies[:], fkey) {
					append(&level_2_surrounding_friendlies, fkey)
				}
			}
		}

		// CAPTURE
		blessed_grp.state      |= cursed_grp.state
		blessed_grp.extendable &= cursed_grp.extendable
	}

	// == merge level 2 surrounding friendlies into blessed group
	for key in level_2_surrounding_friendlies {
		temp_grp, ok := store_remove(friendly_grps, key)
		assert(ok, "I have no idea what this is asserting, right now")

		blessed_grp.state |= temp_grp.state
		blessed_grp.extendable &= temp_grp.extendable
	}

	// == if there is a capture, it is done.
	if capture_occurance do return

	// == if blessed group's liberties larger than 0, it is done capturing
	if group_life(blessed_grp) > 0 do return

	// == Now the blessed group has converted.

	cursed_grp, _ := store_remove(friendly_grps, blessed_key)

	new_family := make([dynamic]Group_Handle)
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

	ok: bool
	blessed_key = new_family[0]
	blessed_grp, ok = store_get(enemy_grps, blessed_key)
	assert(ok, "Enemy key is not in enemy map")

	blessed_grp.state |= cursed_grp.state

	for i in 1 ..< len(new_family) {
		temp_grp, ok := store_remove(enemy_grps, new_family[i])
		assert(ok, "This is the second assertion I am not sure what is")

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

@(private)
game_regen_legal_moves :: proc(game: ^Game) {
	clear(&game.legal_moves)

	// == Are we the Baddies?
	friendly_grps: ^Group_Store
	friendly_hand: ^Hand
	enemy_grps:    ^Group_Store

	switch game.to_play {
	case .Guest:
		friendly_grps = &game.guest_grps
		friendly_hand = &game.guest_hand
		enemy_grps    = &game.host_grps
	case .Host:
		friendly_grps = &game.host_grps
		friendly_hand = &game.host_hand
		enemy_grps    = &game.guest_grps
	}

	// get the hexes allowed to be played in
	playable_hexes := make([dynamic]Hex)
	defer delete(playable_hexes)

	outer: for key, idx in game.groups_map {
		if key.valid do continue // Hex must be empty.

		hex := hex_from_index(idx)
		for flag in CONNECTION_FLAGS {
			nbr_hex := hex + flag_dir(flag)
			nbr_idx := hex_to_index(nbr_hex) or_continue

			nbr_key := game.groups_map[nbr_idx]
			nbr_key.valid or_continue

			if _, ok := store_get(enemy_grps, nbr_key); ok {
				append(&playable_hexes, hex)
				continue outer
			} else if grp, ok := store_get(friendly_grps, nbr_key); ok {
				if grp.extendable && grp.state[idx] == .Liberty {
					append(&playable_hexes, hex)
					continue outer
				}
			} else {
				panic("key is not 0, is not in friendly groups, not in enemy groups, ??")
			}
		}
	}

	for hex in playable_hexes {
		for tile in friendly_hand {
			if tile_is_empty(tile) do continue

			score   := 0 // if score is 6, tile is playable.
			osc_pen := 0 // unless this is the same as Tile cardinality
			defer if score == 6 && osc_pen != card(tile & CONNECTION_FLAGS) { 
				append(&game.legal_moves, Move{hex, tile}) 
			}

			for flag in CONNECTION_FLAGS {
				nbr_hex  := hex + flag_dir(flag)
				nbr_idx, in_bounds := hex_to_index(nbr_hex)
				nbr_tile := game.board[nbr_idx] // this is fine as `nbr_idx` is 0 when hex is out of bounds.
				
				((!in_bounds && flag not_in tile) ||
				(in_bounds && (tile_is_empty(nbr_tile) ||
				       	       (flag in     tile && flag_opposite(flag) in     nbr_tile) ||
					       (flag not_in tile && flag_opposite(flag) not_in nbr_tile)))) or_break

				score += 1

				// Only check for Oscillation if it takes away a Liberty.
				(in_bounds && flag_opposite(flag) in nbr_tile) or_continue

				nbr_key := game.groups_map[nbr_idx]

				if nbr_grp, ok := store_get(enemy_grps, nbr_key); ok {
					if group_life(nbr_grp) == 1 && nbr_grp.extendable {
						osc_pen += 1
					}
				} else if nbr_grp, ok := store_get(friendly_grps, nbr_key); ok {
					if group_life(nbr_grp) == 1 && nbr_grp.extendable {
						osc_pen += 1
					}
				}
			}
		}
	}
}

// A player's territory consists of the number of their pieces on the board minus the number of pieces they didn't place.
game_get_score :: proc(game: ^Game) -> (guest, host: int) {
	// maybe better as struct fields updated as moves are made?
	for tile in game.board {
		if tile_is_empty(tile) do continue
		if .Controller_Is_Host in tile {
			host  += 1
		} else {
			guest += 1
		}
	}
	for i in 0 ..< HAND_SIZE {
		if !tile_is_empty(game.guest_hand[i]) do guest -= 1
		if !tile_is_empty(game.host_hand[i])  do host  -= 1
	}

	return
}

