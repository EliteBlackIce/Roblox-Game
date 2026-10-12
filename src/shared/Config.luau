--!strict
-- Core gameplay tuning for Junkyard Simulator. Content catalogs (items, zones,
-- tools, bots, quests) live in their own modules next to this one.

local Config = {}

Config.Gameplay = {
	StartingCash = 0,
	BaseCapacity = 10,
	BaseCooldown = 1.6, -- seconds between collections at Speed level 0
	MinCooldown = 0.45, -- collection speed can never go below this
	BaseWalkSpeed = 16,
	CollectRange = 14, -- max studs between character and pile, checked on the server
	StationRange = 18, -- sell stations, shops, crates, gates
	CooldownTolerance = 0.1, -- latency allowance on the server-side cooldown check
	RequestThrottle = 0.15, -- min seconds between UI requests per player
	AutosaveInterval = 120,
	AutoCollectInterval = 0.25,
	GemChanceOnEpic = 1, -- gems granted per Epic+ find
}

Config.ScrapPiles = {
	MinCharges = 3, -- collections a pile gives before it is used up
	MaxCharges = 6,
	RespawnTime = 18, -- seconds before a depleted pile comes back
}

Config.Events = {
	GoldenPileInterval = { 120, 210 }, -- seconds between golden piles (random in range)
	GoldenPileDuration = 75,
	GoldenLuck = 8, -- luck multiplier on a golden pile
	GoldenMythicChance = 0.03, -- chance per item to roll the zone's Mythic on a golden pile
	GoldenGems = 3,
	FrenzyInterval = 720, -- seconds between Scrap Frenzy events
	FrenzyDuration = 90,
	FrenzyCashMultiplier = 2,
	FrenzyCooldownMultiplier = 0.6,
}

export type Rarity = {
	Id: string,
	Name: string,
	Tier: number, -- 0 = Common ... 5 = Mythic
	Color: Color3,
	Announce: boolean, -- server-wide shoutout when found
}

Config.Rarities = {
	{ Id = "Common", Name = "Common", Tier = 0, Color = Color3.fromRGB(200, 200, 205), Announce = false },
	{ Id = "Uncommon", Name = "Uncommon", Tier = 1, Color = Color3.fromRGB(95, 215, 95), Announce = false },
	{ Id = "Rare", Name = "Rare", Tier = 2, Color = Color3.fromRGB(70, 160, 255), Announce = false },
	{ Id = "Epic", Name = "Epic", Tier = 3, Color = Color3.fromRGB(185, 95, 255), Announce = false },
	{ Id = "Legendary", Name = "Legendary", Tier = 4, Color = Color3.fromRGB(255, 175, 40), Announce = true },
	{ Id = "Mythic", Name = "Mythic", Tier = 5, Color = Color3.fromRGB(255, 70, 130), Announce = true },
} :: { Rarity }

Config.RarityById = {} :: { [string]: Rarity }
for _, rarity in Config.Rarities do
	Config.RarityById[rarity.Id] = rarity
end

-- Gem-bought timed boosts.
export type Boost = { Id: string, Name: string, Description: string, Gems: number, Duration: number }
Config.Boosts = {
	{ Id = "Cash", Name = "x2 Cash", Description = "Double sell value", Gems = 40, Duration = 600 },
	{ Id = "Luck", Name = "x2 Luck", Description = "Double luck on every grab", Gems = 40, Duration = 600 },
	{ Id = "Speed", Name = "Turbo Grab", Description = "Grab 40% faster", Gems = 30, Duration = 600 },
} :: { Boost }

-- Monetization. Paste your own IDs from the Creator Dashboard; anything left at 0
-- stays switched off and never appears in the store.
export type GamePass = { Key: string, Id: number, Name: string, Description: string }
Config.GamePasses = {
	{ Key = "DoubleCash", Id = 0, Name = "x2 Cash", Description = "Permanently doubles sell value." },
	{ Key = "BigBackpack", Id = 0, Name = "Mega Backpack", Description = "+50% backpack space." },
	{ Key = "ExtraBots", Id = 0, Name = "+2 Bot Slots", Description = "Equip two more Scrap Bots." },
	{ Key = "VIP", Id = 0, Name = "VIP", Description = "x1.25 cash, x1.25 luck and a gold name tag." },
} :: { GamePass }

export type Product = { Key: string, Id: number, Name: string, Gems: number }
Config.Products = {
	{ Key = "GemsSmall", Id = 0, Name = "100 Gems", Gems = 100 },
	{ Key = "GemsMedium", Id = 0, Name = "550 Gems", Gems = 550 },
	{ Key = "GemsLarge", Id = 0, Name = "1,200 Gems", Gems = 1200 },
} :: { Product }

-- Built-in Studio content sounds, so nothing depends on external audio uploads.
Config.Sounds = {
	Collect = "rbxasset://sounds/collide.wav",
	Sell = "rbxasset://sounds/electronicpingshort.wav",
	Purchase = "rbxasset://sounds/electronicpingshort.wav",
	Error = "rbxasset://sounds/clickfast.wav",
	Click = "rbxasset://sounds/button.wav",
	Rare = "rbxasset://sounds/electronicpingshort.wav",
	Hatch = "rbxasset://sounds/swoosh.wav",
}

return Config
