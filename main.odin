package bustan

import "core:fmt"

main :: proc() {
	game := game_init()
	defer game_destroy(game)

	ok: bool

	ok = game_make_move(&game, Move{hex = {0, 0}, tile = tile_from_id(63, .Guest)})
	fmt.printfln("%v", ok)

	ok = game_make_move(&game, Move{hex = {N, 0}, tile = tile_from_id(63, .Host)})
	fmt.printfln("%v", ok)

	// fmt.printfln("%v", game.board) 
}
