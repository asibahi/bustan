package bustan

import "core:fmt"

Test_State :: enum u8 {
	Empty = 0o000, // numbers chosen for a reason
	Lbrty = 0o001,
	Enemy = 0o011,
	Mmber = 0o111,
}

main :: proc() {
	for flag in Test_State {
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
