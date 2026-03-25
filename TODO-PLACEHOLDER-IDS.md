# Placeholder IDs — Action Required Before Launch

All placeholder IDs (`= 0`) in `src/shared/GameConfig.lua` must be replaced
with real Roblox asset IDs created in the [Creator Dashboard](https://create.roblox.com).

The code handles `id == 0` gracefully (shows "Coming Soon", skips purchases),
so the game won't break — but the Store tab won't sell anything until these are set.

---

## Gamepasses (Creator Dashboard → Monetization → Passes)

| Config Key     | Pass Name     | Status           | ID to paste in GameConfig.lua |
|----------------|---------------|------------------|-------------------------------|
| `ADMIN_PANEL`  | Admin Panel   | ❌ Not created   | `__________`                  |
| `DOUBLE_MONEY` | 2x Money      | ❌ Not created   | `__________`                  |
| `VIP`          | V.I.P Pass    | ✅ Done          | `1763788455`                  |

## Developer Products (Creator Dashboard → Monetization → Developer Products)

| Config Entry       | Product Name           | Robux Price | Status         | ID to paste |
|--------------------|------------------------|-------------|----------------|-------------|
| Luck 5x (15 min)   | 5x Luck (15 min)       | 99          | ❌ Not created | `________`  |
| Luck 10x (15 min)  | 10x Luck (15 min)      | 249         | ❌ Not created | `________`  |
| Luck 25x (30 min)  | 25x Luck (30 min)      | 499         | ❌ Not created | `________`  |
| Luck 50x (30 min)  | 50x Luck (30 min)      | 999         | ❌ Not created | `________`  |
| Luck 100x (1 hr)   | 100x Luck (1 hr)       | 1,999       | ❌ Not created | `________`  |
| Luck 250x (1 hr)   | 250x Luck (1 hr)       | 3,999       | ❌ Not created | `________`  |
| Luck 500x (2 hr)   | 500x Luck (2 hr)       | 7,999       | ❌ Not created | `________`  |
| Luck 1000x (2 hr)  | 1000x Luck (2 hr)      | 14,999      | ❌ Not created | `________`  |

---

## How to create them

### Gamepasses
1. Go to https://create.roblox.com → select your game
2. Monetization → Passes → Create a Pass
3. Name it, set the price, upload an icon
4. Copy the **Pass ID** from the URL or details page
5. Paste it into `src/shared/GameConfig.lua` line 52-56

### Developer Products
1. Go to https://create.roblox.com → select your game
2. Monetization → Developer Products → Create a Developer Product
3. Name it (e.g. "5x Luck (15 min)"), set the Robux price
4. Copy the **Product ID**
5. Paste it into `src/shared/GameConfig.lua` lines 63-70

---

## Where to paste the IDs

File: `src/shared/GameConfig.lua`

```lua
-- Line 52-56: Gamepasses
GameConfig.GAMEPASS_IDS = {
    ADMIN_PANEL  = PASTE_ID_HERE,
    DOUBLE_MONEY = PASTE_ID_HERE,
    VIP          = 1763788455,
}

-- Line 62-71: Luck Products
GameConfig.LUCK_PRODUCTS = {
    { id = PASTE_ID_HERE, mult = 5,    duration = 15,  price = 99    },
    { id = PASTE_ID_HERE, mult = 10,   duration = 15,  price = 249   },
    { id = PASTE_ID_HERE, mult = 25,   duration = 30,  price = 499   },
    { id = PASTE_ID_HERE, mult = 50,   duration = 30,  price = 999   },
    { id = PASTE_ID_HERE, mult = 100,  duration = 60,  price = 1999  },
    { id = PASTE_ID_HERE, mult = 250,  duration = 60,  price = 3999  },
    { id = PASTE_ID_HERE, mult = 500,  duration = 120, price = 7999  },
    { id = PASTE_ID_HERE, mult = 1000, duration = 120, price = 14999 },
}
```
