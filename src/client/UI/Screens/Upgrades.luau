--!strict
-- Upgrade Shop window (opened at the shop). Buttons send only the upgrade id.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Windows = require(script.Parent.Parent.Windows)

local C = Theme.Colors

return function()
	local panel = Windows.create("Upgrades", "UPGRADE SHOP", C.Info, Vector2.new(820, 460), "UpgradeShop")
	local grid = Theme.scroll(panel.Content, nil, Vector2.new(184, 300))

	local cards = {}
	for i, upgrade in Upgrades do
		local card = Theme.create("Frame", { Name = upgrade.Id, LayoutOrder = i, BackgroundColor3 = C.PanelLight, Parent = grid }, { Theme.corner(12), Theme.stroke(2), Theme.padding(8) })
		Theme.label({ Size = UDim2.new(1, 0, 0, 26), Text = upgrade.Name, Font = Theme.TitleFont, TextColor3 = C.Accent, MaxTextSize = 22, Parent = card })
		Theme.label({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 40), Text = upgrade.Description, TextWrapped = true, TextColor3 = C.SubText, MaxTextSize = 14, Parent = card })
		local level = Theme.label({ Name = "Level", Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 22), Text = "", MaxTextSize = 18, Parent = card })
		local _, fill = Theme.bar(card, { Position = UDim2.fromOffset(0, 102), Size = UDim2.new(1, 0, 0, 10) }, C.Info)
		local effect = Theme.label({ Name = "Effect", Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 70), Text = "", TextWrapped = true, TextColor3 = C.Cash, MaxTextSize = 16, Parent = card })
		local button = Theme.button({
			Name = "Buy",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 44),
			Text = "Buy",
			Parent = card,
		}, function()
			State.request("BuyUpgrade", upgrade.Id)
		end)
		cards[upgrade.Id] = { level = level, fill = fill, effect = effect, button = button }
	end

	local function render(state: any)
		for _, info in state.Upgrades do
			local card = cards[info.Id]
			local def = Formulas.getUpgrade(info.Id)
			if card and def then
				card.level.Text = `Level {info.Level}/{def.MaxLevel}`
				card.fill.Size = UDim2.fromScale(info.Level / def.MaxLevel, 1)
				local now = Formulas.describeUpgrade(info.Id, info.Level)
				if info.Price then
					card.effect.Text = `{now}\n->\n{Formulas.describeUpgrade(info.Id, info.Level + 1)}`
				else
					card.effect.Text = now
				end
				if not info.Price then
					card.button.Text = "MAXED"
					card.button.BackgroundColor3 = C.Accent
				elseif state.Cash >= info.Price then
					card.button.Text = "Buy " .. Formulas.formatCash(info.Price)
					card.button.BackgroundColor3 = C.Good
				else
					card.button.Text = Formulas.formatCash(info.Price)
					card.button.BackgroundColor3 = C.Disabled
				end
			end
		end
	end
	State.listen(render)
end
