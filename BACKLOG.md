# RunForestRun - Backlog

## Critical - Security

- [x] **Client sends raw Instance refs over RemoteEvent (exploitable pickup)**
  FIXED: Server now finds closest brainrot via `findClosestSpawnedBrainrot()` using CollectionService tags. Client reference is ignored.

- [ ] **Audit imported models in build.rbxlx for backdoor scripts**
  The HTTP 500 error referencing `api.roblox.com` with an invalid UserId is not from game code. Check all imported models/assets for hidden scripts making unauthorized HTTP requests.

## High - Data Integrity

- [x] **Player data uses SetAsync instead of UpdateAsync (race condition)**
  FIXED: `savePlayerData()` now uses `UpdateAsync` to prevent data loss on rapid server hops.

- [x] **Code redemption tracking is in-memory only (reusable across servers)**
  FIXED: `playerUsedCodes` is now saved/restored as part of player DataStore data (`data.usedCodes`).

- [x] **BindToClose saves players sequentially (timeout risk)**
  FIXED: `BindToClose` now saves all players concurrently via `task.spawn` with a 25-second safety timeout.

## Medium - Gameplay Bugs

- [x] **Rebirth request has no debounce (double-rebirth exploit)**
  FIXED: Added `playerRebirthing` lock flag, released at every return path in `processRebirth()`.

- [x] **Zone active count can drift due to fragile manual tracking**
  FIXED: Replaced manual `zoneActive` counter with `getZoneActiveCount()` which counts CollectionService-tagged objects per zone folder. All manual increment/decrement removed.

## Medium - Performance

- [x] **Speed update fires every 1s to every player (unnecessary network traffic)**
  FIXED: Added `lastSentSpeedMult` tracker. Speed update only fires when the rounded value (2 decimals) changes.

- [ ] **Credit plate collection polls every 0.2s for all players x all slots**
  File: `BrainrotSpawnEngine.server.lua:1100-1131`
  Iterates every player x 10 slots every 0.2 seconds. Fine for 2 max players but doesn't scale. Consider Touched events or less frequent polling.

## Medium - Architecture

- [ ] **Extract shared data into src/shared/ (eliminate duplication)**
  The `shared/` directory is empty. BRAINROTS definitions, rarity colors, mutations, and constants are duplicated between server and client. Create:
  - `src/shared/BrainrotConfig.lua` - BRAINROTS, RARITIES, RARITY_COLORS, MUTATIONS
  - `src/shared/Constants.lua` - PICKUP_DISTANCE, HOLD_TIME, BASE_SLOTS, etc.

- [x] **Delete or wire in GameManager.lua (dead code)**
  FIXED: Deleted `src/server/GameManager.lua` - was 242 lines of unreferenced dead code.

- [ ] **Break up monolithic scripts**
  - `BrainrotSpawnEngine.server.lua`: ~2,650 lines
  - `BrainrotPlayerScripts.client.lua`: ~2,100 lines
  - `AdminClient.client.lua`: ~1,350 lines
  Consider splitting by system (spawn, deposit, sell, rebirth, leaderboard, store, UI).

## Low - Code Quality

- [ ] **Replace placeholder gamepass/product IDs before launch**
  Files: `BrainrotSpawnEngine.server.lua:40-41`, line 59
  `ADMIN_PANEL = 0`, `DOUBLE_MONEY = 0`, `GROUP_ID = 0`, all `LUCK_PRODUCT_IDS` have `id = 0`. Code handles `id > 0` checks so it won't break, but these need real values.

- [ ] **Pick one language for player-facing strings (Swedish/English mix)**
  Admin responses use Swedish ("Spelaren hittades inte", "Ogiltigt belopp") while Store/Code UI uses English. Standardize to one language.

- [x] **Gate debug prints behind a DEBUG flag or remove**
  FIXED: Added `DEBUG = false` flag and `debugPrint()`/`debugWarn()` helpers to both server scripts. All verbose prints gated.

- [x] **Fix leaderboard log count IIFE antipattern**
  FIXED: Added `tableCount()` utility function, replaced inline IIFEs in AdminServer.

- [ ] **Clean up unused sellProgress parameters**
  File: `BrainrotSpawnEngine.server.lua:1156`
  `sellProgressEvent:FireClient(player, false, 0, 0, 0)` sends extra unused parameters on cancel. Minor bandwidth waste.

## Low - Deprecation Fixes (in build.rbxlx / Studio models)

- [ ] **Replace SetPartCollisionGroup with BasePart.CollisionGroup**
  102.1K occurrences in server. Located in imported models, not in Lua source files.

- [ ] **Replace CreateCollisionGroup with RegisterCollisionGroup**
  85.0K occurrences in server. Located in imported models.

- [ ] **Replace Humanoid:Move() with Player:Move()**
  51.0K occurrences in server. Located in imported models or default scripts.
