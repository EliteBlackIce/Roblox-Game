--!strict
-- Always-on HUD: currencies, backpack, multipliers, active boosts/events, the
-- current quest, a context hint and the Remote Sell button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Tools = require(ReplicatedStorage.Shared.Tools)
local Zones = require(ReplicatedStorage.Shared.Zones)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)

local Hud = {}

local C = Theme.Colors

local refs: { [string]: any } = {}
local cashValue: NumberValue
local shownCash = 0
local cashTween: Tween? = nil

local function pop(object: GuiObject)
	local scale = object:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = object
	scale.Scale = 1.25
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Pet-Sim style counter: a rounded pill with a round coloured icon bubble.
local function currencyRow(parent: Instance, name: string, order: number, color: Color3, icon: string): TextLabel
	local big = name == "Cash"
	local height = if big then 44 else 34
	local row = Theme.create("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = C.Panel,
		Parent = parent,
	}, {
		Theme.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Theme.stroke(3),
		Theme.gloss(0.12),
	})
	local badge = Theme.create("Frame", {
		Size = UDim2.fromOffset(height + 6, height + 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, height / 2 - 4, 0.5, 0),
		BackgroundColor3 = color,
		ZIndex = 2,
		Parent = row,
	}, { Theme.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), Theme.stroke(3), Theme.gloss(0.3) })
	Theme.label({ Size = UDim2.fromScale(1, 1), Text = icon, Font = Theme.TitleFont, TextColor3 = C.OnColor, ZIndex = 2, MaxTextSize = if big then 26 else 20, Parent = badge })
	local label = Theme.label({
		Name = "Value",
		Position = UDim2.fromOffset(height + 8, 0),
		Size = UDim2.new(1, -(height + 14), 1, 0),
		Text = "0",
		Font = Theme.TitleFont,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = if big then 32 else 22,
		Parent = row,
	})
	return label
end

function Hud.init(screen: ScreenGui, onRemoteSell: () -> ())
	local stats = Theme.create("Frame", {
		Name = "StatsPanel",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(262, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Panel,
		Parent = screen,
	}, {
		Theme.corner(18),
		Theme.stroke(4),
		Theme.gloss(0.1),
		Theme.padding(12),
		Theme.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	refs.cash = currencyRow(stats, "Cash", 1, C.Cash, "$")
	refs.gems = currencyRow(stats, "Gems", 2, C.Gems, "◆")
	refs.tokens = currencyRow(stats, "Tokens", 3, C.Tokens, "★")
	refs.tokensRow = refs.tokens.Parent

	refs.capacityText = Theme.label({
		Name = "Backpack",
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Backpack 0/10",
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 17,
		Parent = stats,
	})
	local bar, fill = Theme.bar(stats, { Name = "CapacityBar", LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 16) }, C.Good)
	refs.capacityFill = fill
	refs.capacityBar = bar
	refs.bagValue = Theme.label({
		Name = "BagValue",
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 18),
		Text = "",
		TextColor3 = C.Cash,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 16,
		Parent = stats,
	})
	refs.multipliers = Theme.label({
		Name = "Multipliers",
		LayoutOrder = 7,
		Size = UDim2.new(1, 0, 0, 18),
		Text = "",
		TextColor3 = C.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = stats,
	})
	refs.tool = Theme.label({
		Name = "Tool",
		LayoutOrder = 8,
		Size = UDim2.new(1, 0, 0, 18),
		Text = "",
		TextColor3 = C.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 15,
		Parent = stats,
	})

	-- Active boosts and events, top-right.
	refs.timers = Theme.create("Frame", {
		Name = "Timers",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(210, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screen,
	}, { Theme.create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- Quest tracker, right side.
	local quest = Theme.create("Frame", {
		Name = "QuestTracker",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.45, 0),
		Size = UDim2.fromOffset(240, 92),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.08,
		Parent = screen,
	}, { Theme.corner(12), Theme.stroke(3), Theme.padding(8) })
	refs.questFrame = quest
	refs.questTitle = Theme.label({ Size = UDim2.new(1, 0, 0, 18), Text = "QUEST", Font = Theme.TitleFont, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 17, Parent = quest })
	refs.questText = Theme.label({ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 30), Text = "", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 15, Parent = quest })
	local _, questFill = Theme.bar(quest, { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 12) }, C.Accent)
	refs.questFill = questFill
	refs.questReward = Theme.label({ Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 16), Text = "", TextColor3 = C.Cash, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = quest })

	refs.hint = Theme.label({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.new(0.6, 0, 0, 32),
		Text = "",
		Font = Theme.TitleFont,
		TextColor3 = C.OnColor,
		MaxTextSize = 26,
		Parent = screen,
	})
	Theme.textStroke(3).Parent = refs.hint

	refs.remoteSell = Theme.button({
		Name = "RemoteSell",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromOffset(170, 44),
		BackgroundColor3 = C.Good,
		Text = "$ SELL ALL",
		Visible = false,
		MaxTextSize = 24,
		Parent = screen,
	}, onRemoteSell)

	cashValue = Instance.new("NumberValue")
	cashValue.Changed:Connect(function(value)
		refs.cash.Text = Formulas.formatCash(value)
	end)

	-- Timers tick every second between state updates.
	task.spawn(function()
		while true do
			task.wait(1)
			if State.current then
				Hud.updateTimers(State.current)
			end
		end
	end)
