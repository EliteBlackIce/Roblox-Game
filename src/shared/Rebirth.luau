--!strict
-- Rebirth resets cash, upgrades, tools and zones in exchange for a permanent
-- sell multiplier and Rebirth Tokens to spend on perks that survive every reset.

local Rebirth = {}

Rebirth.BaseCost = 400000
Rebirth.CostGrowth = 3.0
Rebirth.CashBonusPerRebirth = 0.5 -- +50% sell value per rebirth

export type Perk = {
	Id: string,
	Name: string,
	Description: string,
	Costs: { number }, -- token cost for each level
}

Rebirth.Perks = {
	{
		Id = "BotSlot",
		Name = "Extra Bot Slot",
		Description = "+1 Scrap Bot slot per level.",
		Costs = { 1, 2, 4 },
	},
	{
		Id = "LuckyCharm",
		Name = "Lucky Charm",
		Description = "+10% luck per level.",
		Costs = { 1, 1, 2, 2, 3 },
	},
	{
		Id = "HeadStart",
		Name = "Head Start",
		Description = "Start each rebirth with bonus cash.",
		Costs = { 1, 2, 3, 4 },
	},
	{
		Id = "RemoteSell",
		Name = "Remote Sell",
		Description = "Sell your backpack from anywhere with a button.",
		Costs = { 2 },
	},
	{
		Id = "AutoCollect",
		Name = "Auto Grabber",
		Description = "Automatically grab from piles you stand next to.",
		Costs = { 3 },
	},
	{
		Id = "KeepTools",
		Name = "Tool Insurance",
		Description = "Keep your tool when you rebirth.",
		Costs = { 4 },
	},
} :: { Perk }

Rebirth.HeadStartCash = { 2500, 25000, 150000, 1000000 }

Rebirth.PerkById = {} :: { [string]: Perk }
for _, perk in Rebirth.Perks do
	Rebirth.PerkById[perk.Id] = perk
end

function Rebirth.cost(rebirths: number): number
	return math.floor(Rebirth.BaseCost * Rebirth.CostGrowth ^ rebirths)
end

-- Tokens granted for performing rebirth number `rebirths + 1`.
function Rebirth.tokensFor(rebirths: number): number
	return 1 + math.floor((rebirths + 1) / 3)
end

return Rebirth
