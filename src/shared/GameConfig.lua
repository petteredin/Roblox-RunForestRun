-- =============================================
-- GameConfig (ModuleScript)
-- Shared configuration used by both server and client.
-- Placed in ReplicatedStorage so both sides can require() it.
-- Single source of truth for brainrot catalog, gamepasses,
-- rarity colors, mutations, and luck products.
-- =============================================

local GameConfig = {}

-- =====================
-- BRAINROT CATALOG
-- =====================
-- All 37 brainrots in the game. Must match model names in
-- ReplicatedStorage/NormalBrainrots, GoldenBrainrots, DiamondBrainrots.
GameConfig.BRAINROTS = {
	-- COMMON (8)
	{ name="67 Letter",                 icon="\u{1F4E7}", rarity="COMMON",    baseEarn=10  },
	{ name="Ballerino Lololo",          icon="\u{1FA70}", rarity="COMMON",    baseEarn=9   },
	{ name="Br Br Patapim",            icon="\u{1F438}", rarity="COMMON",    baseEarn=11  },
	{ name="Crab Chef",                 icon="\u{1F980}", rarity="COMMON",    baseEarn=8   },
	{ name="Esok Sekolah",              icon="\u{1F392}", rarity="COMMON",    baseEarn=12  },
	{ name="Frulli Frulla",             icon="\u{1F353}", rarity="COMMON",    baseEarn=9   },
	{ name="Garama",                    icon="\u{1F47E}", rarity="COMMON",    baseEarn=10  },
	{ name="Matteo",                    icon="\u{1F468}", rarity="COMMON",    baseEarn=11  },

	-- UNCOMMON (8)
	{ name="Ballerina Cappuccina",      icon="\u{2615}",  rarity="UNCOMMON",  baseEarn=14  },
	{ name="Bananita Dolphinita",       icon="\u{1F42C}", rarity="UNCOMMON",  baseEarn=16  },
	{ name="Burbaloni Loliloli",        icon="\u{1FAE7}", rarity="UNCOMMON",  baseEarn=13  },
	{ name="Chimpanzini Bananini",      icon="\u{1F412}", rarity="UNCOMMON",  baseEarn=15  },
	{ name="Frigo Camelo",              icon="\u{1F42A}", rarity="UNCOMMON",  baseEarn=17  },
	{ name="Gangster Footera",          icon="\u{1F45F}", rarity="UNCOMMON",  baseEarn=14  },
	{ name="Lirili Larila",             icon="\u{1F335}", rarity="UNCOMMON",  baseEarn=16  },
	{ name="Odin Din Din Dun",          icon="\u{1F941}", rarity="UNCOMMON",  baseEarn=15  },

	-- EPIC (7)
	{ name="Bombombini Gusini",         icon="\u{1FABF}", rarity="EPIC",      baseEarn=22  },
	{ name="Boneca Ambalabu",           icon="\u{1F438}", rarity="EPIC",      baseEarn=25  },
	{ name="Cappucino Assasino",        icon="\u{2615}",  rarity="EPIC",      baseEarn=28  },
	{ name="Garamararam",               icon="\u{1F47E}", rarity="EPIC",      baseEarn=23  },
	{ name="Job Job Job Sahur",         icon="\u{1F4BC}", rarity="EPIC",      baseEarn=20  },
	{ name="Karkerkar Kurkur",          icon="\u{1F993}", rarity="EPIC",      baseEarn=24  },
	{ name="Pipi Kiwi",                 icon="\u{1F95D}", rarity="EPIC",      baseEarn=21  },

	-- LEGENDARY (6)
	{ name="La Vacca Saturno Saturnita", icon="\u{1F404}", rarity="LEGENDARY", baseEarn=40  },
	{ name="Orangutini Ananassini",     icon="\u{1F34D}", rarity="LEGENDARY", baseEarn=45  },
	{ name="Pot Hotspot",               icon="\u{1F4F6}", rarity="LEGENDARY", baseEarn=42  },
	{ name="Strawberry Elephant",       icon="\u{1F353}", rarity="LEGENDARY", baseEarn=38  },
	{ name="Svinina Bombardino",        icon="\u{1F416}", rarity="LEGENDARY", baseEarn=50  },
	{ name="Tralalero Tralala",         icon="\u{1F988}", rarity="LEGENDARY", baseEarn=44  },

	-- MYTHIC (4)
	{ name="Ta Ta Ta Ta Sahur",         icon="\u{1F941}", rarity="MYTHIC",    baseEarn=70  },
	{ name="Trippi Troppi",             icon="\u{1F990}", rarity="MYTHIC",    baseEarn=80  },
	{ name="Trippi Troppi Troppa",      icon="\u{1F990}", rarity="MYTHIC",    baseEarn=75  },
	{ name="Tung Tung Sahur",           icon="\u{1FAB5}", rarity="MYTHIC",    baseEarn=72  },

	-- COSMIC (4)
	{ name="Giraffa Celeste",           icon="\u{1F992}", rarity="COSMIC",    baseEarn=120 },
	{ name="Trulimero Trulicina",       icon="\u{1F30C}", rarity="COSMIC",    baseEarn=140 },
	{ name="Gold Lirili Larila",        icon="\u{1F335}", rarity="COSMIC",    baseEarn=130 },
	{ name="Tralalero Tralala",         icon="\u{1F988}", rarity="COSMIC",    baseEarn=135 },
}

