# Input Latency Optimization

## Summary

This branch implements three key optimizations to reduce input and mode-switching delays in the T9 Bopomofo keyboard.

## Optimizations Implemented

### Priority 1: Background Threading for RimeEngine Operations

**Problem:** All librime C API calls were executed synchronously on the main thread, blocking UI updates during candidate generation.

**Solution:**
- Added a dedicated high-priority serial dispatch queue to RimeEngine
- Implemented async wrapper methods for all key input operations:
  - `processKeyAsync()` - async key processing
  - `backspaceAsync()` - async backspace
  - `clearCompositionAsync()` - async composition clearing
  - `getContextAsync()` - async batch context retrieval
- Added `NSLock` to protect shared session state
- Modified InputEngine to use async operations with automatic task cancellation
- Created `syncFromRimeAsync()` to update UI on main thread after background processing

**Impact:** Input operations no longer block the main thread. UI remains responsive during candidate generation.

### Priority 2: Keyboard View Reuse

**Problem:** `renderKeyboard()` was removing and recreating the entire keyboard view hierarchy on every mode switch, causing expensive layout recalculations.

**Solution:**
- Cache keyboard views for each mode (Zhuyin, English, Symbols, Emoji)
- On mode switch, hide inactive keyboards and show the active one
- Only create each keyboard view once on first access
- Reuse existing views and constraints

**Impact:** Mode switching is now instant - no view allocation or constraint setup overhead.

### Priority 3: Candidate Update Debouncing

**Problem:** `reloadCandidates()` was called immediately after every keystroke, causing frequent UI updates even during rapid typing.

**Solution:**
- Added `reloadCandidatesDebounced()` with 50ms delay
- Uses `DispatchWorkItem` with cancellation for rapid key sequences
- Only the final keystroke triggers UI update when typing quickly

**Impact:** Reduced unnecessary candidate bar updates during fast typing.

## Files Modified

1. `T9Bopomofo/Keyboard/Engine/RimeEngine.swift`
   - Added dispatch queue and lock
   - Added async operation wrappers
   - Protected all session access with locks

2. `T9Bopomofo/Keyboard/Engine/InputEngine.swift`
   - Added `updateTask` for async operation management
   - Converted all Rime operations to use async methods
   - Added `syncFromRimeAsync()` for background sync
   - Task cancellation on new input prevents stale updates

3. `T9Bopomofo/Keyboard/KeyboardViewController.swift`
   - Added cached keyboard view properties
   - Rewrote `renderKeyboard()` to reuse views
   - Added `reloadCandidatesDebounced()` with configurable delay
   - Updated `handleZhuyin()` to use debounced reloads

## Testing Recommendations

1. **Fast typing test:** Type rapidly and verify smooth input without lag
2. **Mode switching test:** Quickly switch between Zhuyin/English/Emoji and verify instant response
3. **Candidate selection test:** Verify candidates still appear correctly after async changes
4. **Memory test:** Switch modes repeatedly and verify no memory leaks from cached views

## Performance Expectations

- Input latency: Should feel near-instant (< 16ms perceived delay)
- Mode switching: Should be instant with no visible delay
- Memory usage: Slightly higher (4 cached keyboard views) but negligible
- CPU usage: Lower due to fewer layout recalculations

## Future Optimization Opportunities

1. Optimize FuzzyMatcher operations (currently runs on main thread during sync)
2. Cache candidate bar layout calculations
3. Implement virtualized scrolling for expanded candidate panel
4. Pre-warm keyboard views during app launch
