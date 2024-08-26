package bustan

Hex_State :: enum u8 {
	Empty            = 0b000, // numbers chosen for a reason
	Liberty          = 0b001,
	Enemy_Connection = 0b011,
	Member_Tile      = 0b111,
}

Group :: struct {
	state:      [CELL_COUNT]Hex_State,
	using status: bit_field u8 {
		extendable: bool | 1,
		alive:      bool | 1,
		__:         u8   | 6,
	},
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

Group_Handle :: bit_field u8 {
	idx:   u8     | 6,
	owner: Player | 1,
	valid: bool   | 1,
}

Group_Store :: struct {
	data:        [HAND_SIZE]Group,
	using _meta: bit_field u8 {
		cursor: u8     | 7,
		player: Player | 1,
	}
}

store_insert :: proc(store: ^Group_Store, group: Group) -> Group_Handle {
	assert(group.alive, "trying to insert a dead group!")
	store.data[store.cursor] = group
	defer store.cursor += 1

	return Group_Handle{idx = store.cursor, owner = store.player, valid = true}
}

store_get :: proc(store: ^Group_Store, key: Group_Handle) -> (ret: ^Group, ok: bool) {
	(key.valid &&
	 store.player == key.owner && 
	 key.idx < store.cursor && 
	 store.data[key.idx].alive) or_return

	return &store.data[key.idx], true
}

store_remove :: proc(store: ^Group_Store, key: Group_Handle) -> (ret: Group, ok: bool) {
	grp := store_get(store, key) or_return
	defer grp.alive = false

	return grp^, true
}
