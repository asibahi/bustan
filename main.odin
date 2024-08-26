package bustan

import "core:fmt"

main :: proc() {
	game := game_init()
	defer game_destroy(game)

	ok: bool

	ok = game_make_move(&game, Move{hex = {0, 0}, tile = tile_from_id(63, .Guest)})
	fmt.printfln("%v", ok)

	ok = game_make_move(&game, Move{hex = RIGHT, tile = ~{.Right}})
	fmt.printfln("%v", ok)

	for key in game.groups_map {
		fmt.printf("%v, ", transmute(u8)key)
	}
}
