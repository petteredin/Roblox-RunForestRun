# RunForestRun - Backlog

## Critical - Security

- [x] **Client sends raw Instance refs over RemoteEvent (exploitable pickup)**
  FIXED: Server now finds closest brainrot via `findClosestSpawnedBrainrot()` using CollectionService tags. Client reference is ignored.

- [x] **Audit imported models in build.rbxlx for backdoor scripts**
  AUDITED: `build.rbxlx` contains only 2 scripts — both are our own (`BrainrotSpawnEngine`, `BrainrotPlayerScripts`). Zero third-party scripts found. Scanned for: HttpService calls, remote require() with numeric IDs, loadstring/getfenv/setfenv, obfuscated strings, TeleportService abuse, unauthorized asset references. All clean. NOTE: A `BearTrap` model with `R6 Hit` script exists in the Studio .rbxl place file (not Rojo-managed) — it throws `Right Leg is not a valid member` errors. This should be fixed or removed in Studio directly.

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

- [x] **Extract shared data into src/shared/ (eliminate duplication)**
  FIXED: Created `src/shared/GameConfig.lua` (109 lines) with BRAINROTS catalog, RARITIES, RARITY_COLORS, MUTATIONS, GAMEPASS_IDS, LUCK_PRODUCTS. Both server and client now `require(GameConfig)` instead of duplicating definitions.

- [x] **Delete or wire in GameManager.lua (dead code)**
  FIXED: Deleted `src/server/GameManager.lua` - was 242 lines of unreferenced dead code.

- [x] **Break up monolithic scripts** (Phase 1 complete)
  Extracted 6 modules so far:
  - `src/client/IndexPanel.lua` (498 lines) — Brainrot index/collection panel
  - `src/client/StorePanel.lua` (823 lines) — V.I.P, Server Luck, Codes tabs
  - `src/server/RemoteSetup.lua` (106 lines) — Centralized RemoteEvent/Function/Bindable creation
  - `src/server/SpawnSystem.lua` (418 lines) — Spawn, despawn, rarity/mutation rolling, billboard prompts
  - `src/shared/GameConfig.lua` (109 lines) — Shared data catalog
  - `src/client/UFOWarningUI.client.lua` (151 lines) — UFO beam warning overlay

  Results:
  - `BrainrotPlayerScripts.client.lua`: 2,219 → 1,023 lines (−54%)
  - `BrainrotSpawnEngine.server.lua`: 3,099 → 2,685 lines (−13%)

  Remaining in orchestrator (high coupling, future phases):
  - Pickup/carry system (~400 lines)
  - Slot/deposit system (~350 lines)
  - Sell/upgrade system (~350 lines)
  - Rebirth system (~200 lines)
  - DataStore save/load (~400 lines)
  - Leaderboard (~200 lines)
  - VIP/gamepass (~150 lines)
  - Speed accelerator (~100 lines)

## Low - Code Quality

- [ ] **Replace placeholder gamepass/product IDs before launch**
  Files: `BrainrotSpawnEngine.server.lua:40-41`, line 59
  `ADMIN_PANEL = 0`, `DOUBLE_MONEY = 0`, `GROUP_ID = 0`, all `LUCK_PRODUCT_IDS` have `id = 0`. Code handles `id > 0` checks so it won't break, but these need real values.

- [x] **Pick one language for player-facing strings (Swedish/English mix)**
  FIXED: All player-facing strings converted to English. One Swedish comment remains in AdminClient (line 333: `-- GUI-BYGGARE`) — cosmetic only.

- [x] **Gate debug prints behind a DEBUG flag or remove**
  FIXED: Added `DEBUG = false` flag and `debugPrint()`/`debugWarn()` helpers to both server scripts. All verbose prints gated.

- [x] **Fix leaderboard log count IIFE antipattern**
  FIXED: Added `tableCount()` utility function, replaced inline IIFEs in AdminServer.

- [ ] **Clean up unused sellProgress parameters**
  File: `BrainrotSpawnEngine.server.lua:1156`
  `sellProgressEvent:FireClient(player, false, 0, 0, 0)` sends extra unused parameters on cancel. Minor bandwidth waste.

## Recently Fixed (Code Review Rounds)

- [x] **CRITICAL: require(nil) crash if GameConfig WaitForChild times out**
  FIXED: Added nil guard before `require()` in both BrainrotSpawnEngine and AdminClient.

- [x] **CRITICAL: slotUpgrades nil guard at upgrade click**
  FIXED: Auto-create empty table `slotUpgrades[player] = {}` before accessing slot index.

- [x] **CRITICAL: walletLabel used before creation in sellResultEvent**
  FIXED: Added `if walletLabel then` nil guard.

- [x] **CRITICAL: clickToRebirthBtn undefined**
  FIXED: Replaced with `rebirthReqFrame` (the actual clickable element).

- [x] **CRITICAL: TweenService never required (admin broadcast crash)**
  FIXED: Added `local TweenService = game:GetService("TweenService")`.

- [x] **CRITICAL: luckFrame variable shadowing (HUD luck wrote to Store tab)**
  FIXED: Renamed Store tab variable to `storeLuckFrame`.

- [x] **HIGH: 12 remote events without nil guards**
  FIXED: All `safeWait()`/`WaitForChild` results now nil-checked before `.OnClientEvent:Connect()`.

- [x] **HIGH: Luck purchase could downgrade active luck (5x overwrites 1000x)**
  FIXED: Added `if newMult <= serverLuckMult and remaining > 60 then return` guard.

- [x] **HIGH: slotDepositTime race condition**
  FIXED: Moved `slotDepositTime` creation before `playerSlots` assignment.

- [x] **HIGH: Redeem code race condition on server hop**
  FIXED: Added atomic DataStore check with per-player-per-code key.

- [x] **MEDIUM: getMutation reverse-lookup loop**
  FIXED: `getMutation()` now returns both `mutation, mutationKey`.

- [x] **MEDIUM: Rebirth off-by-one (rebirth 10 requirements not shown)**
  FIXED: Changed boundary check to include `MAX_REBIRTHS`.

- [x] **MEDIUM: storedBlock nil check before CollectionService tag**
  FIXED: Added `if not storedBlock then warn(...) return end` guard.

- [x] **MEDIUM: No bounds validation on admin numeric commands**
  FIXED: Added `math.max(0, ...)` and range checks to SetCredits, SetRebirth, SetSpeed.

- [x] **MEDIUM: unpack(data.undoArgs) without type guard**
  FIXED: Added `type(data.undoArgs) == "table"` check before unpack.

## Low - Deprecation Fixes (in build.rbxlx / Studio models)

- [ ] **Replace SetPartCollisionGroup with BasePart.CollisionGroup**
  102.1K occurrences in server. Located in imported models, not in Lua source files.

- [ ] **Replace CreateCollisionGroup with RegisterCollisionGroup**
  85.0K occurrences in server. Located in imported models.

- [ ] **Replace Humanoid:Move() with Player:Move()**
  51.0K occurrences in server. Located in imported models or default scripts.
