--!strict
-- Fast travel to the Hub and any unlocked zone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Zones = require(ReplicatedStorage.Shared.Zones)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Windows = require(script.Parent.Parent.Windows)

local C = Theme.Colors

return function()
	local panel = Windows.create("Teleport", "TELEPORT", C.Info, Vector2.new(560, 560))
	local list = Theme.scroll(panel.Content)

	local destinations = { { Id = "Hub", Name = "The Hub", Color = C.Accent, Zone = nil :: Zones.Zone? } }
	for _, zone in Zones.List do
		table.insert(destinations, { Id = zone.Id, Name = zone.Name, Color = zone.Theme.Accent, Zone = zone })
	end

	local buttons = {}
	for i, dest in destinations do
		local row = Theme.create("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = C.PanelLight, Parent = list }, { Theme.corner(10), Theme.stroke(2, dest.Color), Theme.padding(8) })
		Theme.label({ Size = UDim2.new(1, -170, 1, 0), Text = dest.Name, Font = Theme.TitleFont, TextColor3 = dest.Color, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = row })
		buttons[dest.Id] = Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0, 160, 1, 0), Text = "Go", Parent = row }, function()
			local state = State.current
			if state and (dest.Id == "Hub" or state.Zones[dest.Id]) then
				local ok = State.request("Teleport", dest.Id)
				if ok then
					Windows.close()
				end
			end
		end)
	end

	State.listen(function(state)
		for _, dest in destinations do
			local button = buttons[dest.Id]
			if dest.Id == "Hub" or state.Zones[dest.Id] then
				button.Text = "Go"
				button.BackgroundColor3 = C.Good
			else
				local zone = dest.Zone :: Zones.Zone
				button.Text = if zone.RebirthsRequired > state.Rebirths then `Rebirth {zone.RebirthsRequired}` else `Locked {Formulas.formatCash(zone.Price)}`
				button.BackgroundColor3 = C.Disabled
			end
		end
	end)
end
