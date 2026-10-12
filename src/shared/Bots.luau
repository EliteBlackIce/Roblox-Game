--!strict
-- Scrap Bots: pets hatched from crates. Each bot adds to your cash and luck
-- multipliers while equipped. Five copies of a bot merge into a Golden bot.

local Bots = {}

export type Bot = {
	Id: string,
	Name: string,
	Rarity: string,
	Cash: number, -- +X sell value (0.1 = +10%)
	Luck: number, -- +X luck
	Style: string, -- "Cube" | "Drone" | "Crawler" | "Orb", picks the low-poly model
	Body: Color3,
	Trim: Color3,
}

export type Crate = {
	Id: string,
	Name: string,
	Currency: string, -- "Cash" | "Gems"
	Price: number,
	Color: Color3,
	Drops: { { Bot: string, Weight: number } },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Bots.GoldenMultiplier = 2.5 -- golden bots have their bonuses multiplied by this
Bots.MergeCount = 5
Bots.BaseSlots = 3
Bots.MaxInventory = 60

Bots.List = {
	-- Rusty Crate
	{ Id = "BoltBot", Name = "Bolt Bot", Rarity = "Common", Cash = 0.05, Luck = 0, Style = "Cube", Body = rgb(170, 110, 70), Trim = rgb(220, 220, 220) },
	{ Id = "TinDrone", Name = "Tin Drone", Rarity = "Common", Cash = 0, Luck = 0.05, Style = "Drone", Body = rgb(190, 195, 205), Trim = rgb(80, 160, 255) },
	{ Id = "SparkBug", Name = "Spark Bug", Rarity = "Uncommon", Cash = 0.1, Luck = 0.03, Style = "Crawler", Body = rgb(250, 210, 60), Trim = rgb(60, 60, 60) },
	{ Id = "CoilCrawler", Name = "Coil Crawler", Rarity = "Rare", Cash = 0.2, Luck = 0.05, Style = "Crawler", Body = rgb(230, 130, 60), Trim = rgb(255, 230, 120) },
	{ Id = "GearGolem", Name = "Gear Golem", Rarity = "Epic", Cash = 0.4, Luck = 0.1, Style = "Cube", Body = rgb(120, 120, 135), Trim = rgb(255, 170, 40) },
	-- Chrome Crate
	{ Id = "ChromePup", Name = "Chrome Pup", Rarity = "Uncommon", Cash = 0.15, Luck = 0.05, Style = "Crawler", Body = rgb(215, 225, 240), Trim = rgb(80, 200, 255) },
	{ Id = "MagnetMite", Name = "Magnet Mite", Rarity = "Rare", Cash = 0.25, Luck = 0.1, Style = "Drone", Body = rgb(230, 60, 60), Trim = rgb(220, 220, 230) },
	{ Id = "TurboTank", Name = "Turbo Tank", Rarity = "Epic", Cash = 0.6, Luck = 0.1, Style = "Cube", Body = rgb(70, 120, 70), Trim = rgb(250, 210, 60) },
	{ Id = "NeonOwl", Name = "Neon Owl", Rarity = "Legendary", Cash = 1.0, Luck = 0.2, Style = "Orb", Body = rgb(60, 220, 200), Trim = rgb(255, 80, 200) },
	-- Galaxy Crate
	{ Id = "PlasmaPup", Name = "Plasma Pup", Rarity = "Rare", Cash = 0.4, Luck = 0.15, Style = "Crawler", Body = rgb(80, 220, 255), Trim = rgb(255, 255, 255) },
	{ Id = "RocketRaptor", Name = "Rocket Raptor", Rarity = "Epic", Cash = 0.9, Luck = 0.2, Style = "Drone", Body = rgb(230, 70, 70), Trim = rgb(250, 200, 60) },
	{ Id = "StarSentinel", Name = "Star Sentinel", Rarity = "Legendary", Cash = 1.75, Luck = 0.3, Style = "Orb", Body = rgb(40, 40, 80), Trim = rgb(255, 230, 90) },
	{ Id = "CosmicCore", Name = "Cosmic Core", Rarity = "Mythic", Cash = 4.0, Luck = 0.5, Style = "Orb", Body = rgb(255, 255, 255), Trim = rgb(255, 70, 130) },
	-- Gem Crate
	{ Id = "GemBeetle", Name = "Gem Beetle", Rarity = "Rare", Cash = 0.3, Luck = 0.15, Style = "Crawler", Body = rgb(80, 230, 140), Trim = rgb(40, 120, 70) },
	{ Id = "CrystalCat", Name = "Crystal Cat", Rarity = "Epic", Cash = 0.7, Luck = 0.2, Style = "Cube", Body = rgb(170, 220, 255), Trim = rgb(255, 255, 255) },
	{ Id = "DiamondDragon", Name = "Diamond Dragon", Rarity = "Legendary", Cash = 1.5, Luck = 0.4, Style = "Drone", Body = rgb(120, 240, 255), Trim = rgb(30, 80, 160) },
} :: { Bot }

Bots.Crates = {
	{
		Id = "Rusty",
		Name = "Rusty Crate",
		Currency = "Cash",
		Price = 1000,
		Color = rgb(190, 110, 60),
		Drops = {
			{ Bot = "BoltBot", Weight = 40 },
			{ Bot = "TinDrone", Weight = 35 },
			{ Bot = "SparkBug", Weight = 17 },
			{ Bot = "CoilCrawler", Weight = 7 },
			{ Bot = "GearGolem", Weight = 1 },
		},
	},
	{
		Id = "Chrome",
		Name = "Chrome Crate",
		Currency = "Cash",
		Price = 100000,
		Color = rgb(200, 215, 235),
		Drops = {
			{ Bot = "ChromePup", Weight = 55 },
			{ Bot = "MagnetMite", Weight = 32 },
			{ Bot = "TurboTank", Weight = 12 },
			{ Bot = "NeonOwl", Weight = 1 },
		},
	},
	{
		Id = "Galaxy",
		Name = "Galaxy Crate",
		Currency = "Cash",
		Price = 10000000,
		Color = rgb(110, 60, 200),
		Drops = {
			{ Bot = "PlasmaPup", Weight = 60 },
			{ Bot = "RocketRaptor", Weight = 32 },
			{ Bot = "StarSentinel", Weight = 7.5 },
			{ Bot = "CosmicCore", Weight = 0.5 },
		},
	},
	{
		Id = "Gem",
		Name = "Gem Crate",
		Currency = "Gems",
		Price = 150,
		Color = rgb(60, 220, 140),
		Drops = {
			{ Bot = "GemBeetle", Weight = 70 },
			{ Bot = "CrystalCat", Weight = 26 },
			{ Bot = "DiamondDragon", Weight = 4 },
		},
	},
} :: { Crate }

Bots.ById = {} :: { [string]: Bot }
for _, bot in Bots.List do
	Bots.ById[bot.Id] = bot
end
Bots.CrateById = {} :: { [string]: Crate }
for _, crate in Bots.Crates do
	Bots.CrateById[crate.Id] = crate
end

return Bots
