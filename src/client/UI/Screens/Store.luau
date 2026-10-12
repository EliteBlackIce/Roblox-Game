--!strict
-- Robux store. Only lists passes/products that have a real Id in Config, and
-- the menu hides the button entirely when there are none.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Windows = require(script.Parent.Parent.Windows)

local C = Theme.Colors

local Store = {}

function Store.hasItems(): boolean
	for _, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			return true
		end
	end
	for _, product in Config.Products do
		if product.Id ~= 0 then
			return true
		end
	end
	return false
end

function Store.init()
	local panel = Windows.create("Store", "STORE", C.Accent, Vector2.new(640, 520))
	local list = Theme.scroll(panel.Content)
	local passButtons = {}
	local order = 0
	for _, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			order += 1
			local row = Theme.create("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = C.PanelLight, Parent = list }, { Theme.corner(10), Theme.stroke(2, C.Accent), Theme.padding(8) })
			Theme.label({ Size = UDim2.new(1, -150, 0.55, 0), Text = pass.Name, Font = Theme.TitleFont, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = row })
			Theme.label({ Position = UDim2.fromScale(0, 0.55), Size = UDim2.new(1, -150, 0.45, 0), Text = pass.Description, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = row })
			passButtons[pass.Key] = Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0, 140, 1, 0), BackgroundColor3 = C.Accent, Text = "Buy", Parent = row }, function()
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.Id)
			end)
		end
	end
	for _, product in Config.Products do
		if product.Id ~= 0 then
			order += 1
			local row = Theme.create("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.PanelLight, Parent = list }, { Theme.corner(10), Theme.stroke(2, C.Gems), Theme.padding(8) })
			Theme.label({ Size = UDim2.new(1, -150, 1, 0), Text = product.Name, Font = Theme.TitleFont, TextColor3 = C.Gems, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = row })
			Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0, 140, 1, 0), BackgroundColor3 = C.Gems, Text = "Buy", Parent = row }, function()
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.Id)
			end)
		end
	end
	State.listen(function(state)
		for key, button in passButtons do
			if state.Passes[key] then
				button.Text = "OWNED"
				button.BackgroundColor3 = C.Disabled
			end
		end
	end)
end

return Store
