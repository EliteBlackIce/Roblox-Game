--!strict
-- Player settings, saved on the server.

local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Windows = require(script.Parent.Parent.Windows)

local C = Theme.Colors

local OPTIONS = {
	{ Key = "Sfx", Name = "Sound Effects", Description = "Collect, sell and purchase sounds." },
	{ Key = "HideBots", Name = "Hide Other Bots", Description = "Only show your own Scrap Bots." },
	{ Key = "LowFx", Name = "Low Effects", Description = "Fewer particles for slower devices." },
}

return function()
	local panel = Windows.create("Settings", "SETTINGS", C.Disabled, Vector2.new(560, 360))
	local list = Theme.scroll(panel.Content)
	local toggles = {}
	for i, option in OPTIONS do
		local row = Theme.create("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = C.PanelLight, Parent = list }, { Theme.corner(10), Theme.stroke(2), Theme.padding(8) })
		Theme.label({ Size = UDim2.new(1, -130, 0.55, 0), Text = option.Name, Font = Theme.TitleFont, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = row })
		Theme.label({ Position = UDim2.fromScale(0, 0.55), Size = UDim2.new(1, -130, 0.45, 0), Text = option.Description, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = row })
		toggles[option.Key] = Theme.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.new(0, 110, 1, 0), Text = "", Parent = row }, function()
			local state = State.current
			if state then
				State.request("SetSetting", option.Key, not state.Settings[option.Key])
			end
		end)
	end
	State.listen(function(state)
		for key, button in toggles do
			local on = state.Settings[key] == true
			button.Text = if on then "ON" else "OFF"
			button.BackgroundColor3 = if on then C.Good else C.Disabled
		end
	end)
end
