package main

import "core:fmt"

Test_State :: enum u8 {
	Empty   = 0x00, // numbers chosen for a reason
	Liberty = 0x01,
	Member  = 0x11,
	Enemy   = 0x21,
}

main :: proc() {
	for flag in Test_State {
		for glaf in Test_State {
			fmt.printfln("%v\t| %v\t== %v", flag, glaf, flag | glaf)
		}
	}

}
