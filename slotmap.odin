package main

foreign import slotmap "deps/slotmap/libslotmap.a"
import "core:c"

SmPtr :: distinct rawptr
SmKey :: distinct c.uint64_t
SmItem :: ^Group

foreign slotmap {
	slotmap_init :: proc() -> SmPtr ---
	slotmap_destroy :: proc(sm: SmPtr) ---
	slotmap_insert :: proc(sm: SmPtr, item: SmItem) -> SmKey ---
	slotmap_contains_key :: proc(sm: SmPtr, key: SmKey) -> c.bool ---
	slotmap_get :: proc(sm: SmPtr, key: SmKey) -> SmItem ---
	slotmap_remove :: proc(sm: SmPtr, key: SmKey) -> SmItem ---
}
