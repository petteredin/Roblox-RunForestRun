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
-- All brainrots in the game. Server uses modelName (= name) separately.
-- Icon uses Unicode escapes for cross-platform compatibility.
GameConfig.BRAINROTS = {
	{ name="Tralalero Tralala",         icon="\u{1F988}", rarity="COMMON",    baseEarn=10  },
	{ name="Chimpanzini Bananini",      icon="\u{1F412}", rarity="COMMON",    baseEarn=9   },
	{ name="Bobrito Bandito",           icon="\u{1F32F}", rarity="COMMON",    baseEarn=11  },
	{ name="Frulli Frulla",             icon="\u{1F353}", rarity="COMMON",    baseEarn=8   },
	{ name="Frigo Camelo",              icon="\u{1F42A}", rarity="COMMON",    baseEarn=12  },
	{ name="Ballerina Cappuccina",      icon="\u{2615}",  rarity="UNCOMMON",  baseEarn=14  },
	{ name="Liril\195\172 Laril\195\160", icon="\u{1F335}", rarity="UNCOMMON",  baseEarn=16  },
	{ name="Burbaloni Luliloli",        icon="\u{1FAE7}", rarity="UNCOMMON",  baseEarn=13  },
	{ name="Orangutini Ananasini",      icon="\u{1F34D}", rarity="UNCOMMON",  baseEarn=15  },
	{ name="Pot Hotspot",               icon="\u{1F4F6}", rarity="UNCOMMON",  baseEarn=17  },
	{ name="Cappuccino Assassino",      icon="\u{2615}",  rarity="EPIC",      baseEarn=22  },
	{ name="Bombardiro Crocodilo",      icon="\u{1F40A}", rarity="EPIC",      baseEarn=28  },
	{ name="Brr Brr Patapim",           icon="\u{1F438}", rarity="EPIC",      baseEarn=25  },
	{ name="Il Cacto Hipopotamo",       icon="\u{1F99B}", rarity="EPIC",      baseEarn=20  },
	{ name="Espressona Signora",        icon="\u{1F475}", rarity="EPIC",      baseEarn=23  },
	{ name="Trippi Troppi",             icon="\u{1F990}", rarity="LEGENDARY", baseEarn=40  },
	{ name="Bombombini Gusini",         icon="\u{1FABF}", rarity="LEGENDARY", baseEarn=45  },
	{ name="La Vaca Saturno Saturnita", icon="\u{1F404}", rarity="LEGENDARY", baseEarn=50  },
	{ name="Glorbo Fruttodrillo",       icon="\u{1F40A}", rarity="LEGENDARY", baseEarn=42  },
	{ name="Rhino Toasterino",          icon="\u{1F98F}", rarity="LEGENDARY", baseEarn=38  },
	{ name="Tung Tung Tung Sahur",      icon="\u{1FAB5}", rarity="MYTHIC",    baseEarn=70  },
	{ name="Boneca Ambalabu",           icon="\u{1F438}", rarity="MYTHIC",    baseEarn=80  },
	{ name="Garamararamararaman",       icon="\u{1F47E}", rarity="MYTHIC",    baseEarn=75  },
	{ name="Ta Ta Ta Ta Ta Sahur",      icon="\u{1F941}", rarity="MYTHIC",    baseEarn=65  },
	{ name="Tric Trac Baraboom",        icon="\u{1F4A5}", rarity="MYTHIC",    baseEarn=72  },
	{ name="Girafa Celeste",            icon="\u{1F992}", rarity="COSMIC",    baseEarn=120 },
	{ name="Trulimero Trulicina",       icon="\u{1F30C}", rarity="COSMIC",    baseEarn=140 },
	{ name="Blueberrinni Octopussini",  icon="\u{1F419}", rarity="COSMIC",    baseEarn=130 },
	{ name="Graipussi Medussi",         icon="\u{1F347}", rarity="COSMIC",    baseEarn=110 },
	{ name="Zibra Zubra Zibralini",     icon="\u{1F993}", rarity="COSMIC",    baseEarn=135 },
}

-- =====================
-- GAMEPASS IDS
-- =====================
GameConfig.GAMEPASS_IDS = {
	ADMIN_PANEL  = 0,           -- Replace with real ID from Creator Dashboard
	DOUBLE_MONEY = 0,           -- Replace with real ID
	VIP          = 1763788455,  -- V.I.P Pass
}

-- =====================
-- LUCK PRODUCTS (Developer Products)
-- =====================
-- duration is in minutes, price is in Robux
GameConfig.LUCK_PRODUCTS = {
	{ id = 0, mult = 5,    duration = 15,  price = 99    },
	{ id = 0, mult = 10,   duration = 15,  price = 249   },
	{ id = 0, mult = 25,   duration = 30,  price = 499   },
	{ id = 0, mult = 50,   duration = 30,  price = 999   },
	{ id = 0, mult = 100,  duration = 60,  price = 1999  },
	{ id = 0, mult = 250,  duration = 60,  price = 3999  },
	{ id = 0, mult = 500,  duration = 120, price = 7999  },
	{ id = 0, mult = 1000, duration = 120, price = 14999 },
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
-- MUTATIONS
-- =====================
GameConfig.MUTATIONS = {
	{ key = "NONE",    label = "Normal",  color = Color3.fromRGB(180, 180, 180), weight = 75, mult = 1     },
	{ key = "GOLD",    label = "Gold",    color = Color3.fromRGB(255, 200, 0),   weight = 12, mult = 2.25  },
	{ key = "DIAMOND", label = "Diamond", color = Color3.fromRGB(100, 220, 255), weight = 8,  mult = 7.75  },
	{ key = "RAINBOW", label = "Rainbow", color = Color3.fromRGB(255, 100, 200), weight = 5,  mult = 23.25 },
}

-- Dictionary form for quick lookups (server uses this)
GameConfig.MUTATIONS_BY_KEY = {}
for _, m in ipairs(GameConfig.MUTATIONS) do
	GameConfig.MUTATIONS_BY_KEY[m.key] = { label = m.label, color = m.color, weight = m.weight, mult = m.mult }
end

return GameConfig
