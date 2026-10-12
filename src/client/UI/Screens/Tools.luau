--!strict
-- Tool Shop window: every tool in order, buy the next one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local ToolArt = require(ReplicatedStorage.Shared.Art.ToolArt)
local Tools = require(ReplicatedStorage.Shared.Tools)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Viewport = require(script.Parent.Parent.Viewport)
local Windows = require(script.Parent.Parent.Windows)

local C = Theme.Colors

return function()
	local panel = Windows.create("Tools", "TOOL SHOP", C.Orange, Vector2.new(720, 520), "ToolShop")
	local list = Theme.scroll(panel.Content)

	local rows = {}
	for tier, tool in Tools do
		local row = Theme.create("Frame", { Name = "Tool" .. tier, LayoutOrder = tier, Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = C.PanelLight, Parent = list }, { Theme.corner(12), Theme.stroke(2), Theme.padding(8) })
		local holder = Theme.create("Frame", { Size = UDim2.new(0, 110, 1, 0), BackgroundColor3 = C.Panel, Parent = row }, { Theme.corner(10) })
		Viewport.new(holder, ToolArt.build(tier), nil, { Yaw = 90, Pitch = 20, Zoom = 1.2 })
		Theme.label({ Position = UDim2.fromOffset(122, 0), Size = UDim2.new(0.5, -122, 0.55, 0), Text = tool.Name, Font = Theme.TitleFont, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = row })
		Theme.label({
			Position = UDim2.new(0, 122, 0.55, 0),
			Size = UDim2.new(0.55, -122, 0.45, 0),
			Text = `Grabs x{tool.Yield}  •  Luck x{string.format("%.1f", tool.Luck)}`,
			TextColor3 = C.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 15,
			Parent = row,
		})
		local button = Theme.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(0.34, 0, 1, 0),
			Text = "",
			Parent = row,
		}, function()
			-- Only the next tool in line can be bought.
			if State.current and State.current.ToolTier + 1 == tier then
				State.request("BuyTool")
			end
		end)
		rows[tier] = button
	end

	State.listen(function(state)
		for tier, button in rows do
			local tool = Tools[tier]
			if tier <= state.ToolTier then
				button.Text = if tier == state.ToolTier then "EQUIPPED" else "OWNED"
				button.BackgroundColor3 = if tier == state.ToolTier then C.Accent else C.Disabled
				button.Active = false
			elseif tier == state.ToolTier + 1 then
				button.Text = "Buy " .. Formulas.formatCash(tool.Price)
				button.BackgroundColor3 = if state.Cash >= tool.Price then C.Good else C.Disabled
				button.Active = true
			else
				button.Text = "Locked " .. Formulas.formatCash(tool.Price)
				button.BackgroundColor3 = C.PanelDark
				button.Active = false
			end
		end
	end)
end
