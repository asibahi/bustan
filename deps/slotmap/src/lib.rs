#![allow(clippy::missing_safety_doc)]

use slotmap::{DefaultKey, Key, KeyData, SlotMap};
type SmItem = *mut core::ffi::c_void;
type SmPtr = *mut SlotMap<DefaultKey, SmItem>;

#[no_mangle]
pub extern "C" fn slotmap_init() -> SmPtr {
    let sm = Box::new(SlotMap::<_, SmItem>::new());
    Box::into_raw(sm)
}

#[no_mangle]
pub unsafe extern "C" fn slotmap_destroy(sm: SmPtr) {
    _ = unsafe { Box::from_raw(sm) };
}

#[no_mangle]
pub unsafe extern "C" fn slotmap_insert(sm: SmPtr, item: SmItem) -> u64 {
    let Some(sm) = (unsafe { sm.as_mut() }) else {
        return 0;
    };
    let handle = sm.insert(item);
    handle.data().as_ffi()
}

#[no_mangle]
pub unsafe extern "C" fn slotmap_contains_key(sm: SmPtr, key: u64) -> bool {
    let Some(sm) = (unsafe { sm.as_mut() }) else {
        return false;
    };
    let key = DefaultKey::from(KeyData::from_ffi(key));
    sm.contains_key(key)
}

#[no_mangle]
pub unsafe extern "C" fn slotmap_get(sm: SmPtr, key: u64) -> SmItem {
    let Some(sm) = (unsafe { sm.as_mut() }) else {
        return core::ptr::null_mut();
    };
    let key = DefaultKey::from(KeyData::from_ffi(key));
    let ret = sm.get(key);
    *ret.unwrap_or(&core::ptr::null_mut())
}

#[no_mangle]
pub unsafe extern "C" fn slotmap_remove(sm: SmPtr, key: u64) -> SmItem {
    let Some(sm) = (unsafe { sm.as_mut() }) else {
        return core::ptr::null_mut();
    };
    let key = DefaultKey::from(KeyData::from_ffi(key));
    sm.remove(key).unwrap_or(core::ptr::null_mut())
}
