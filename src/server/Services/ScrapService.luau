--!strict
-- Scrap piles: server-validated collection, weighted loot rolls, depletion and respawn.
-- Piles are any Model tagged "ScrapPile" with a "PromptAnchor" part inside.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local ToolService = require(script.Parent.ToolService)

local ScrapService = {}

local PILE_TAG = "ScrapPile"
local rng = Random.new()
local lastCollect: { [Player]: number } = {}
local lastWarning: { [Player]: number } = {}

local notifyRemote: RemoteEvent
local collectedRemote: RemoteEvent

local function notify(player: Player, message: string, kind: string)
	-- Throttle repeated warnings so holding the prompt does not spam toasts.
	local now = os.clock()
	if kind == "error" and lastWarning[player] and now - lastWarning[player] < 1.5 then
		return
	end
	if kind == "error" then
		lastWarning[player] = now
	end
	notifyRemote:FireClient(player, message, kind)
end

local function getAnchor(pile: Model): BasePart?
	local anchor = pile:FindFirstChild("PromptAnchor")
	return if anchor and anchor:IsA("BasePart") then anchor else nil
end

local function getPrompt(pile: Model): ProximityPrompt?
	local anchor = getAnchor(pile)
	local prompt = anchor and anchor:FindFirstChild("CollectPrompt")
	return if prompt and prompt:IsA("ProximityPrompt") then prompt else nil
end

local function updatePromptText(pile: Model)
	local prompt = getPrompt(pile)
	if prompt then
		local charges = pile:GetAttribute("Charges") or 0
		local zone = pile:GetAttribute("ZoneName") or "Scrap Pile"
		prompt.ObjectText = `{zone} • {charges} left`
	end
end

local function setVisible(pile: Model, visible: boolean)
	local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, part in pile:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "PromptAnchor" and not part:GetAttribute("Persistent") then
			local original = part:GetAttribute("OriginalTransparency")
			if original == nil then
				original = part.Transparency
				part:SetAttribute("OriginalTransparency", original)
			end
			part.CanCollide = visible and part:GetAttribute("OriginalCollide") ~= false
			TweenService:Create(part, info, { Transparency = if visible then original else 1 }):Play()
		end
	end
end

local function refill(pile: Model)
	local charges = rng:NextInteger(Config.ScrapPiles.MinCharges, Config.ScrapPiles.MaxCharges)
	pile:SetAttribute("Charges", charges)
	pile:SetAttribute("Active", true)
	setVisible(pile, true)
	local prompt = getPrompt(pile)
	if prompt then
		prompt.Enabled = true
	end
	updatePromptText(pile)
end

local function deplete(pile: Model)
	pile:SetAttribute("Active", false)
	local prompt = getPrompt(pile)
	if prompt then
		prompt.Enabled = false
	end
	setVisible(pile, false)
	task.delay(Config.ScrapPiles.RespawnTime, refill, pile)
end

local function collect(player: Player, pile: Model)
	local profile = DataService.get(player)
	if not profile or pile:GetAttribute("Active") ~= true then
		return
	end
	local charges = pile:GetAttribute("Charges")
	if type(charges) ~= "number" or charges <= 0 then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local anchor = getAnchor(pile)
	if not root or not root:IsA("BasePart") or not anchor then
		return
	end
	if (root.Position - anchor.Position).Magnitude > Config.Gameplay.CollectRange then
		return
	end

	if not ToolService.isHoldingTool(player) then
		notify(player, "Equip your grabber first! (press 1)", "error")
		return
	end

	local now = os.clock()
	local cooldown = Formulas.getCooldown(profile.Levels)
	if lastCollect[player] and now - lastCollect[player] < cooldown - Config.Gameplay.CooldownTolerance then
		return
	end

	local free = Formulas.getCapacity(profile.Levels) - DataService.getUsedSlots(profile)
	if free <= 0 then
		notify(player, "Backpack full! Sell your scrap at the SELL station.", "error")
		return
	end

	lastCollect[player] = now
	local tool = Formulas.getTool(profile.Levels)
	local luck = tool.Luck * (pile:GetAttribute("ZoneLuck") or 1)
	local amount = math.min(tool.Yield, free)

	local items = {}
	for _ = 1, amount do
		local scrap = Formulas.rollScrap(rng, luck)
		profile.Inventory[scrap.Id] += 1
		table.insert(items, scrap.Id)
	end

	pile:SetAttribute("Charges", charges - 1)
	updatePromptText(pile)
	if charges - 1 <= 0 then
		deplete(pile)
	end

	collectedRemote:FireClient(player, items, anchor.Position)
	DataService.changed(player)
end

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
		if part:IsA("BasePart") then
			part:SetAttribute("OriginalCollide", part.CanCollide)
		end
	end
	prompt.Triggered:Connect(function(player)
		collect(player, pile)
	end)
	refill(pile)
end

function ScrapService.start()
	notifyRemote = Remotes.event("Notify")
	collectedRemote = Remotes.event("Collected")

	for _, pile in CollectionService:GetTagged(PILE_TAG) do
		registerPile(pile)
	end
	CollectionService:GetInstanceAddedSignal(PILE_TAG):Connect(registerPile)

	Players.PlayerRemoving:Connect(function(player)
		lastCollect[player] = nil
		lastWarning[player] = nil
	end)
end

return ScrapService
