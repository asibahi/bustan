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

game_make_move :: proc(game: ^Game, candidate: Maybe(Move)) -> bool {
	(game.status == .Ongoing) or_return // Game is over. What are you doing?

	move, ok := candidate.?
	if !ok { 	// Pass
		if game.last_move == nil {
			// todo: calculate scores and update the game status
			return true
		}
		switch game.to_play {
			case .Guest:
				game.to_play = .Host
			case .Host:
				game.to_play = .Guest
		}
		game.last_move = nil
		game_regen_legal_moves(game)
		return true
	}

	slice.contains(game.legal_moves[:], move) or_return
	defer {
		game.last_move = candidate
		game_regen_legal_moves(game)
	}

	game.board[hex_to_index(move.hex)] = move.tile // we already know it is legal!!

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
		(!tile_is_empty(tile)) or_continue
		if .Controller_Is_Host in tile {
			host += 1
		} else {
			guest += 1
		}
	}
	for tile in game.guest_hand {
		if !tile_is_empty(tile) do guest -= 1
	}
	for tile in game.host_hand {
		if !tile_is_empty(tile) do host -= 1
	}
	return
}
