package main

Player :: enum u8 {
	Guest, // White
	Host, // Black
}

Move :: struct {
	loc:  Hex,
	tile: Tile,
}

Status :: enum u8 {
	Ongoing,
	GuestWin,
	HostWin,
	Tie,
}

Game :: struct {
	board:                 Board,
	to_play:               Player,
	status:                Status,
	//
	guest_hand, host_hand: Hand,
	//
	groups_map:            [CELL_COUNT]int, // Group indices?
	guest_grps, host_grps: [dynamic]Group,
	//
	// do i need these?
	move_history:          [dynamic]Move,
	board_history:         [dynamic]Board,
}

game_init :: proc() -> (ret: Game) {
	// All other fields start with zero values except these two.
	ret.guest_hand, ret.host_hand = hands_init()
	return
}

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

	return
}

game_get_legal_moves :: proc(game: ^Game) -> [dynamic]Move {
	// todo

	return nil
}
