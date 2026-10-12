--!strict
-- Game passes and developer products. Everything with an Id of 0 in Config is
-- disabled, so the game works without any monetization set up.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BotService = require(script.Parent.BotService)
local DataService = require(script.Parent.DataService)
local ToolService = require(script.Parent.ToolService)

local MonetizationService = {}

local function refreshPasses(player: Player)
	local owned = DataService.passes[player] or {}
	DataService.passes[player] = owned
	for _, pass in Config.GamePasses do
		if pass.Id ~= 0 and not owned[pass.Key] then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and has then
				owned[pass.Key] = true
			end
		end
	end
	player:SetAttribute("VIP", owned.VIP == true)
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and DataService.get(player)
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(profile.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = nil
	for _, candidate in Config.Products do
		if candidate.Id ~= 0 and candidate.Id == receipt.ProductId then
			product = candidate
		end
	end
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	profile.Gems += product.Gems
	table.insert(profile.Receipts, purchaseId)
	while #profile.Receipts > 50 do
		table.remove(profile.Receipts, 1)
	end
	-- Save right away so a crash can't lose a paid purchase.
	DataService.save(player)
	DataService.notify(player, `Thanks for your purchase! +{product.Gems} gems`, "success")
	DataService.changed(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.start()
	DataService.onLoaded(function(player)
		refreshPasses(player)
		BotService.syncAttribute(player)
		DataService.changed(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			refreshPasses(player)
			for _, pass in Config.GamePasses do
				if pass.Id == passId then
					DataService.notify(player, `Thanks for buying {pass.Name}!`, "success")
				end
			end
			ToolService.refresh(player)
			DataService.changed(player)
		end
	end)

	local anyProducts = false
	for _, product in Config.Products do
		if product.Id ~= 0 then
			anyProducts = true
		end
	end
	if anyProducts then
		MarketplaceService.ProcessReceipt = processReceipt
	end
end

MonetizationService.processReceipt = processReceipt

return MonetizationService
