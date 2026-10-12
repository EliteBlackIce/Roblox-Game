--!strict
-- Collection book: every item per zone shown as a 3D model (a black silhouette
-- until discovered). Completing a zone's set gives +5% cash, each Mythic +10%.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Art.Items)
local Zones = require(ReplicatedStorage.Shared.Zones)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Viewport = require(script.Parent.Parent.Viewport)
local Windows = require(script.Parent.Parent.Windows)

local C = Theme.Colors

type Cell = { Frame: Frame, Known: boolean?, View: ViewportFrame?, Name: TextLabel, Value: TextLabel, Stroke: UIStroke }

return function()
	local panel = Windows.create("Index", "SCRAP INDEX", C.Good, Vector2.new(880, 580))
	local summary = Theme.label({ Size = UDim2.new(1, 0, 0, 26), Text = "", TextColor3 = C.Cash, MaxTextSize = 18, Parent = panel.Content })
	local list = Theme.scroll(panel.Content, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32) })

	local cells: { [string]: Cell } = {}
	local headers: { [string]: TextLabel } = {}
	local built = false

	local function build()
		built = true
		for order, zone in Zones.List do
			local section = Theme.create("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 176), BackgroundColor3 = C.PanelLight, Parent = list }, {
				Theme.corner(14),
				Theme.stroke(3, zone.Theme.Accent),
				Theme.padding(8),
			})
			headers[zone.Id] = Theme.label({ Size = UDim2.new(1, 0, 0, 24), Text = zone.Name, Font = Theme.TitleFont, TextColor3 = zone.Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = section })
			local row = Theme.create("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30), BackgroundTransparency = 1, Parent = section }, {
				Theme.create("UIGridLayout", { CellSize = UDim2.new(1 / 7, -6, 1, 0), CellPadding = UDim2.fromOffset(6, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			for i, item in zone.Items do
				local rarity = Config.RarityById[item.Rarity]
				local stroke = Theme.stroke(3, C.Stroke)
				local cell = Theme.create("Frame", { LayoutOrder = i, BackgroundColor3 = C.Panel, Parent = row }, {
					Theme.corner(12),
					stroke,
					Theme.create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 205)) }),
				})
				local name = Theme.label({ Position = UDim2.new(0, 2, 1, -44), Size = UDim2.new(1, -4, 0, 26), Text = "???", TextWrapped = true, Font = Theme.TitleFont, MaxTextSize = 13, Parent = cell })
				Theme.textStroke().Parent = name
				local value = Theme.label({ Position = UDim2.new(0, 2, 1, -18), Size = UDim2.new(1, -4, 0, 16), Text = rarity.Name, TextColor3 = rarity.Color, Font = Theme.TitleFont, MaxTextSize = 12, Parent = cell })
				Theme.textStroke().Parent = value
				cells[item.Id] = { Frame = cell, Known = nil, View = nil, Name = name, Value = value, Stroke = stroke }
			end
		end
	end

	local function render(state: any)
		if not built then
			build()
		end
		local found, total = 0, 0
		for _, zone in Zones.List do
			local count = 0
			for _, item in zone.Items do
				total += 1
				local known = state.Discovered[item.Id] == true
				local cell = cells[item.Id]
				if known then
					found += 1
					if item.Rarity ~= "Mythic" then
						count += 1
					end
				end
				if cell.Known ~= known then
					cell.Known = known
					if cell.View then
						cell.View:Destroy()
					end
					local rarity = Config.RarityById[item.Rarity]
					cell.View = Viewport.new(cell.Frame, Items.build(item.Id), { Size = UDim2.new(1, 0, 1, -40) }, { Silhouette = not known, Yaw = 30, Pitch = 20 })
					cell.Name.Text = if known then item.Name else "???"
					cell.Value.Text = if known then `{rarity.Name} • {Formulas.formatCash(item.Value)}` else rarity.Name
					cell.Stroke.Color = if known then rarity.Color else C.Stroke
				end
			end
			local complete = count >= #zone.Items - 1
			headers[zone.Id].Text = `{zone.Name}  •  {count}/{#zone.Items - 1}{if complete then "  COMPLETE (+5% cash)" else ""}`
			headers[zone.Id].TextColor3 = if complete then C.Accent else zone.Theme.Accent
		end
		summary.Text = `Discovered {found}/{total} items  •  Index cash bonus x{string.format("%.2f", Formulas.indexBonus(state))}`
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
