# Architecture: librime-backed T9 Zhuyin

## Short answer

Hamster is a keyboard shell around **librime**. This app now does the same:
custom `zhuyin_phone` UI + **librime** (LibrimeKit xcframeworks) running your
`bopomofo_phone` / `bopomofo_t9` schema, `rime.lua` (`t9_sort_filter`),
`user_predict` Lua, and `essay.txt`.

## Runtime layout

| Layer | Implementation |
|-------|----------------|
| UI | Swift keyboard (`zhuyin_phone`) |
| Engine | `RimeEngine` → librime C API (`process_key` / candidates / `clear_composition`) |
| Fallback | Swift T9 matcher if Rime fails to start |
| Schema / dict / lua | Bundled under `Resources/rime/`, copied to App Group on first launch |
| xcframeworks | `Scripts/download-frameworks.sh` (amorphobia/LibrimeKit) |
| essay | `Scripts/download-models.sh` |

## Product rules preserved

- Symbol / space / return → insert only + `clear_composition` (never first-candidate commit)
- Exact long-press sends schema letters (`b`/`g`/…) into Rime, not just T9 digits
- User learning still via App Group `UserLexicon` (+ Rime userdb / lua predict)

## Known gap

`zh-hant-t-essay-bgw.gram` needs **librime-octagram**, which is not in LibrimeKit
v0.1.0. Schema `grammar:` is commented out until that plugin is linked. Essay +
Poet + `t9_sort_filter` still provide Hamster-like ranking for most cases.
