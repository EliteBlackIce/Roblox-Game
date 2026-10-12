--!strict
-- Window framework: every menu panel is a centred window; only one is open at a
-- time. Station panels (shops) close automatically when you walk away.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Theme)

local Windows = {}

export type Panel = {
	Name: string,
	Window: Frame,
	Content: Frame,
	Station: string?, -- tag the player must stay near, if any
	OnOpen: (() -> ())?,
}

local registry: { [string]: Panel } = {}
local openName: string? = nil
local screen: ScreenGui
local openedCallbacks: { (string?) -> () } = {}

function Windows.init(gui: ScreenGui)
	screen = gui
	task.spawn(function()
		while true do
			task.wait(0.5)
			local panel = openName and registry[openName]
			if panel and panel.Station then
				local character = Players.LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local near = false
				if root and root:IsA("BasePart") then
					for _, station in CollectionService:GetTagged(panel.Station) do
						local anchor = station:FindFirstChild("PromptAnchor")
						if anchor and anchor:IsA("BasePart") and (anchor.Position - root.Position).Magnitude < Config.Gameplay.StationRange + 8 then
							near = true
						end
					end
				end
				if not near then
					Windows.close()
				end
			end
		end
	end)
end

-- Creates a window and returns its content frame.
function Windows.create(name: string, title: string, color: Color3, size: Vector2?, station: string?): Panel
	local window = Theme.create("Frame", {
		Name = name .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.66),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		ZIndex = 5,
		Parent = screen,
	}, {
		Theme.corner(18),
		Theme.stroke(5),
		Theme.padding(14),
		Theme.gloss(0.15),
		Theme.create("UISizeConstraint", { MinSize = Vector2.new(330, 300), MaxSize = size or Vector2.new(820, 520) }),
		Theme.create("UIScale", { Name = "PopScale" }),
	})

	local header = Theme.create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = color,
		Parent = window,
	}, { Theme.corner(12), Theme.stroke(3), Theme.gloss(0.3) })
	local titleLabel = Theme.label({
		Name = "Title",
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -70, 1, 0),
		Text = title,
		Font = Theme.TitleFont,
		TextColor3 = Theme.Colors.OnColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 32,
		Parent = header,
	})
	Theme.textStroke().Parent = titleLabel
	Theme.button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Theme.Colors.Bad,
		Text = "X",
		Parent = header,
	}, function()
		Windows.close()
	end)

	local content = Theme.create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 1, -60),
		BackgroundTransparency = 1,
		Parent = window,
	})

	local panel: Panel = { Name = name, Window = window, Content = content, Station = station, OnOpen = nil }
	registry[name] = panel
	return panel
end

function Windows.open(name: string)
	local panel = registry[name]
	if not panel then
		return
	end
	if openName and openName ~= name and registry[openName] then
		registry[openName].Window.Visible = false
	end
	openName = name
	panel.Window.Visible = true
	local scale = panel.Window:FindFirstChild("PopScale") :: UIScale
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if panel.OnOpen then
		panel.OnOpen()
	end
	for _, fn in openedCallbacks do
		fn(name)
	end
end

function Windows.toggle(name: string)
	if openName == name then
		Windows.close()
	else
		Windows.open(name)
	end
end

function Windows.close()
	if openName and registry[openName] then
		registry[openName].Window.Visible = false
	end
	openName = nil
	for _, fn in openedCallbacks do
		fn(nil)
	end
end

function Windows.isOpen(name: string): boolean
	return openName == name
end

function Windows.onChanged(fn: (string?) -> ())
	table.insert(openedCallbacks, fn)
end

return Windows
