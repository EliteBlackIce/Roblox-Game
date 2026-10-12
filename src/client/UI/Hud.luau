--!strict
-- Always-on HUD: cash, backpack capacity, carried scrap breakdown and a context hint.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Theme = require(script.Parent.Theme)

local Hud = {}
Hud.__index = Hud

export type Hud = typeof(setmetatable(
	{} :: {
		cashLabel: TextLabel,
		capacityLabel: TextLabel,
		capacityFill: Frame,
		toolLabel: TextLabel,
		rows: { [string]: TextLabel },
		hint: TextLabel,
		shownCash: number,
		cashTween: Tween?,
		cashValue: NumberValue,
	},
	Hud
))

function Hud.new(screen: ScreenGui): Hud
	local C = Theme.Colors

	local panel = Theme.create("Frame", {
		Name = "StatsPanel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(230, 260),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		Parent = screen,
	}, { Theme.corner(14), Theme.stroke(3), Theme.padding(12) })

	local cashLabel = Theme.label({
		Name = "Cash",
		Size = UDim2.new(1, 0, 0, 40),
		Text = "$0",
		Font = Theme.TitleFont,
		TextColor3 = C.Cash,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 36,
		Parent = panel,
	})
	Theme.textStroke().Parent = cashLabel

	local capacityLabel = Theme.label({
		Name = "CapacityText",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Backpack 0/10",
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = panel,
	})

	local bar = Theme.create("Frame", {
		Name = "CapacityBar",
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundColor3 = C.PanelLight,
		Parent = panel,
	}, { Theme.corner(8) })
	local fill = Theme.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Good,
		Parent = bar,
	}, { Theme.corner(8) })

	local rows: { [string]: TextLabel } = {}
	for i, scrap in Config.ScrapTypes do
		local row = Theme.create("Frame", {
			Name = scrap.Id,
			Position = UDim2.fromOffset(0, 94 + (i - 1) * 26),
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Parent = panel,
		})
		Theme.create("Frame", {
			Name = "Swatch",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = scrap.Color,
			Parent = row,
		}, { Theme.corner(4) })
		Theme.label({
			Name = "Name",
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -70, 1, 0),
			Text = scrap.Name,
			TextColor3 = C.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 16,
			Parent = row,
		})
		rows[scrap.Id] = Theme.label({
			Name = "Count",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 46, 1, 0),
			Text = "0",
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 18,
			Parent = row,
		})
	end

	local toolLabel = Theme.label({
		Name = "Tool",
		Position = UDim2.fromOffset(0, 94 + #Config.ScrapTypes * 26 + 6),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		TextColor3 = C.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = panel,
	})

	local hint = Theme.label({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.new(0.6, 0, 0, 34),
		Text = "",
		Font = Theme.TitleFont,
		MaxTextSize = 26,
		Parent = screen,
	})
	Theme.textStroke().Parent = hint

	local cashValue = Instance.new("NumberValue")
	local self = setmetatable({
		cashLabel = cashLabel,
		capacityLabel = capacityLabel,
		capacityFill = fill,
		toolLabel = toolLabel,
		rows = rows,
		hint = hint,
		shownCash = 0,
		cashTween = nil :: Tween?,
		cashValue = cashValue,
	}, Hud)

	-- Cash counts up smoothly instead of snapping.
	cashValue.Changed:Connect(function(value)
		cashLabel.Text = Formulas.formatCash(value)
	end)
	return self
end

local function pop(object: GuiObject)
	local scale = object:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = object
	scale.Scale = 1.25
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function Hud.update(self: Hud, state: any)
	local C = Theme.Colors

	if state.Cash ~= self.shownCash then
		if self.cashTween then
			self.cashTween:Cancel()
		end
		local tween = TweenService:Create(self.cashValue, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = state.Cash })
		self.cashTween = tween
		tween:Play()
		if state.Cash > self.shownCash then
			pop(self.cashLabel)
		end
		self.shownCash = state.Cash
	end

	local ratio = if state.Capacity > 0 then state.Used / state.Capacity else 0
	self.capacityLabel.Text = `Backpack {state.Used}/{state.Capacity}`
	TweenService:Create(self.capacityFill, TweenInfo.new(0.25), {
		Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1),
		BackgroundColor3 = if ratio >= 1 then C.Bad elseif ratio >= 0.7 then C.Accent else C.Good,
	}):Play()
	self.capacityLabel.TextColor3 = if ratio >= 1 then C.Bad else C.Text

	for id, label in self.rows do
		local count = state.Inventory[id] or 0
		local text = tostring(count)
		if label.Text ~= text then
			label.Text = text
			if count > 0 then
				pop(label)
			end
		end
	end

	self.toolLabel.Text = `Tool: {state.ToolName}`

	-- Context hint guides the core loop for new players.
	local cheapest = math.huge
	for _, upgrade in state.Upgrades do
		if upgrade.Price and upgrade.Price < cheapest then
			cheapest = upgrade.Price
		end
	end
	if state.Used >= state.Capacity then
		self.hint.Text = "Backpack full! Sell at the green SELL station."
		self.hint.TextColor3 = C.Bad
	elseif state.Cash >= cheapest and state.Used == 0 then
		self.hint.Text = "You can afford an upgrade! Visit the blue UPGRADE SHOP."
		self.hint.TextColor3 = C.Accent
	elseif state.Used == 0 then
		self.hint.Text = "Walk up to a scrap pile and hold [E] to collect junk!"
		self.hint.TextColor3 = C.Text
	else
		self.hint.Text = ""
	end
end

return Hud
