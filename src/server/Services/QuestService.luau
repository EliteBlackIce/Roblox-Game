--!strict
-- Quest chain, daily quests and the daily login streak. Progress is evaluated
-- from server-side stats whenever a profile changes; rewards are granted
-- automatically (chain) or claimed (dailies, login).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Quests = require(Shared.Quests)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local RequestRouter = require(script.Parent.RequestRouter)
local Stations = require(script.Parent.Stations)

local QuestService = {}

local function today(): number
	return os.time() // 86400
end

local function statValue(profile: DataService.Profile, stat: string): number
	if stat == "ToolTier" then
		return profile.ToolTier
	elseif stat == "ZonesUnlocked" then
		return EconomyService.zonesUnlocked(profile)
	elseif stat == "Rebirths" then
		return profile.Rebirths
	elseif stat == "TotalEarned" then
		return profile.TotalEarned
	end
	return profile.Stats[stat] or 0
end

local function progressOf(profile: DataService.Profile, quest: Quests.Quest, base: number): number
	local value = statValue(profile, quest.Stat)
	if Quests.AbsoluteStats[quest.Stat] then
		return math.min(value, quest.Goal)
	end
	return math.clamp(value - base, 0, quest.Goal)
end

local function giveReward(profile: DataService.Profile, reward: Quests.Reward)
	if reward.Cash then
		DataService.addCash(profile, reward.Cash)
	end
	if reward.Gems then
		profile.Gems += reward.Gems
	end
end

local function rewardText(reward: Quests.Reward): string
	local parts = {}
	if reward.Cash then
		table.insert(parts, Formulas.formatCash(reward.Cash))
	end
	if reward.Gems then
		table.insert(parts, `{reward.Gems} gems`)
	end
	return table.concat(parts, " + ")
end
QuestService.rewardText = rewardText

local function startChainQuest(profile: DataService.Profile)
	local quest = Quests.Chain[profile.Quest.Index]
	profile.Quest.Base = if quest then statValue(profile, quest.Stat) else 0
end

local function rollDailies(player: Player, profile: DataService.Profile)
	local day = today()
	if profile.Daily.Day == day then
		return
	end
	local ids = Quests.pickDaily(day, player.UserId)
	profile.Daily = { Day = day, Ids = ids, Base = {}, Claimed = {}, Bonus = false }
	for i, id in ids do
		profile.Daily.Base[i] = statValue(profile, Quests.DailyById[id].Stat)
		profile.Daily.Claimed[i] = false
	end
end

-- Advances the chain as far as completed quests allow.
local function evaluate(player: Player, profile: DataService.Profile)
	local advanced = false
	for _ = 1, #Quests.Chain do
		local quest = Quests.Chain[profile.Quest.Index]
		if not quest or progressOf(profile, quest, profile.Quest.Base) < quest.Goal then
			break
		end
		giveReward(profile, quest.Reward)
		DataService.notify(player, `Quest complete: {quest.Text}! +{rewardText(quest.Reward)}`, "success")
		profile.Quest.Index += 1
		startChainQuest(profile)
		advanced = true
	end
	if advanced then
		DataService.changed(player)
	end
end

local function claimDaily(player: Player, index: unknown): (boolean, string?)
	local profile = DataService.get(player) :: DataService.Profile
	rollDailies(player, profile)
	if type(index) ~= "number" or not profile.Daily.Ids[index] then
		return false, "Invalid quest."
	end
	local quest = Quests.DailyById[profile.Daily.Ids[index]]
	if profile.Daily.Claimed[index] then
		return false, "Already claimed."
	end
	if progressOf(profile, quest, profile.Daily.Base[index]) < quest.Goal then
		return false, "Not finished yet!"
	end
	profile.Daily.Claimed[index] = true
	giveReward(profile, quest.Reward)
	local message = `+{rewardText(quest.Reward)}`

	local all = true
	for i in profile.Daily.Ids do
		if not profile.Daily.Claimed[i] then
			all = false
		end
	end
	if all and not profile.Daily.Bonus then
		profile.Daily.Bonus = true
		giveReward(profile, Quests.DailyAllBonus)
		message ..= ` and a bonus {rewardText(Quests.DailyAllBonus)} for finishing every daily!`
	end
	DataService.changed(player)
	return true, message
end

local function loginStatus(profile: DataService.Profile): (boolean, number)
	local day = today()
	if profile.Login.LastDay == day then
		return false, profile.Login.Streak
	end
	local streak = if profile.Login.LastDay == day - 1 then profile.Login.Streak + 1 else 1
	return true, streak
end

local function claimLogin(player: Player): (boolean, string?)
	local profile = DataService.get(player) :: DataService.Profile
	local canClaim, streak = loginStatus(profile)
	if not canClaim then
		return false, "Come back tomorrow for your next reward!"
	end
	local gems = Quests.LoginRewards[(streak - 1) % #Quests.LoginRewards + 1]
	profile.Login.LastDay = today()
	profile.Login.Streak = streak
	profile.Gems += gems
	DataService.changed(player)
	return true, `Day {streak} reward: +{gems} gems!`
end

function QuestService.start()
	RequestRouter.register("ClaimDaily", claimDaily)
	RequestRouter.register("ClaimLogin", claimLogin)
	Stations.connectPrompt("QuestBoard", "OpenPrompt", function(player)
		Remotes.event("OpenPanel"):FireClient(player, "Quests")
	end)

	DataService.onLoaded(function(player, profile)
		rollDailies(player, profile)
		if profile.Quest.Base == 0 and profile.Quest.Index == 1 then
			startChainQuest(profile)
		end
		evaluate(player, profile)
	end)
	DataService.onChanged(evaluate)

	DataService.decorate(function(player, profile, state)
		rollDailies(player, profile)
		local quest = Quests.Chain[profile.Quest.Index]
		state.Quest = if quest
			then {
				Index = profile.Quest.Index,
				Total = #Quests.Chain,
				Text = quest.Text,
				Progress = progressOf(profile, quest, profile.Quest.Base),
				Goal = quest.Goal,
				Reward = rewardText(quest.Reward),
			}
			else nil
		local dailies = {}
		for i, id in profile.Daily.Ids do
			local daily = Quests.DailyById[id]
			table.insert(dailies, {
				Text = daily.Text,
				Progress = progressOf(profile, daily, profile.Daily.Base[i]),
				Goal = daily.Goal,
				Reward = rewardText(daily.Reward),
				Claimed = profile.Daily.Claimed[i],
			})
		end
		state.Dailies = dailies
		state.DailyResetIn = (today() + 1) * 86400 - os.time()
		local canClaim, streak = loginStatus(profile)
		state.Login = {
			CanClaim = canClaim,
			Streak = streak,
			Reward = Quests.LoginRewards[(streak - 1) % #Quests.LoginRewards + 1],
		}
	end)
end

return QuestService
