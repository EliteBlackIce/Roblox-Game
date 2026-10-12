--!strict
-- Rebirth window: progress to the next rebirth and the Rebirth Token perk shop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Windows = require(script.Parent.Parent.Windows)

local C = Theme.Colors

return function()
	local panel = Windows.create("Rebirth", "REBIRTH", C.Tokens, Vector2.new(780, 560))
	local content = panel.Content

	local top = Theme.create("Frame", { Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = C.PanelLight, Parent = content }, { Theme.corner(12), Theme.stroke(2, C.Tokens), Theme.padding(10) })
	local headline = Theme.label({ Size = UDim2.new(1, 0, 0, 28), Font = Theme.TitleFont, TextColor3 = C.Tokens, MaxTextSize = 24, Parent = top })
	local detail = Theme.label({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 40), TextWrapped = true, TextColor3 = C.SubText, MaxTextSize = 15, Parent = top })
	local _, fill = Theme.bar(top, { Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 14) }, C.Tokens)
	local armed = false
	local rebirthButton
	rebirthButton = Theme.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0.6, 0, 0, 44),
		BackgroundColor3 = C.Tokens,
		Text = "REBIRTH",
		Parent = top,
	}, function()
		local state = State.current
		if not state or state.Cash < state.RebirthCost then
			State.request("Rebirth") -- server explains what's missing
			return
		end
		if not armed then
			armed = true
			rebirthButton.Text = "Tap again to confirm!"
			task.delay(4, function()
				armed = false
				if State.current then
					rebirthButton.Text = "REBIRTH"
				end
			end)
			return
		end
		armed = false
		State.request("Rebirth")
	end)

	local tokens = Theme.label({ Position = UDim2.fromOffset(0, 158), Size = UDim2.new(1, 0, 0, 26), Font = Theme.TitleFont, TextColor3 = C.Tokens, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = content })
	local list = Theme.scroll(content, { Position = UDim2.fromOffset(0, 190), Size = UDim2.new(1, 0, 1, -190) })

	local perkButtons = {}
	local perkLevels = {}
	for i, perk in Rebirth.Perks do
		local row = Theme.create("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.PanelLight, Parent = list }, { Theme.corner(10), Theme.stroke(2), Theme.padding(8) })
		Theme.label({ Size = UDim2.new(1, -170, 0.5, 0), Text = perk.Name, Font = Theme.TitleFont, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 19, Parent = row })
		perkLevels[perk.Id] = Theme.label({ Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, -170, 0.5, 0), Text = perk.Description, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = row })
		perkButtons[perk.Id] = Theme.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(0, 160, 1, 0),
			BackgroundColor3 = C.Tokens,
			Text = "",
			Parent = row,
		}, function()
			State.request("BuyPerk", perk.Id)
		end)
	end

	State.listen(function(state)
		local nextMult = 1 + (state.Rebirths + 1) * Rebirth.CashBonusPerRebirth
		local tokensGained = Rebirth.tokensFor(state.Rebirths)
		headline.Text = `Rebirth {state.Rebirths} -> {state.Rebirths + 1}`
		detail.Text = `Costs {Formulas.formatCash(state.RebirthCost)}. Resets cash, upgrades, tools and zones. Keeps bots, gems, index and perks. Rebirth bonus becomes x{string.format("%.1f", nextMult)} and you get {tokensGained} token{if tokensGained == 1 then "" else "s"}.`
		fill.Size = UDim2.fromScale(math.clamp(state.Cash / state.RebirthCost, 0, 1), 1)
		if not armed then
			rebirthButton.Text = if state.Cash >= state.RebirthCost then "REBIRTH" else `{Formulas.formatCash(state.Cash)} / {Formulas.formatCash(state.RebirthCost)}`
		end
		rebirthButton.BackgroundColor3 = if state.Cash >= state.RebirthCost then C.Tokens else C.Disabled
		tokens.Text = `Rebirth Tokens: {state.Tokens}`
		for _, perk in Rebirth.Perks do
			local lvl = state.Perks[perk.Id] or 0
			local cost = perk.Costs[lvl + 1]
			local button = perkButtons[perk.Id]
			perkLevels[perk.Id].Text = `{perk.Description}  (Level {lvl}/{#perk.Costs})`
			if not cost then
				button.Text = "MAXED"
				button.BackgroundColor3 = C.Accent
			else
				button.Text = `{cost} Token{if cost == 1 then "" else "s"}`
				button.BackgroundColor3 = if state.Tokens >= cost then C.Tokens else C.Disabled
			end
		end
	end)
end
