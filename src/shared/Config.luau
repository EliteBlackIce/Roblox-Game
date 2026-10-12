--!strict
-- Central tuning for Junkyard Simulator. Every number the economy uses lives here,
-- and the server is the only side that acts on it.

local Config = {}

Config.Gameplay = {
	StartingCash = 0,
	BaseCapacity = 10,
	BaseCooldown = 1.6, -- seconds between collections at upgrade level 0
	MinCooldown = 0.5, -- collection speed can never go below this
	CollectRange = 14, -- max studs between character and pile, checked on the server
	SellRange = 16,
	ShopRange = 18,
	CooldownTolerance = 0.1, -- latency allowance on the server-side cooldown check
	PurchaseThrottle = 0.25, -- min seconds between purchase requests per player
	AutosaveInterval = 120,
}

Config.ScrapPiles = {
	MinCharges = 3, -- collections a pile gives before it is used up
	MaxCharges = 6,
	RespawnTime = 20, -- seconds before a depleted pile comes back
}

-- Rarity tier feeds the luck formula: higher tiers benefit more from luck.
export type ScrapType = {
	Id: string,
	Name: string,
	Value: number,
	Weight: number,
	Tier: number,
	Color: Color3,
}

Config.ScrapTypes = {
	{
		Id = "CommonMetal",
		Name = "Common Metal",
		Value = 5,
		Weight = 60,
		Tier = 0,
		Color = Color3.fromRGB(176, 184, 192),
	},
	{
		Id = "CopperWire",
		Name = "Copper Wire",
		Value = 15,
		Weight = 25,
		Tier = 1,
		Color = Color3.fromRGB(230, 128, 60),
	},
	{
		Id = "ElectronicParts",
		Name = "Electronic Parts",
		Value = 40,
		Weight = 12,
		Tier = 2,
		Color = Color3.fromRGB(70, 200, 120),
	},
	{
		Id = "RareMechanical",
		Name = "Rare Mechanical Parts",
		Value = 150,
		Weight = 3,
		Tier = 3,
		Color = Color3.fromRGB(170, 100, 255),
	},
} :: { ScrapType }

-- Tools are unlocked in order by the "BetterTools" upgrade (level 0 = first tool).
export type ToolDef = {
	Name: string,
	Yield: number, -- items granted per collection (still capped by free space)
	Luck: number, -- multiplies the odds of rarer scrap
	Color: Color3,
	Material: Enum.Material,
}

Config.Tools = {
	{ Name = "Rusty Grabber", Yield = 1, Luck = 1.0, Color = Color3.fromRGB(140, 90, 60), Material = Enum.Material.CorrodedMetal },
	{ Name = "Steel Grabber", Yield = 1, Luck = 1.4, Color = Color3.fromRGB(170, 175, 185), Material = Enum.Material.Metal },
	{ Name = "Magnet Claw", Yield = 2, Luck = 1.8, Color = Color3.fromRGB(200, 50, 50), Material = Enum.Material.SmoothPlastic },
	{ Name = "Hydraulic Claw", Yield = 2, Luck = 2.4, Color = Color3.fromRGB(255, 190, 40), Material = Enum.Material.DiamondPlate },
	{ Name = "Plasma Extractor", Yield = 3, Luck = 3.2, Color = Color3.fromRGB(80, 220, 255), Material = Enum.Material.Neon },
} :: { ToolDef }

export type UpgradeDef = {
	Id: string,
	Name: string,
	Description: string,
	MaxLevel: number,
	-- Price to go from `level` to `level + 1`.
	Prices: { number },
}

Config.Upgrades = {
	{
		Id = "Capacity",
		Name = "Bigger Backpack",
		Description = "Carry more scrap before you have to sell.",
		MaxLevel = 10,
		Prices = { 40, 90, 175, 300, 500, 800, 1250, 1900, 2800, 4000 },
	},
	{
		Id = "Speed",
		Name = "Collection Speed",
		Description = "Less waiting between grabs.",
		MaxLevel = 10,
		Prices = { 60, 120, 220, 380, 600, 900, 1350, 2000, 2900, 4200 },
	},
	{
		Id = "BetterTools",
		Name = "Better Tools",
		Description = "Grab more scrap per pull and find rarer parts.",
		MaxLevel = #Config.Tools - 1,
		Prices = { 250, 900, 2600, 7500 },
	},
} :: { UpgradeDef }

Config.CapacityPerLevel = 5
Config.CooldownPerLevel = 0.11

-- Built-in Studio content sounds, so nothing depends on external audio uploads.
Config.Sounds = {
	Collect = "rbxasset://sounds/collide.wav",
	Sell = "rbxasset://sounds/electronicpingshort.wav",
	Purchase = "rbxasset://sounds/electronicpingshort.wav",
	Error = "rbxasset://sounds/clickfast.wav",
	Click = "rbxasset://sounds/button.wav",
}

return Config