-- =====================
-- MUTATION FOLDER MAPPING
-- =====================
-- Maps mutation key to the ReplicatedStorage folder containing the models
GameConfig.MUTATION_FOLDERS = {
	NONE    = "NormalBrainrots",
	GOLD    = "GoldenBrainrots",
	DIAMOND = "DiamondBrainrots",
}

-- =====================
-- GAMEPASS IDS
-- =====================
GameConfig.GAMEPASS_IDS = {
	ADMIN_PANEL  = 1768316772,  -- Admin Panel GamePass (30,000 R$)
	DOUBLE_MONEY = 1767762906,  -- 2x Money GamePass (125 R$)
	VIP          = 1763788455,  -- V.I.P Pass (350 R$)
}

-- =====================
-- LUCK PRODUCTS (Developer Products)
-- =====================
-- duration is in minutes, price is in Robux
GameConfig.LUCK_PRODUCTS = {
	{ id = 3563392152, mult = 5,    duration = 15,  price = 99    },
	{ id = 3563392463, mult = 10,   duration = 15,  price = 249   },
	{ id = 3563392678, mult = 25,   duration = 30,  price = 499   },
	{ id = 3563392856, mult = 50,   duration = 30,  price = 999   },
	{ id = 3563393031, mult = 100,  duration = 60,  price = 1499  },
	{ id = 3563393233, mult = 250,  duration = 60,  price = 2999  },
	{ id = 3563393401, mult = 500,  duration = 120, price = 5999  },
	{ id = 3563393621, mult = 1000, duration = 120, price = 12999 },
}

-- All available luck multiplier tiers (for admin UI dropdowns)
GameConfig.LUCK_TIERS = { 1, 5, 10, 25, 50, 100, 250, 500, 1000 }

-- =====================
-- RARITY COLORS (Color3 for UI)
-- =====================
GameConfig.RARITY_COLORS = {
	COMMON    = Color3.fromRGB(180, 180, 180),
	UNCOMMON  = Color3.fromRGB(80,  160, 255),
	EPIC      = Color3.fromRGB(180, 100, 255),
	LEGENDARY = Color3.fromRGB(255, 160, 50),
	MYTHIC    = Color3.fromRGB(255, 80,  80),
	COSMIC    = Color3.fromRGB(100, 220, 255),
}

-- =====================
-- RARITY ORDER
-- =====================
GameConfig.RARITY_ORDER = { "COMMON", "UNCOMMON", "EPIC", "LEGENDARY", "MYTHIC", "COSMIC" }

-- =====================
-- MUTATIONS (Rainbow removed)
-- =====================
GameConfig.MUTATIONS = {
	{ key = "NONE",    label = "Normal",  color = Color3.fromRGB(180, 180, 180), weight = 75, mult = 1     },
	{ key = "GOLD",    label = "Gold",    color = Color3.fromRGB(255, 200, 0),   weight = 15, mult = 2.25  },
	{ key = "DIAMOND", label = "Diamond", color = Color3.fromRGB(100, 220, 255), weight = 10, mult = 7.75  },
}

-- Dictionary form for quick lookups (server uses this)
GameConfig.MUTATIONS_BY_KEY = {}
for _, m in ipairs(GameConfig.MUTATIONS) do
	GameConfig.MUTATIONS_BY_KEY[m.key] = { label = m.label, color = m.color, weight = m.weight, mult = m.mult }
end

return GameConfig
