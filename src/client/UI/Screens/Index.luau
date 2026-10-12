--!strict
-- Collection book: every item per zone. Completing a zone's set gives +5% cash,
-- each Mythic found gives +10%.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Zones = require(ReplicatedStorage.Shared.Zones)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Windows = require(script.Parent.Parent.Windows)

local C = Theme.Colors

return function()
	local panel = Windows.create("Index", "SCRAP INDEX", C.Good, Vector2.new(860, 560))
	local summary = Theme.label({ Size = UDim2.new(1, 0, 0, 26), Text = "", TextColor3 = C.Cash, MaxTextSize = 18, Parent = panel.Content })
	local list = Theme.scroll(panel.Content, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32) })

	local function render(state: any)
		Theme.clear(list)
		local found, total = 0, 0
		for order, zone in Zones.List do
			local count = 0
			for _, item in zone.Items do
				total += 1
				if state.Discovered[item.Id] then
					found += 1
					if item.Rarity ~= "Mythic" then
						count += 1
					end
				end
			end
			local section = Theme.create("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = C.PanelLight, Parent = list }, { Theme.corner(12), Theme.stroke(2, zone.Theme.Accent), Theme.padding(8) })
			local complete = count >= #zone.Items - 1
			Theme.label({
				Size = UDim2.new(1, 0, 0, 24),
				Text = `{zone.Name}  •  {count}/{#zone.Items - 1}{if complete then "  COMPLETE (+5% cash)" else ""}`,
				Font = Theme.TitleFont,
				TextColor3 = if complete then C.Accent else zone.Theme.Accent,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 20,
				Parent = section,
			})
			local row = Theme.create("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30), BackgroundTransparency = 1, Parent = section }, {
				Theme.create("UIGridLayout", { CellSize = UDim2.new(1 / 7, -6, 1, 0), CellPadding = UDim2.fromOffset(6, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			for i, item in zone.Items do
				local rarity = Config.RarityById[item.Rarity]
				local known = state.Discovered[item.Id] == true
				local cell = Theme.create("Frame", { LayoutOrder = i, BackgroundColor3 = C.Panel, Parent = row }, { Theme.corner(10), Theme.stroke(2, if known then rarity.Color else C.Stroke) })
				Theme.create("Frame", { Size = UDim2.fromOffset(28, 28), Position = UDim2.new(0.5, -14, 0, 6), Rotation = 45, BackgroundColor3 = if known then item.Color else C.PanelDark, Parent = cell }, { Theme.corner(6), Theme.stroke(2) })
				Theme.label({ Position = UDim2.fromOffset(2, 42), Size = UDim2.new(1, -4, 0, 30), Text = if known then item.Name else "???", TextWrapped = true, MaxTextSize = 13, Parent = cell })
				Theme.label({ Position = UDim2.fromOffset(2, 74), Size = UDim2.new(1, -4, 0, 14), Text = rarity.Name, TextColor3 = rarity.Color, MaxTextSize = 12, Parent = cell })
				Theme.label({ Position = UDim2.fromOffset(2, 90), Size = UDim2.new(1, -4, 0, 14), Text = if known then Formulas.formatCash(item.Value) else "", TextColor3 = C.Cash, MaxTextSize = 12, Parent = cell })
			end
		end
		local bonus = 1
		for _, zone in Zones.List do
			local complete = true
			for _, item in zone.Items do
				if item.Rarity ~= "Mythic" and not state.Discovered[item.Id] then
					complete = false
				end
			end
			if complete then
				bonus += 0.05
			end
			for _, item in zone.Items do
				if item.Rarity == "Mythic" and state.Discovered[item.Id] then
					bonus += 0.1
				end
			end
		end
		summary.Text = `Discovered {found}/{total} items  •  Index cash bonus x{string.format("%.2f", bonus)}`
	end
	State.listen(function(state)
		if Windows.isOpen("Index") then
			render(state)
		end
	end)
	panel.OnOpen = function()
		if State.current then
			render(State.current)
		end
	end
end
