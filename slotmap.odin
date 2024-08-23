package bustan

foreign import slotmap "deps/slotmap/libslotmap.a"
import "core:c"

Slot_Map :: distinct rawptr
Sm_Key   :: distinct c.uint64_t
Sm_Item  :: ^Group

foreign slotmap {
	slotmap_init	     :: proc() 				  -> Slot_Map ---
	slotmap_destroy	     :: proc(sm: Slot_Map) ---
	slotmap_insert	     :: proc(sm: Slot_Map, item: Sm_Item) -> Sm_Key ---
	slotmap_contains_key :: proc(sm: Slot_Map, key: Sm_Key)   -> c.bool ---
	slotmap_get	     :: proc(sm: Slot_Map, key: Sm_Key)   -> Sm_Item ---
	slotmap_remove	     :: proc(sm: Slot_Map, key: Sm_Key)   -> Sm_Item ---
}
