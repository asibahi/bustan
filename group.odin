package bustan

Hex_State :: enum u8 {
	Empty            = 0o000, // numbers chosen for a reason
	Liberty          = 0o001,
	Enemy_Connection = 0o011,
	Member_Tile      = 0o111,
}

Group :: struct {
	state:      [CELL_COUNT]Hex_State,
	extendable: bool,
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
