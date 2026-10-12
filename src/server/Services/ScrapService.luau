--!strict
-- Scrap piles: server-validated collection, weighted loot rolls per zone, golden
-- piles, depletion/respawn and the Auto Grabber perk.
-- Piles are Models tagged "ScrapPile" with a "ZoneId" attribute and a
-- "PromptAnchor" part holding a "CollectPrompt".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)
local DataService = require(script.Parent.DataService)
local Stations = require(script.Parent.Stations)
local ToolService = require(script.Parent.ToolService)

local ScrapService = {}

local PILE_TAG = "ScrapPile"
local GOLD = Color3.fromRGB(255, 205, 50)
local rng = Random.new()
local lastCollect: { [Player]: number } = {}
local lastWarning: { [Player]: { [string]: number } } = {}
local piles: { Model } = {}

local function warnOnce(player: Player, key: string, message: string)
	-- Throttle repeated warnings so holding the prompt does not spam toasts.
	local now = os.clock()
	local seen = lastWarning[player]
	if not seen then
		seen = {}
		lastWarning[player] = seen
	end
	if seen[key] and now - seen[key] < 2 then
		return
	end
	seen[key] = now
	DataService.notify(player, message, "error")
end

local function getPrompt(pile: Model): ProximityPrompt?
	local anchor = Stations.anchor(pile)
	local prompt = anchor and anchor:FindFirstChild("CollectPrompt")
	return if prompt and prompt:IsA("ProximityPrompt") then prompt else nil
end

local function updatePromptText(pile: Model)
	local prompt = getPrompt(pile)
	if prompt then
		local charges = pile:GetAttribute("Charges") or 0
		local zone = Zones.ById[pile:GetAttribute("ZoneId") or ""]
		local name = if zone then zone.Name else "Scrap Pile"
		if pile:GetAttribute("Golden") then
			prompt.ObjectText = `GOLDEN PILE • {charges} left`
			prompt.ActionText = "Grab Gold!"
		else
			prompt.ObjectText = `{name} • {charges} left`
			prompt.ActionText = "Collect"
		end
	end
end

local function junkParts(pile: Model): { BasePart }
	local parts = {}
	for _, part in pile:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "PromptAnchor" and not part:GetAttribute("Persistent") then
			table.insert(parts, part)
		end
	end
	return parts
end

local function setVisible(pile: Model, visible: boolean)
	local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, part in junkParts(pile) do
		local original = part:GetAttribute("OriginalTransparency")
		if original == nil then
			original = part.Transparency
			part:SetAttribute("OriginalTransparency", original)
		end
		part.CanCollide = visible and part:GetAttribute("OriginalCollide") == true
		TweenService:Create(part, info, { Transparency = if visible then original else 1 }):Play()
	end
end

local function setGoldenLook(pile: Model, golden: boolean)
	for _, part in junkParts(pile) do
		if part:GetAttribute("BaseColor") == nil then
			part:SetAttribute("BaseColor", part.Color)
			part:SetAttribute("BaseMaterial", part.Material.Name)
		end
		if golden then
			part.Color = GOLD
			part.Material = Enum.Material.Neon
		else
			part.Color = part:GetAttribute("BaseColor") :: Color3
			part.Material = (Enum.Material :: any)[part:GetAttribute("BaseMaterial")] or Enum.Material.SmoothPlastic
		end
	end
end

local function refill(pile: Model)
	pile:SetAttribute("Charges", rng:NextInteger(Config.ScrapPiles.MinCharges, Config.ScrapPiles.MaxCharges))
	pile:SetAttribute("Active", true)
	setVisible(pile, true)
	local prompt = getPrompt(pile)
	if prompt then
		prompt.Enabled = true
	end
	updatePromptText(pile)
end

function ScrapService.clearGolden(pile: Model)
	if pile:GetAttribute("Golden") then
		pile:SetAttribute("Golden", false)
		setGoldenLook(pile, false)
		updatePromptText(pile)
	end
end

local function deplete(pile: Model)
	pile:SetAttribute("Active", false)
	ScrapService.clearGolden(pile)
	local prompt = getPrompt(pile)
	if prompt then
		prompt.Enabled = false
	end
	setVisible(pile, false)
	task.delay(Config.ScrapPiles.RespawnTime, refill, pile)
end

-- Turns a pile golden until it is emptied or `duration` passes.
function ScrapService.makeGolden(pile: Model, duration: number)
	if pile:GetAttribute("Active") ~= true then
		refill(pile)
	end
	pile:SetAttribute("Golden", true)
	pile:SetAttribute("Charges", Config.ScrapPiles.MaxCharges + 2)
	setGoldenLook(pile, true)
	updatePromptText(pile)
	local token = (pile:GetAttribute("GoldenToken") or 0) + 1
	pile:SetAttribute("GoldenToken", token)
	task.delay(duration, function()
		if pile:GetAttribute("GoldenToken") == token then
			ScrapService.clearGolden(pile)
		end
	end)
end

function ScrapService.getPiles(): { Model }
	return piles
end

