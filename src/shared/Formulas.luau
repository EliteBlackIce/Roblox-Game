--!strict
-- Pure functions that turn a player's profile into gameplay numbers. Shared so the
-- client can display exactly what the server enforces.

local Bots = require(script.Parent.Bots)
local Config = require(script.Parent.Config)
local Rebirth = require(script.Parent.Rebirth)
local Tools = require(script.Parent.Tools)
local Upgrades = require(script.Parent.Upgrades)
local Zones = require(script.Parent.Zones)

local Formulas = {}

-- Everything outside the saved profile that changes a player's numbers.
export type Context = {
	Now: number, -- os.time()
	Frenzy: boolean,
	Passes: { [string]: boolean },
}

local function level(profile: any, id: string): number
	return profile.Levels[id] or 0
end

local function perk(profile: any, id: string): number
	return profile.Perks[id] or 0
end

function Formulas.boostActive(profile: any, id: string, now: number): boolean
	local expires = profile.Boosts[id]
	return expires ~= nil and expires > now
end

---------------------------------------------------------------- upgrades

function Formulas.getUpgrade(id: string): Upgrades.Upgrade?
	for _, upgrade in Upgrades do
		if upgrade.Id == id then
			return upgrade
		end
	end
	return nil
end

-- Price of the next level, or nil when maxed out.
function Formulas.upgradePrice(id: string, currentLevel: number): number?
	local upgrade = Formulas.getUpgrade(id)
	if not upgrade or currentLevel >= upgrade.MaxLevel then
		return nil
	end
	return math.floor(upgrade.Base * upgrade.Growth ^ currentLevel)
end

function Formulas.capacityFor(backpackLevel: number, bigBackpack: boolean): number
	local base = Config.Gameplay.BaseCapacity + backpackLevel * 5
	return if bigBackpack then math.floor(base * 1.5) else base
end

function Formulas.cooldownFor(speedLevel: number): number
	return math.max(Config.Gameplay.MinCooldown, Config.Gameplay.BaseCooldown - speedLevel * 0.075)
end

function Formulas.walkSpeedFor(sneakersLevel: number): number
	return Config.Gameplay.BaseWalkSpeed + sneakersLevel * 1.6
end

function Formulas.luckLevelBonus(luckLevel: number): number
	return 1 + luckLevel * 0.08
end

function Formulas.describeUpgrade(id: string, lvl: number): string
	if id == "Backpack" then
		return `{Formulas.capacityFor(lvl, false)} slots`
	elseif id == "Speed" then
		return string.format("%.2fs per grab", Formulas.cooldownFor(lvl))
	elseif id == "Luck" then
		return string.format("x%.2f luck", Formulas.luckLevelBonus(lvl))
	elseif id == "Sneakers" then
		return string.format("%.1f walk speed", Formulas.walkSpeedFor(lvl))
	end
	return ""
end

---------------------------------------------------------------- stats

