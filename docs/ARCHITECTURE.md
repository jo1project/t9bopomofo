# Architecture: librime + octagram

## Engine

Custom `zhuyin_phone` UI + **librime** (fulanto/LibrimeKit 2.9.0) with:

- **librime-lua** (`t9_sort_filter`, `user_predict`)
- **librime-octagram** (`zh-hant-t-essay-bgw.gram` contextual suggestions)
- essay vocabulary + `bopomofo_phone` / `bopomofo_t9`

Frameworks are downloaded by `Scripts/download-frameworks.sh` (not committed).

## Runtime

| Layer | Path |
|-------|------|
| UI | Swift keyboard |
| Engine | `RimeEngine` → `rime_get_api()` |
| Fallback | Swift T9 if Rime fails |
| Shared data | App Group `…/rime/SharedSupport` (essay, `.gram`, prelude) |
| User data | App Group `…/rime/user` (schemas, dicts, lua, build) |

## Product rules

Symbol / space / return → insert only + `clear_composition` (never first-candidate commit).
