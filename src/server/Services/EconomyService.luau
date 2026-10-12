--!strict
-- Selling and upgrade purchases. The client only ever sends an upgrade id; prices,
-- cash, inventory and effects are all looked up and changed here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local ToolService = require(script.Parent.ToolService)

local EconomyService = {}

local lastPurchase: { [Player]: number } = {}

local function distanceTo(player: Player, part: BasePart): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return math.huge
	end
	return (root.Position - part.Position).Magnitude
end

local function nearTagged(player: Player, tag: string, range: number): boolean
	for _, station in CollectionService:GetTagged(tag) do
		local anchor = station:FindFirstChild("PromptAnchor")
		if anchor and anchor:IsA("BasePart") and distanceTo(player, anchor) <= range then
			return true
		end
	end
	return false
end

local function sell(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	if not nearTagged(player, "SellStation", Config.Gameplay.SellRange) then
		return
	end

	local total = 0
	local count = 0
	local breakdown = {}
	for _, scrap in Config.ScrapTypes do
		local amount = profile.Inventory[scrap.Id] or 0
		if amount > 0 then
			local earned = amount * scrap.Value
			total += earned
			count += amount
			table.insert(breakdown, { Id = scrap.Id, Count = amount, Earned = earned })
		end
		profile.Inventory[scrap.Id] = 0
	end

	if count == 0 then
		Remotes.event("Notify"):FireClient(player, "Nothing to sell! Collect scrap from the piles first.", "error")
		return
	end

	profile.Cash += total
	profile.TotalEarned += total
	Remotes.event("Sold"):FireClient(player, total, count, breakdown)
	DataService.changed(player)
end

local function purchase(player: Player, upgradeId: unknown): (boolean, string)
	local now = os.clock()
	if lastPurchase[player] and now - lastPurchase[player] < Config.Gameplay.PurchaseThrottle then
		return false, "Slow down!"
	end
	lastPurchase[player] = now

	if type(upgradeId) ~= "string" then
		return false, "Invalid upgrade."
	end
	local upgrade = Formulas.getUpgrade(upgradeId)
	local profile = DataService.get(player)
	if not upgrade or not profile then
		return false, "Invalid upgrade."
	end
	if not nearTagged(player, "UpgradeShop", Config.Gameplay.ShopRange) then
		return false, "Walk back to the Upgrade Shop to buy."
	end

	local level = profile.Levels[upgrade.Id]
	local price = Formulas.getUpgradePrice(upgrade.Id, level)
	if not price then
		return false, `{upgrade.Name} is already maxed out!`
	end
	if profile.Cash < price then
		return false, `You need {Formulas.formatCash(price - profile.Cash)} more.`
	end

	profile.Cash -= price
	profile.Levels[upgrade.Id] = level + 1

	if upgrade.Id == "BetterTools" then
		ToolService.refresh(player)
	end
	DataService.changed(player)
	return true, `{upgrade.Name} upgraded to level {level + 1}!`
end

local function connectPrompt(tag: string, promptName: string, handler: (Player) -> ())
	local function register(station: Instance)
		local anchor = station:FindFirstChild("PromptAnchor")
		local prompt = anchor and anchor:FindFirstChild(promptName)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(handler)
		else
			warn(`[EconomyService] {tag} missing PromptAnchor/{promptName}:`, station:GetFullName())
		end
	end
	for _, station in CollectionService:GetTagged(tag) do
		register(station)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(register)
end

function EconomyService.start()
	connectPrompt("SellStation", "SellPrompt", sell)
	connectPrompt("UpgradeShop", "ShopPrompt", function(player)
		Remotes.event("OpenShop"):FireClient(player)
	end)

	Remotes.func("PurchaseUpgrade").OnServerInvoke = purchase

	Players.PlayerRemoving:Connect(function(player)
		lastPurchase[player] = nil
	end)
end

return EconomyService
