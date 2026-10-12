--!strict
-- Promo codes. The list lives on the server so exploiters cannot read it.
-- Add new codes here for updates and milestones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local DataService = require(script.Parent.DataService)
local RequestRouter = require(script.Parent.RequestRouter)

local CodeService = {}

type CodeReward = { Cash: number?, Gems: number?, Boost: string?, BoostSeconds: number?, Expires: number? }

local CODES: { [string]: CodeReward } = {
	RELEASE = { Cash = 500, Gems = 20 },
	JUNKYARD = { Gems = 50 },
	SCRAPPY = { Boost = "Cash", BoostSeconds = 900 },
	LUCKYDAY = { Boost = "Luck", BoostSeconds = 900 },
	THANKYOU = { Gems = 25 },
}

local function redeem(player: Player, raw: unknown): (boolean, string?)
	if type(raw) ~= "string" or #raw > 30 then
		return false, "Invalid code."
	end
	local code = string.upper((raw:gsub("%s", "")))
	local reward = CODES[code]
	if not reward or (reward.Expires and os.time() > reward.Expires) then
		return false, "That code doesn't exist or has expired."
	end
	local profile = DataService.get(player) :: DataService.Profile
	if profile.Codes[code] then
		return false, "You already used that code."
	end
	profile.Codes[code] = true

	local parts = {}
	if reward.Cash then
		DataService.addCash(profile, reward.Cash)
		table.insert(parts, Formulas.formatCash(reward.Cash))
	end
	if reward.Gems then
		profile.Gems += reward.Gems
		table.insert(parts, `{reward.Gems} gems`)
	end
	if reward.Boost and reward.BoostSeconds then
		local now = os.time()
		profile.Boosts[reward.Boost] = math.max(profile.Boosts[reward.Boost] or 0, now) + reward.BoostSeconds
		table.insert(parts, `{reward.BoostSeconds // 60} min x2 {reward.Boost}`)
	end
	DataService.changed(player)
	return true, `Code redeemed! +{table.concat(parts, " + ")}`
end

function CodeService.start()
	RequestRouter.register("RedeemCode", redeem)
end

return CodeService
