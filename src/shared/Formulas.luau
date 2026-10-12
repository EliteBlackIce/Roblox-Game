--!strict
-- Pure functions that turn upgrade levels into gameplay stats. Shared so the
-- client can display the same numbers the server enforces.

local Config = require(script.Parent.Config)

local Formulas = {}

export type Levels = { [string]: number }

function Formulas.getCapacity(levels: Levels): number
	return Config.Gameplay.BaseCapacity + (levels.Capacity or 0) * Config.CapacityPerLevel
end

function Formulas.getCooldown(levels: Levels): number
	local cooldown = Config.Gameplay.BaseCooldown - (levels.Speed or 0) * Config.CooldownPerLevel
	return math.max(Config.Gameplay.MinCooldown, cooldown)
end

function Formulas.getTool(levels: Levels): Config.ToolDef
	local index = math.clamp((levels.BetterTools or 0) + 1, 1, #Config.Tools)
	return Config.Tools[index]
end

function Formulas.getUpgrade(id: string): Config.UpgradeDef?
	for _, upgrade in Config.Upgrades do
		if upgrade.Id == id then
			return upgrade
		end
	end
	return nil
end

-- Returns nil when the upgrade is maxed out.
function Formulas.getUpgradePrice(id: string, currentLevel: number): number?
	local upgrade = Formulas.getUpgrade(id)
	if not upgrade or currentLevel >= upgrade.MaxLevel then
		return nil
	end
	return upgrade.Prices[currentLevel + 1]
end

-- Human-readable effect of an upgrade at a given level.
function Formulas.describeEffect(id: string, level: number): string
	local levels = { [id] = level }
	if id == "Capacity" then
		return `{Formulas.getCapacity(levels)} slots`
	elseif id == "Speed" then
		return string.format("%.2fs cooldown", Formulas.getCooldown(levels))
	elseif id == "BetterTools" then
		local tool = Formulas.getTool(levels)
		return `{tool.Name} (x{tool.Yield}, {string.format("%.1f", tool.Luck)} luck)`
	end
	return ""
end

function Formulas.getScrapType(id: string): Config.ScrapType?
	for _, scrap in Config.ScrapTypes do
		if scrap.Id == id then
			return scrap
		end
	end
	return nil
end

-- Weighted random pick. Luck boosts each type's weight in proportion to its tier,
-- so commons stay common while rare parts become noticeably easier to find.
function Formulas.rollScrap(rng: Random, luck: number): Config.ScrapType
	local total = 0
	local weights = table.create(#Config.ScrapTypes)
	for i, scrap in Config.ScrapTypes do
		local weight = scrap.Weight * (1 + (luck - 1) * scrap.Tier)
		weights[i] = weight
		total += weight
	end

	local roll = rng:NextNumber() * total
	for i, scrap in Config.ScrapTypes do
		roll -= weights[i]
		if roll <= 0 then
			return scrap
		end
	end
	return Config.ScrapTypes[1]
end

function Formulas.formatCash(amount: number): string
	local formatted = tostring(math.floor(amount))
	local k
	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return "$" .. formatted
end

return Formulas
