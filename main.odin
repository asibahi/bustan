package bustan

import "core:fmt"
import "core:strings"
import "core:os"

main :: proc() {
	game := game_init()
	defer game_destroy(game)

	moves := strings.split(MOVE_LIST, ";")

	for m, idx in moves {
		move: Move
		ok: bool
		move, ok = move_from_mindsports_parse(m)
		if !ok {
			fmt.println("MOVE PARSER BROKE")
			break
		}

		fmt.println(idx + 1, m)

		ok = game_make_move(&game, move)
		if !ok {
			fmt.println("COULD NOT MAKE MOVE")
			break
		}

		board_print(game.board)

		buffer: [2]u8
		os.read(os.stdin, buffer[:])
	}

}
