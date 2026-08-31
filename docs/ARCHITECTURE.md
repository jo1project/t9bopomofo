# Architecture: why Hamster feels smarter

## Short answer

Hamster is **not** a custom decoder. It is a keyboard shell around **librime**
(Rime) plus your schema (`bopomofo_phone` / `bopomofo_t9`), `rime.lua`
(`t9_sort_filter`), optional `user_predict` Lua, `essay.txt`, and
`zh-hant-t-essay-bgw.gram`.

This app originally shipped a **hand-rolled Swift T9 matcher**. That is why
fixes looked like “one word at a time”: we were patching symptoms of a toy
ranker, not running the same engine Hamster uses.

## What Rime actually does

1. **Speller algebra** — maps pinyin → internal codes → T9 digits (your schema).
2. **Syllable graph** — every legal segmentation of the key stream.
3. **script_translator + Poet** — dictionary lookup + sentence composition
   using `essay` phrase table.
4. **octagram grammar** (`.gram`) — reweights candidates with preceding text
   (`contextual_suggestions`).
5. **t9_sort_filter (rime.lua)** — UI-facing order:
   - full-coverage first
   - first-syllable promote when a tone anchors syllable 1 (this is why `有`
     appears when you type tone after `ㄧㄡ`)
   - round-robin partial spans so you can segment-select
   - orphan-tone breaks last
6. **user_predict.lua** — post-commit association learning.

## Direction in this repo

| Layer | Status |
|-------|--------|
| UI (`zhuyin_phone`) | Custom Swift keyboard (kept) |
| Ranking | Porting `t9_sort_filter` into Swift; next: real librime |
| Schema / dict / lua | Bundled under `Resources/rime/` (from your uploads + [SSARCandy/rime-bopomofo-t9](https://github.com/SSARCandy/rime-bopomofo-t9)) |
| librime xcframework | `Scripts/download-frameworks.sh` (LibrimeKit) |
| `.gram` / `essay.txt` | `Scripts/download-models.sh` |

Whack-a-mole weight edits in `taiwan_phrases` remain as **Taiwan boosts**, not
as the primary ranking strategy.

## What you should expect

After librime is wired end-to-end, candidate quality should approach Hamster /
元書 for the same schema+dict+gram. Until then, the Swift port of
`t9_sort_filter` + full-span preference closes the worst gaps (`好像`/`有`/tone).
