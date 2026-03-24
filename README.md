# Run Forest Run — Save Brainrots from Traps

A Roblox obby experience where players rescue brainrot creatures from traps across 4 difficulty zones, collect them for credits, and compete on leaderboards.

## Game Overview

Players navigate obstacle courses across progressively harder zones, picking up brainrot creatures and depositing them in personal slots to earn credits per second. The game features a rebirth system, mutation rarities, V.I.P. passes, and an admin panel for server management.

## Project Structure

Built with [Rojo](https://rojo.space/) for file-based development and synced to Roblox Studio.

```
Roblox-RunForestRun/
├── default.project.json          # Rojo project config
├── build.rbxlx                   # Roblox Studio place file
├── src/
│   ├── server/                   # ServerScriptService
│   │   ├── BrainrotSpawnEngine.server.lua   # Core game engine
│   │   ├── AdminServer.server.lua           # Admin panel server logic
│   │   └── TrapManager.server.lua           # Trap systems (all zones)
│   ├── client/                   # StarterPlayerScripts
│   │   ├── BrainrotPlayerScripts.client.lua # Player HUD, pickup, sell, UI
│   │   ├── AdminClient.client.lua           # Admin panel client UI
│   │   └── UFOWarningUI.client.lua          # UFO beam warning overlay
│   └── shared/                   # ReplicatedStorage
│       └── GameConfig.lua                   # Shared config (catalog, rarities, mutations)
```

## Core Systems

### Brainrot Spawn Engine
- 30 unique brainrot creatures across 6 rarities (Common to Cosmic)
- 4 mutation types: Normal (75%), Gold (12%), Diamond (8%), Rainbow (5%)
- Zone-based spawning with configurable caps and intervals
- Pickup (hold E), deposit to slots, upgrade, and sell (hold F)
- Rebirth system with escalating requirements

### Zones and Traps

| Zone | Difficulty | Trap Type | Description |
|------|-----------|-----------|-------------|
| 1 | Easy | Spinning Bars | Horizontal bars rotating around a pivot — time your crossing |
| 2 | Medium | Mouse Traps | Giant snap traps on the ground — jump over or avoid |
| 3 | Hard | UFO Abduction | Patrolling UFO with tractor beam — stay out of the green light |

### Economy
- **Credits/sec**: Each slotted brainrot earns credits based on base rate, rarity multiplier, mutation multiplier, and upgrade level
- **Upgrades**: Cost = 20x current earn rate, doubles earn rate per level (max level 10)
- **Selling**: Sell price = 10x current earn rate
- **Rebirth**: Reset progress for permanent multipliers and higher speed caps

### Speed System
- Speed increases +1% per second played
- Capped by rebirth level: Rebirth 0 = 10x max, Rebirth 1 = 20x, up to 100x at Rebirth 9+

### Luck System
- Server-wide luck multiplier boosts rare spawn and mutation chances
- Tiers: 1x, 5x, 10x, 25x, 50x, 100x, 250x, 500x, 1000x
- Activated via Robux purchase or admin grant (timed duration)

### Admin Panel
- Owner and authorized admin access
- Player management: credits, rebirths, speed, ban/unban
- Spawn brainrots by name (server or global scope)
- Grant luck multipliers (server or global, timed)
- Broadcast messages to all players
- Server and global scope for cross-server commands

### V.I.P. Pass
- Permanent gamepass with crown displayed above player
- Shown on session and all-time leaderboards

## Development

### Prerequisites
- [Roblox Studio](https://www.roblox.com/create)
- [Rojo](https://rojo.space/) (VS Code extension or CLI)

### Setup
1. Clone the repository
2. Install and start the Rojo server:
   ```
   rojo serve
   ```
3. Open `build.rbxlx` in Roblox Studio
4. Connect to Rojo via the Studio plugin
5. Changes to `src/` files sync automatically

### Configuration
Game-wide settings are centralized in `src/shared/GameConfig.lua`:
- Brainrot catalog (names, rarities, base earnings)
- Gamepass IDs
- Luck product tiers and pricing
- Rarity colors
- Mutation weights and multipliers

## License

Private project — all rights reserved.
