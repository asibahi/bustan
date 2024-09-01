package bustan

/*
 this module is only used for converting the notation in:
 https://mindsports.nl/index.php/dagaz/131-workshops/955-dominions-example-workshop
*/

import "core:strconv"

MOVE_LIST :: "W[P63i9];B[P55h8];W[P30h9];B[P63g8];W[P62g9];B[P51f8];W[P60i8];B[P47h7];W[P61i7];B[P39h6];W[P55i6];B[P59i5];W[P31j6];B[P61j5];W[P27k6];B[P23f9];W[P47g10];B[P58h5];W[P2e9];B[P62j10];W[P12j11];B[P54j9];W[P39i10];B[P46j8];W[P16k8];B[P27k7];W[P15l8];B[P57l6];W[P42j7];B[P31m9];W[P59m8];B[P19l9];W[P8n10];B[P30n9];W[P51n8];B[P29o9];W[P48o8];B[P53k12];W[P32k11];B[P37p9];W[P33p8];B[P15l13];W[P14p10];B[P52q11];W[P56q10];B[P50p11];W[P50k9];B[P22k10];W[P18l10];B[P8q9];W[P24m10];B[P10m7];W[P4q12];B[P38l12];W[P54o11];B[P21p12];W[P40q13];B[P60q14];W[P1p13];B[P35n11];W[P44q15];B[P12p15]"

move_mindsports_parse :: proc(str: string) -> (ret: Move, success: bool) #optional_ok {
	// move format: B[P12p15]

	player: Player
        switch str[0] {
        case 'W': player = .Guest
        case 'B': player = .Host
        case: return {}, false
        }

	c := 3
	tile: Tile

        for len := 2; len >= 0; len -= 1 {
                if len == 0 do return {}, false
                if id, ok := strconv.parse_uint(str[c:][:len]); ok {
                        c += len
                        tile = tile_mindsports_id(u8(id), player)
                        break
                }
        }

	row := N - i8(str[c] - 'a')
        c += 1
        
	col: i8
        for len := 2; len >= 0; len -= 1 {
                if len == 0 do return {}, false
                if res, ok := strconv.parse_uint(str[c:][:len]); ok {
                        col = i8(res) - N - 1
                        break
                }
        }

	return {tile = tile, hex = {col, row}}, true
}

tile_mindsports_id :: proc(id: u8, player: Player) -> (ret: Tile) {
	assert(0 < id, "Blank Tile is not playable")
	assert(id <= HAND_SIZE, "Tile is impossible")

	if id & (1 << 0) > 0 do ret |= {.Top_Right}
	if id & (1 << 1) > 0 do ret |= {.Top_Left}
	if id & (1 << 2) > 0 do ret |= {.Left}
	if id & (1 << 3) > 0 do ret |= {.Btm_Left}
	if id & (1 << 4) > 0 do ret |= {.Btm_Right}
	if id & (1 << 5) > 0 do ret |= {.Right}

	switch player {
	case .Host: ret |= HOST_FLAGS
	case .Guest:
	}
        
	return
}

// tests 

import "core:testing"

@(test)
test_parse_mindsports :: proc(t: ^testing.T) {
        output := move_mindsports_parse("W[P63i9]")
        expected := Move{tile = tile_from_id(63, .Guest), hex = CENTER }

	testing.expect(t, output == expected)
}