-- Core collection. Returns true when something was granted.
local function collect(player: Player, pile: Model, auto: boolean): boolean
	local profile = DataService.get(player)
	if not profile or pile:GetAttribute("Active") ~= true then
		return false
	end
	local charges = pile:GetAttribute("Charges")
	if type(charges) ~= "number" or charges <= 0 then
		return false
	end

	local root = Stations.root(player)
	local anchor = Stations.anchor(pile)
	if not root or not anchor then
		return false
	end
	if (root.Position - anchor.Position).Magnitude > Config.Gameplay.CollectRange then
		return false
	end

	local zone = Zones.ById[pile:GetAttribute("ZoneId") or ""]
	if not zone or not profile.Zones[zone.Id] then
		if not auto then
			warnOnce(player, "zone", "You haven't unlocked this zone yet!")
		end
		return false
	end

	if not auto and not ToolService.isHoldingTool(player) then
		warnOnce(player, "tool", "Equip your grabber first! (press 1)")
		return false
	end

	local ctx = DataService.context(player)
	local now = os.clock()
	local cooldown = Formulas.getCooldown(profile, ctx)
	if lastCollect[player] and now - lastCollect[player] < cooldown - Config.Gameplay.CooldownTolerance then
		return false
	end

	local free = Formulas.getCapacity(profile, ctx) - DataService.getUsedSlots(profile)
	if free <= 0 then
		if not auto then
			warnOnce(player, "full", "Backpack full! Sell your scrap at a SELL pad.")
		end
		return false
	end

	lastCollect[player] = now
	local golden = pile:GetAttribute("Golden") == true
	local tool = Formulas.getTool(profile)
	local luck = Formulas.getLuck(profile, ctx) * (if golden then Config.Events.GoldenLuck else 1)
	local amount = math.min(tool.Yield, free)

	local items = {}
	local discovered = {}
	local gems = 0
	for _ = 1, amount do
		local item = Formulas.rollItem(rng, zone, luck, golden)
		local tier = Config.RarityById[item.Rarity].Tier
		profile.Inventory[item.Id] = (profile.Inventory[item.Id] or 0) + 1
		table.insert(items, item.Id)
		if not profile.Discovered[item.Id] then
			profile.Discovered[item.Id] = true
			table.insert(discovered, item.Id)
		end
		if tier >= 2 then
			DataService.addStat(profile, "RareFinds", 1)
		end
		if tier >= 3 then
			DataService.addStat(profile, "EpicFinds", 1)
			gems += Config.Gameplay.GemChanceOnEpic
		end
		if tier >= 5 then
			DataService.addStat(profile, "MythicFinds", 1)
		end
		if Config.RarityById[item.Rarity].Announce then
			Remotes.event("Announce"):FireAllClients(`{player.DisplayName} found a {item.Rarity} {item.Name}!`, item.Rarity)
		end
	end
	DataService.addStat(profile, "Collected", amount)
	if golden then
		DataService.addStat(profile, "GoldenGrabs", 1)
		gems += Config.Events.GoldenGems
	end
	profile.Gems += gems

	pile:SetAttribute("Charges", charges - 1)
	updatePromptText(pile)
	if charges - 1 <= 0 then
		deplete(pile)
	end

	Remotes.event("Collected"):FireClient(player, items, anchor.Position, {
		Golden = golden,
		Gems = gems,
		New = discovered,
	})
	DataService.changed(player)
	return true
end
ScrapService.collect = collect

local function registerPile(pile: Instance)
	if not pile:IsA("Model") then
		return
	end
	local prompt = getPrompt(pile)
	if not prompt then
		warn("[ScrapService] Scrap pile missing PromptAnchor/CollectPrompt:", pile:GetFullName())
		return
	end
	for _, part in pile:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("OriginalCollide") == nil then
			part:SetAttribute("OriginalCollide", part.CanCollide)
		end
	end
	prompt.Triggered:Connect(function(player)
		collect(player, pile, false)
	end)
	table.insert(piles, pile)
	refill(pile)
end

-- Auto Grabber perk: grab from the nearest pile in range on every cooldown.
local function autoCollectLoop()
	while true do
		task.wait(Config.Gameplay.AutoCollectInterval)
		for player, profile in DataService.all() do
			if (profile.Perks.AutoCollect or 0) > 0 then
				local root = Stations.root(player)
				if root then
					local best, bestDistance = nil, Config.Gameplay.CollectRange
					for _, pile in piles do
						if pile:GetAttribute("Active") == true and profile.Zones[pile:GetAttribute("ZoneId") or ""] then
							local anchor = Stations.anchor(pile)
							if anchor then
								local distance = (anchor.Position - root.Position).Magnitude
								if distance <= bestDistance then
									best, bestDistance = pile, distance
								end
							end
						end
					end
					if best then
						collect(player, best, true)
					end
				end
			end
		end
	end
end

function ScrapService.start()
	for _, pile in CollectionService:GetTagged(PILE_TAG) do
		registerPile(pile)
	end
	CollectionService:GetInstanceAddedSignal(PILE_TAG):Connect(registerPile)

	Players.PlayerRemoving:Connect(function(player)
		lastCollect[player] = nil
		lastWarning[player] = nil
	end)
	task.spawn(autoCollectLoop)
end

return ScrapService
