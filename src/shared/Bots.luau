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
	Style: string, -- "Walker" | "Flyer"
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

-- Style decides how a follower moves: "Walker" hops behind you, "Flyer" floats.
Bots.List = {
	-- Rusty Crate
	{ Id = "BoltBot", Name = "Bolt Bot", Rarity = "Common", Cash = 0.05, Luck = 0, Style = "Walker", Body = rgb(236, 128, 72), Trim = rgb(255, 226, 170) },
	{ Id = "TinDrone", Name = "Tin Drone", Rarity = "Common", Cash = 0, Luck = 0.05, Style = "Flyer", Body = rgb(200, 210, 226), Trim = rgb(235, 80, 80) },
	{ Id = "SparkBug", Name = "Spark Bug", Rarity = "Uncommon", Cash = 0.1, Luck = 0.03, Style = "Walker", Body = rgb(255, 214, 64), Trim = rgb(52, 50, 70) },
	{ Id = "CoilCrawler", Name = "Coil Crawler", Rarity = "Rare", Cash = 0.2, Luck = 0.05, Style = "Walker", Body = rgb(122, 214, 120), Trim = rgb(255, 160, 80) },
	{ Id = "GearGolem", Name = "Gear Golem", Rarity = "Epic", Cash = 0.4, Luck = 0.1, Style = "Walker", Body = rgb(140, 150, 178), Trim = rgb(255, 184, 64) },
	{ Id = "TrashKing", Name = "Trash King", Rarity = "Secret", Cash = 8, Luck = 1, Style = "Walker", Body = rgb(150, 150, 168), Trim = rgb(255, 205, 60) },
	-- Chrome Crate
	{ Id = "ChromePup", Name = "Chrome Pup", Rarity = "Uncommon", Cash = 0.15, Luck = 0.05, Style = "Walker", Body = rgb(222, 232, 248), Trim = rgb(90, 170, 255) },
	{ Id = "MagnetMite", Name = "Magnet Mite", Rarity = "Rare", Cash = 0.25, Luck = 0.1, Style = "Walker", Body = rgb(240, 74, 84), Trim = rgb(225, 232, 245) },
	{ Id = "TurboTank", Name = "Turbo Tank", Rarity = "Epic", Cash = 0.6, Luck = 0.1, Style = "Walker", Body = rgb(110, 190, 120), Trim = rgb(255, 214, 80) },
	{ Id = "NeonOwl", Name = "Neon Owl", Rarity = "Legendary", Cash = 1.0, Luck = 0.2, Style = "Flyer", Body = rgb(80, 210, 214), Trim = rgb(255, 110, 210) },
	{ Id = "PrismPhoenix", Name = "Prism Phoenix", Rarity = "Secret", Cash = 10, Luck = 1.2, Style = "Flyer", Body = rgb(255, 120, 90), Trim = rgb(255, 230, 110) },
	-- Galaxy Crate
	{ Id = "PlasmaPup", Name = "Plasma Pup", Rarity = "Rare", Cash = 0.4, Luck = 0.15, Style = "Walker", Body = rgb(120, 110, 230), Trim = rgb(110, 240, 255) },
	{ Id = "RocketRaptor", Name = "Rocket Raptor", Rarity = "Epic", Cash = 0.9, Luck = 0.2, Style = "Walker", Body = rgb(236, 92, 92), Trim = rgb(255, 214, 90) },
	{ Id = "StarSentinel", Name = "Star Sentinel", Rarity = "Legendary", Cash = 1.75, Luck = 0.3, Style = "Flyer", Body = rgb(255, 214, 80), Trim = rgb(90, 80, 200) },
	{ Id = "CosmicCore", Name = "Cosmic Core", Rarity = "Mythic", Cash = 4.0, Luck = 0.5, Style = "Flyer", Body = rgb(250, 245, 255), Trim = rgb(255, 90, 170) },
	{ Id = "NebulaWhale", Name = "Nebula Whale", Rarity = "Secret", Cash = 14, Luck = 1.5, Style = "Flyer", Body = rgb(70, 60, 160), Trim = rgb(255, 130, 220) },
	-- Gem Crate
	{ Id = "GemBeetle", Name = "Gem Beetle", Rarity = "Rare", Cash = 0.3, Luck = 0.15, Style = "Walker", Body = rgb(70, 220, 150), Trim = rgb(40, 120, 90) },
	{ Id = "CrystalCat", Name = "Crystal Cat", Rarity = "Epic", Cash = 0.7, Luck = 0.2, Style = "Walker", Body = rgb(190, 225, 255), Trim = rgb(150, 120, 255) },
	{ Id = "DiamondDragon", Name = "Diamond Dragon", Rarity = "Legendary", Cash = 1.5, Luck = 0.4, Style = "Flyer", Body = rgb(130, 230, 255), Trim = rgb(60, 110, 200) },
	{ Id = "KaleidoKitty", Name = "Kaleido Kitty", Rarity = "Secret", Cash = 9, Luck = 1.6, Style = "Walker", Body = rgb(255, 245, 250), Trim = rgb(255, 120, 200) },
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
			{ Bot = "TrashKing", Weight = 0.02 },
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
			{ Bot = "PrismPhoenix", Weight = 0.02 },
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
			{ Bot = "NebulaWhale", Weight = 0.02 },
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
			{ Bot = "KaleidoKitty", Weight = 0.03 },
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
