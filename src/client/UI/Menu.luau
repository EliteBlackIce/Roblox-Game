--!strict
-- Left-side menu buttons that open the windows, with "!" badges when something
-- is ready to claim.

local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local Viewport = require(script.Parent.Viewport)
local Windows = require(script.Parent.Windows)
local Art = game:GetService("ReplicatedStorage").Shared.Art

local C = Theme.Colors

local Menu = {}

-- Each button shows a 3D icon: { art module, model id }.
local ENTRIES = {
	{ Panel = "Bots", Label = "Bots", Color = C.Purple, Icon = { "BotArt", "TinDrone" } },
	{ Panel = "Quests", Label = "Quests", Color = C.Accent, Icon = { "Items", "SunkenTreasure" } },
	{ Panel = "Index", Label = "Index", Color = C.Good, Icon = { "Items", "GoldenRobotHead" } },
	{ Panel = "Rebirth", Label = "Rebirth", Color = C.Tokens, Icon = { "Items", "CosmicShard" } },
	{ Panel = "Boosts", Label = "Boosts", Color = C.Gems, Icon = { "Items", "OldBattery" } },
	{ Panel = "Teleport", Label = "Teleport", Color = C.Info, Icon = { "Items", "SatelliteDish" } },
	{ Panel = "Codes", Label = "Codes", Color = Color3.fromRGB(80, 200, 160), Icon = { "Items", "CircuitBoard" } },
	{ Panel = "Settings", Label = "Settings", Color = C.Disabled, Icon = { "Items", "AncientGear" } },
	{ Panel = "Store", Label = "Store", Color = C.Orange, Icon = { "Items", "GoldenToaster" } },
}

function Menu.init(screen: ScreenGui, showStore: boolean)
	local frame = Theme.create("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.66, 0),
		Size = UDim2.fromOffset(152, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Theme.create("UIGridLayout", { CellSize = UDim2.fromOffset(72, 72), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local badges: { [string]: Frame } = {}
	for i, entry in ENTRIES do
		if entry.Panel ~= "Store" or showStore then
			local button = Theme.button({
				Name = entry.Panel .. "Button",
				LayoutOrder = i,
				BackgroundColor3 = entry.Color,
				Text = "",
				Parent = frame,
			}, function()
				Windows.toggle(entry.Panel)
			end)
			local icon = (require(Art:FindFirstChild(entry.Icon[1]) :: ModuleScript) :: any).build(entry.Icon[2])
			Viewport.new(button, icon, { Size = UDim2.new(1, 0, 1, -16), Active = false }, { Yaw = 30, Pitch = 18, Zoom = 1.15 })
			local label = Theme.label({
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 18),
				Text = entry.Label,
				Font = Theme.TitleFont,
				MaxTextSize = 15,
				Parent = button,
			})
			Theme.textStroke().Parent = label
			badges[entry.Panel] = Theme.create("Frame", {
				Name = "Badge",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = C.Bad,
				Visible = false,
				ZIndex = 3,
				Parent = button,
			}, { Theme.corner(10), Theme.stroke(2), Theme.label({ Size = UDim2.fromScale(1, 1), Text = "!", Font = Theme.TitleFont, ZIndex = 3, MaxTextSize = 16 }) })
		end
	end

	State.listen(function(state)
		local questReady = state.Login.CanClaim
		for _, daily in state.Dailies do
			if daily.Progress >= daily.Goal and not daily.Claimed then
				questReady = true
			end
		end
		badges.Quests.Visible = questReady
		badges.Rebirth.Visible = state.Cash >= state.RebirthCost
	end)
end

return Menu
