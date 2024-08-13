package main

import "core:fmt"

Test_State :: enum u8 {
	Empty = 0x00, // numbers chosen for a reason
	Lbrty = 0x01,
	Enemy = 0x11,
	Mmber = 0x13,
}

main :: proc() {
	for flag in Test_State{
		fmt.printf("\t%v", flag)

	}
	fmt.println("")
	for flag in Test_State {
		fmt.printf("%v:", flag)
		for glaf in Test_State {
			fmt.printf("\t%v", flag | glaf)
		}
		fmt.println("")
	}

}