function Formulas.getTool(profile: any): Tools.Tool
	return Tools[math.clamp(profile.ToolTier, 1, #Tools)]
end

function Formulas.getCapacity(profile: any, ctx: Context): number
	return Formulas.capacityFor(level(profile, "Backpack"), ctx.Passes.BigBackpack == true)
end

function Formulas.getCooldown(profile: any, ctx: Context): number
	local cooldown = Formulas.cooldownFor(level(profile, "Speed"))
	if Formulas.boostActive(profile, "Speed", ctx.Now) then
		cooldown *= 0.6
	end
	if ctx.Frenzy then
		cooldown *= Config.Events.FrenzyCooldownMultiplier
	end
	return math.max(0.25, cooldown)
end

function Formulas.getWalkSpeed(profile: any): number
	return Formulas.walkSpeedFor(level(profile, "Sneakers"))
end

function Formulas.botSlots(profile: any, ctx: Context): number
	return Bots.BaseSlots + perk(profile, "BotSlot") + (if ctx.Passes.ExtraBots then 2 else 0)
end

-- Summed bonuses of equipped bots.
function Formulas.botBonuses(profile: any): (number, number)
	local cash, luck = 0, 0
	local equipped = {}
	for _, uid in profile.Equipped do
		equipped[uid] = true
	end
	for _, owned in profile.Bots do
		if equipped[owned.Uid] then
			local bot = Bots.ById[owned.Id]
			if bot then
				local mult = if owned.Golden then Bots.GoldenMultiplier else 1
				cash += bot.Cash * mult
				luck += bot.Luck * mult
			end
		end
	end
	return cash, luck
end

-- Number of zones whose six regular items have all been discovered.
function Formulas.completedSets(profile: any): number
	local count = 0
	for _, zone in Zones.List do
		local complete = true
		for _, item in zone.Items do
			if item.Rarity ~= "Mythic" and not profile.Discovered[item.Id] then
				complete = false
				break
			end
		end
		if complete then
			count += 1
		end
	end
	return count
end

function Formulas.mythicsFound(profile: any): number
	local count = 0
	for _, zone in Zones.List do
		for _, item in zone.Items do
			if item.Rarity == "Mythic" and profile.Discovered[item.Id] then
				count += 1
			end
		end
	end
	return count
end

function Formulas.indexBonus(profile: any): number
	return 1 + Formulas.completedSets(profile) * 0.05 + Formulas.mythicsFound(profile) * 0.1
end

function Formulas.getLuck(profile: any, ctx: Context): number
	local _, botLuck = Formulas.botBonuses(profile)
	local luck = Formulas.getTool(profile).Luck
		* Formulas.luckLevelBonus(level(profile, "Luck"))
		* (1 + perk(profile, "LuckyCharm") * 0.1)
		* (1 + botLuck)
	if Formulas.boostActive(profile, "Luck", ctx.Now) then
		luck *= 2
	end
	if ctx.Passes.VIP then
		luck *= 1.25
	end
	return luck
end

function Formulas.getCashMultiplier(profile: any, ctx: Context): number
	local botCash = Formulas.botBonuses(profile)
	local mult = (1 + profile.Rebirths * Rebirth.CashBonusPerRebirth) * (1 + botCash) * Formulas.indexBonus(profile)
	if Formulas.boostActive(profile, "Cash", ctx.Now) then
		mult *= 2
	end
	if ctx.Frenzy then
		mult *= Config.Events.FrenzyCashMultiplier
	end
	if ctx.Passes.DoubleCash then
		mult *= 2
	end
	if ctx.Passes.VIP then
		mult *= 1.25
	end
	return mult
end

-- Raw (unmultiplied) value of everything in the backpack.
function Formulas.inventoryValue(inventory: { [string]: number }): number
	local total = 0
	for id, count in inventory do
		local item = Zones.Items[id]
		if item then
			total += item.Value * count
		end
	end
	return total
end

---------------------------------------------------------------- loot

-- Weighted roll from a zone's table. Luck boosts each item's weight in
-- proportion to its rarity tier, so commons stay common while rares become
-- noticeably easier to find. Golden piles skip Common/Uncommon and can roll the
-- zone's Mythic.
function Formulas.rollItem(rng: Random, zone: Zones.Zone, luck: number, golden: boolean): Zones.Item
	if golden then
		for _, item in zone.Items do
			if item.Rarity == "Mythic" and rng:NextNumber() < Config.Events.GoldenMythicChance then
				return item
			end
		end
	end

	local total = 0
	local weights = {}
	for i, item in zone.Items do
		local tier = Config.RarityById[item.Rarity].Tier
		local weight = 0
		if tier < 5 and not (golden and tier < 2) then
			weight = item.Weight * (1 + (luck - 1) * tier)
		end
		weights[i] = weight
		total += weight
	end

	local roll = rng:NextNumber() * total
	for i, item in zone.Items do
		roll -= weights[i]
		if weights[i] > 0 and roll <= 0 then
			return item
		end
	end
	return zone.Items[1]
end

function Formulas.rollBot(rng: Random, crate: Bots.Crate): Bots.Bot
	local total = 0
	for _, drop in crate.Drops do
		total += drop.Weight
	end
	local roll = rng:NextNumber() * total
	for _, drop in crate.Drops do
		roll -= drop.Weight
		if roll <= 0 then
			return Bots.ById[drop.Bot]
		end
	end
	return Bots.ById[crate.Drops[1].Bot]
end

---------------------------------------------------------------- formatting

local SUFFIXES = { "", "K", "M", "B", "T", "Qd", "Qn" }

-- 950 -> "950", 12500 -> "12.5K", 3400000 -> "3.4M"
function Formulas.formatNumber(amount: number): string
	amount = math.floor(amount)
	if math.abs(amount) < 10000 then
		local formatted = tostring(amount)
		local k
		repeat
			formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		until k == 0
		return formatted
	end
	local index = 1
	local value = amount
	while math.abs(value) >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text = if math.abs(value) >= 100 then string.format("%d", math.floor(value)) else string.format("%.3g", value)
	return text .. SUFFIXES[index]
end

function Formulas.formatCash(amount: number): string
	return "$" .. Formulas.formatNumber(amount)
end

function Formulas.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Formulas
