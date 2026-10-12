--!strict
-- Quest chain, daily quests and login streak rewards.
--
-- Quest goals read a stat. "Delta" stats count progress made since the quest
-- started (Collected, Hatched, ...). "Absolute" stats read the player's current
-- value (ToolTier, ZonesUnlocked, Rebirths, TotalEarned).

local Quests = {}

export type Reward = { Cash: number?, Gems: number? }
export type Quest = {
	Id: string,
	Text: string,
	Stat: string,
	Goal: number,
	Reward: Reward,
}

Quests.AbsoluteStats = {
	ToolTier = true,
	ZonesUnlocked = true,
	Rebirths = true,
	TotalEarned = true,
}

Quests.Chain = {
	{ Id = "c1", Text = "Collect 10 pieces of scrap", Stat = "Collected", Goal = 10, Reward = { Cash = 50 } },
	{ Id = "c2", Text = "Sell $100 worth of scrap", Stat = "SoldCash", Goal = 100, Reward = { Cash = 100 } },
	{ Id = "c3", Text = "Buy an upgrade at the Upgrade Shop", Stat = "Upgrades", Goal = 1, Reward = { Cash = 150 } },
	{ Id = "c4", Text = "Collect 50 pieces of scrap", Stat = "Collected", Goal = 50, Reward = { Cash = 300 } },
	{ Id = "c5", Text = "Buy the Steel Grabber at the Tool Shop", Stat = "ToolTier", Goal = 2, Reward = { Gems = 25 } },
	{ Id = "c6", Text = "Unlock the Car Graveyard", Stat = "ZonesUnlocked", Goal = 2, Reward = { Cash = 500 } },
	{ Id = "c7", Text = "Find 3 Rare (or better) items", Stat = "RareFinds", Goal = 3, Reward = { Gems = 20 } },
	{ Id = "c8", Text = "Hatch a Scrap Bot from a crate", Stat = "Hatched", Goal = 1, Reward = { Cash = 1500 } },
	{ Id = "c9", Text = "Unlock Appliance Alley", Stat = "ZonesUnlocked", Goal = 3, Reward = { Gems = 40 } },
	{ Id = "c10", Text = "Find an Epic (or better) item", Stat = "EpicFinds", Goal = 1, Reward = { Gems = 30 } },
	{ Id = "c11", Text = "Grab from a Golden Pile", Stat = "GoldenGrabs", Goal = 1, Reward = { Gems = 40 } },
	{ Id = "c12", Text = "Unlock the Electronics Dump", Stat = "ZonesUnlocked", Goal = 4, Reward = { Gems = 60 } },
	{ Id = "c13", Text = "Earn $250,000 in total", Stat = "TotalEarned", Goal = 250000, Reward = { Gems = 75 } },
	{ Id = "c14", Text = "Rebirth for the first time", Stat = "Rebirths", Goal = 1, Reward = { Gems = 150 } },
	{ Id = "c15", Text = "Unlock the Shipyard Wrecks", Stat = "ZonesUnlocked", Goal = 5, Reward = { Gems = 150 } },
	{ Id = "c16", Text = "Reach Rebirth 2", Stat = "Rebirths", Goal = 2, Reward = { Gems = 200 } },
	{ Id = "c17", Text = "Unlock the Crash Site", Stat = "ZonesUnlocked", Goal = 6, Reward = { Gems = 300 } },
	{ Id = "c18", Text = "Find a Mythic item", Stat = "MythicFinds", Goal = 1, Reward = { Gems = 500 } },
} :: { Quest }

Quests.DailyPool = {
	{ Id = "d_collect1", Text = "Collect 150 pieces of scrap", Stat = "Collected", Goal = 150, Reward = { Gems = 15 } },
	{ Id = "d_collect2", Text = "Collect 400 pieces of scrap", Stat = "Collected", Goal = 400, Reward = { Gems = 30 } },
	{ Id = "d_rare", Text = "Find 5 Rare (or better) items", Stat = "RareFinds", Goal = 5, Reward = { Gems = 20 } },
	{ Id = "d_epic", Text = "Find an Epic (or better) item", Stat = "EpicFinds", Goal = 1, Reward = { Gems = 25 } },
	{ Id = "d_sell", Text = "Sell your backpack 5 times", Stat = "SellCount", Goal = 5, Reward = { Gems = 15 } },
	{ Id = "d_hatch", Text = "Hatch 2 Scrap Bots", Stat = "Hatched", Goal = 2, Reward = { Gems = 20 } },
	{ Id = "d_golden", Text = "Grab from 2 Golden Piles", Stat = "GoldenGrabs", Goal = 2, Reward = { Gems = 30 } },
	{ Id = "d_upgrade", Text = "Buy 3 upgrades", Stat = "Upgrades", Goal = 3, Reward = { Gems = 15 } },
} :: { Quest }

Quests.DailyCount = 3
Quests.DailyAllBonus = { Gems = 25 } :: Reward

-- Gems for login streak days 1..7 (the streak loops after day 7).
Quests.LoginRewards = { 10, 15, 20, 30, 40, 60, 100 }

Quests.DailyById = {} :: { [string]: Quest }
for _, quest in Quests.DailyPool do
	Quests.DailyById[quest.Id] = quest
end

-- Deterministic pick of today's quests for a player.
function Quests.pickDaily(day: number, userId: number): { string }
	local rng = Random.new(day * 7919 + userId % 100000)
	local pool = table.clone(Quests.DailyPool)
	local picked = {}
	for _ = 1, Quests.DailyCount do
		local index = rng:NextInteger(1, #pool)
		table.insert(picked, pool[index].Id)
		table.remove(pool, index)
	end
	return picked
end

return Quests
