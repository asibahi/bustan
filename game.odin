package main

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
	friendly_grps, enemy_grps: Slot_Map

	switch game.to_play {
	case .Guest:
		active_hand = &game.guest_hand
		friendly_grps = game.guest_grps
		enemy_grps = game.host_grps
	case .Host:
		active_hand = &game.host_hand
		friendly_grps = game.host_grps
		enemy_grps = game.guest_grps
	}

	// Make move. Already known to be legal!!
	hand_tile, removed := hand_remove_tile(active_hand, move.tile)
	assert(removed) // but verify
	game.board[hex_to_index(move.hex)] = hand_tile
	move.tile = hand_tile // might be superfluous, but just to ascertain the Owner flags are set correctly

	// First, deal with the case where a Tile starts its own Section
	if grp, ok := group_section_init(move, game); ok {
		grp := new_clone(grp)
		key := slotmap_insert(friendly_grps, grp)
		game.groups_map[hex_to_index(move.hex)] = key
	}

	// todo: update game state

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
