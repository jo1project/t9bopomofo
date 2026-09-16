# Architecture: Swift T9 + libchewing-derived lexicon

## Engine

Custom `zhuyin_phone` UI + pure Swift T9 matcher:

- `SyllableCodec` — zhuyin (bopomofo) syllable → T9 digits/tone, via `T9KeyMap`
- `DictionaryLoader` — loads `Resources/chewing/*.dict.yaml` into an in-memory prefix-indexed lexicon
- `T9SortFilter` — coverage/tone-anchor ranking (ported from Hamster's `rime.lua` `t9_sort_filter`)
- `UserLexicon` — per-user word frequency + bigram, boosts ranking, backed by App Group `UserDefaults` + optional iCloud KVS sync

## Data

- `Resources/chewing/chewing_base.dict.yaml` — generated from [libchewing-data](https://github.com/chewing/libchewing-data)'s `word.csv` (single chars) + `tsi.csv` (phrases) via `Scripts/build-chewing-dict.py`
- `Resources/chewing/taiwan_phrases.dict.yaml` — hand-maintained Taiwan Mandarin slang/brand terms, layered on top; readings are zhuyin (mixed with literal ASCII spelling for loanwords, e.g. `Dcard` → `D card`)

## Runtime

| Layer | Path |
|-------|------|
| UI | Swift keyboard |
| Engine | `InputEngine` → `DictionaryLoader` + `T9SortFilter` |
| User data | App Group `UserDefaults` (`UserLexicon`), optional iCloud KVS |

## Product rules

Symbol / space / return → insert only + `clearComposing` (never first-candidate commit).
