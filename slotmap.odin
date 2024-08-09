package main

foreign import slotmap "deps/stonegroup/libstonegroup.a"
import "core:c"

SmPtr :: distinct rawptr
SmItem :: ^Group
foreign slotmap {
	slotmap_init :: proc() -> SmPtr ---
	slotmap_destroy :: proc(sm: SmPtr) ---
	slotmap_insert :: proc(sm: SmPtr, item: SmItem) -> c.uint64_t ---
	slotmap_contains_key :: proc(sm: SmPtr, key: c.uint64_t) -> c.bool ---
	slotmap_get :: proc(sm: SmPtr, key: c.uint64_t) -> SmItem ---
	slotmap_remove :: proc(sm: SmPtr, key: c.uint64_t) -> SmItem ---
}
