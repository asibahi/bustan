package bustan

import "core:fmt"

main :: proc() {
	input, out: Hex
	idx: int
	okto, okfrom: bool

	input = CENTER
	idx, okto = hex_to_index(input)
	out, okfrom = hex_from_index(idx)

	fmt.printfln("CENTER: %v, %v, %v, %v, %v", input, idx, okto, out, okfrom)

	// ===
	input = Hex{N,N}
	idx, okto = hex_to_index(input)
	out, okfrom = hex_from_index(idx)

	fmt.printfln("TPRGHT: %v, %v, %v, %v, %v", input, idx, okto, out, okfrom)

}