end

local timerRows: { [string]: TextLabel } = {}
local function timerRow(id: string, text: string, color: Color3, order: number)
	local label = timerRows[id]
	if not label then
		local frame = Theme.create("Frame", {
			Name = id,
			Size = UDim2.fromOffset(210, 32),
			BackgroundColor3 = C.Panel,
			LayoutOrder = order,
			Parent = refs.timers,
		}, { Theme.corner(10), Theme.stroke(2, color) })
		label = Theme.label({ Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), Font = Theme.TitleFont, TextColor3 = color, MaxTextSize = 18, Parent = frame })
		timerRows[id] = label
	end
	label.Text = text
end

local function removeTimer(id: string)
	local label = timerRows[id]
	if label then
		(label.Parent :: Instance):Destroy()
		timerRows[id] = nil
	end
end

function Hud.updateTimers(state: any)
	local now = State.now()
	if state.FrenzyUntil and state.FrenzyUntil > now then
		timerRow("Frenzy", `FRENZY x2  {Formulas.formatTime(state.FrenzyUntil - now)}`, C.Orange, 0)
	else
		removeTimer("Frenzy")
	end
	for i, boost in Config.Boosts do
		local expires = state.Boosts[boost.Id]
		if expires and expires > now then
			timerRow(boost.Id, `{boost.Name}  {Formulas.formatTime(expires - now)}`, C.Gems, i)
		else
			removeTimer(boost.Id)
		end
	end
end

function Hud.update(state: any)
	if state.Cash ~= shownCash then
		if cashTween then
			cashTween:Cancel()
		end
		local tween = TweenService:Create(cashValue, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Value = state.Cash })
		cashTween = tween
		tween:Play()
		if state.Cash > shownCash then
			pop(refs.cash)
		end
		shownCash = state.Cash
	end
	refs.gems.Text = Formulas.formatNumber(state.Gems)
	refs.tokens.Text = `{state.Tokens} Rebirth Token{if state.Tokens == 1 then "" else "s"}`
	refs.tokensRow.Visible = state.Rebirths > 0 or state.Tokens > 0

	local ratio = if state.Capacity > 0 then state.Used / state.Capacity else 0
	refs.capacityText.Text = `Backpack {state.Used}/{state.Capacity}`
	refs.capacityText.TextColor3 = if ratio >= 1 then C.Bad else C.Text
	TweenService:Create(refs.capacityFill, TweenInfo.new(0.25), {
		Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1),
		BackgroundColor3 = if ratio >= 1 then C.Bad elseif ratio >= 0.7 then C.Accent else C.Good,
	}):Play()
	local bagWorth = Formulas.inventoryValue(state.Inventory) * state.CashMultiplier
	refs.bagValue.Text = if state.Used > 0 then `Bag worth ~{Formulas.formatCash(bagWorth)}` else "Bag is empty"
	refs.multipliers.Text = string.format("x%.2f cash  •  x%.2f luck", state.CashMultiplier, state.Luck)
	refs.tool.Text = `Tool: {Tools[state.ToolTier].Name}`

	if state.Quest then
		refs.questFrame.Visible = true
		refs.questTitle.Text = `QUEST {state.Quest.Index}/{state.Quest.Total}`
		refs.questText.Text = state.Quest.Text
		TweenService:Create(refs.questFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(state.Quest.Progress / state.Quest.Goal, 0, 1), 1) }):Play()
		refs.questReward.Text = `{Formulas.formatNumber(state.Quest.Progress)}/{Formulas.formatNumber(state.Quest.Goal)}  •  Reward: {state.Quest.Reward}`
	else
		refs.questFrame.Visible = false
	end

	refs.remoteSell.Visible = (state.Perks.RemoteSell or 0) > 0 and state.Used > 0

	-- Context hint guides the core loop.
	local nextZone = nil
	for _, zone in Zones.List do
		if not state.Zones[zone.Id] then
			nextZone = zone
			break
		end
	end
	local cheapest = math.huge
	for _, upgrade in state.Upgrades do
		if upgrade.Price and upgrade.Price < cheapest then
			cheapest = upgrade.Price
		end
	end
	if state.Used >= state.Capacity then
		refs.hint.Text = "Backpack full! Sell at a green SELL pad."
		refs.hint.TextColor3 = C.Bad
	elseif nextZone and state.Cash >= nextZone.Price and state.Rebirths >= nextZone.RebirthsRequired then
		refs.hint.Text = `You can unlock {nextZone.Name}! Head to its gate.`
		refs.hint.TextColor3 = C.Accent
	elseif state.Cash >= state.RebirthCost then
		refs.hint.Text = "You can REBIRTH for a permanent cash boost!"
		refs.hint.TextColor3 = C.Tokens
	elseif state.Used == 0 and state.Cash >= cheapest then
		refs.hint.Text = "You can afford an upgrade! Visit the UPGRADES shop."
		refs.hint.TextColor3 = C.Accent
	elseif state.Used == 0 and state.TotalEarned == 0 then
		refs.hint.Text = "Walk up to a scrap pile and hold [E] to collect junk!"
		refs.hint.TextColor3 = C.OnColor
	else
		refs.hint.Text = ""
	end

	Hud.updateTimers(state)
end

return Hud
