--!strict
-- Cash upgrades bought at the Upgrade Shop. Price for the next level is
-- floor(Base * Growth ^ level).

export type Upgrade = {
	Id: string,
	Name: string,
	Description: string,
	MaxLevel: number,
	Base: number,
	Growth: number,
}

local Upgrades: { Upgrade } = {
	{
		Id = "Backpack",
		Name = "Bigger Backpack",
		Description = "+5 backpack slots per level.",
		MaxLevel = 40,
		Base = 40,
		Growth = 1.42,
	},
	{
		Id = "Speed",
		Name = "Quick Hands",
		Description = "Less waiting between grabs.",
		MaxLevel = 15,
		Base = 60,
		Growth = 1.75,
	},
	{
		Id = "Luck",
		Name = "Lucky Gloves",
		Description = "+8% luck per level for rarer finds.",
		MaxLevel = 25,
		Base = 100,
		Growth = 1.6,
	},
	{
		Id = "Sneakers",
		Name = "Speedy Sneakers",
		Description = "Run faster around the yard.",
		MaxLevel = 10,
		Base = 80,
		Growth = 2.1,
	},
}

return Upgrades
