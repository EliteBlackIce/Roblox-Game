--!strict
-- Scrap Bot inventory: equip, unequip, equip best, golden merge and delete.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotArt = require(ReplicatedStorage.Shared.Art.BotArt)
local Bots = require(ReplicatedStorage.Shared.Bots)
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Viewport = require(script.Parent.Parent.Viewport)
local Windows = require(script.Parent.Parent.Windows)

local C = Theme.Colors

local function bonusText(bot: Bots.Bot, golden: boolean): string
	local mult = if golden then Bots.GoldenMultiplier else 1
	local parts = {}
	if bot.Cash > 0 then
		table.insert(parts, `+{math.floor(bot.Cash * mult * 100 + 0.5)}% cash`)
	end
	if bot.Luck > 0 then
		table.insert(parts, `+{math.floor(bot.Luck * mult * 100 + 0.5)}% luck`)
	end
	return table.concat(parts, "  ")
end

local function power(owned: any): number
	local bot = Bots.ById[owned.Id]
	local mult = if owned.Golden then Bots.GoldenMultiplier else 1
	return (bot.Cash + bot.Luck * 1.5) * mult
end

return function()
	local panel = Windows.create("Bots", "SCRAP BOTS", C.Purple, Vector2.new(860, 540))
	local content = panel.Content

	local summary = Theme.label({ Size = UDim2.new(0.6, 0, 0, 34), Text = "", TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = content })
	Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(150, 34),
		BackgroundColor3 = C.Purple,
		Text = "Equip Best",
		Parent = content,
	}, function()
		State.request("EquipBest")
	end)

	local grid = Theme.scroll(content, { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(0.64, 0, 1, -42) }, Vector2.new(112, 128))
	local detail = Theme.create("Frame", {
		Name = "Detail",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 42),
		Size = UDim2.new(0.34, 0, 1, -42),
		BackgroundColor3 = C.PanelLight,
		Parent = content,
	}, { Theme.corner(12), Theme.stroke(2), Theme.padding(10) })
	local empty = Theme.label({ Size = UDim2.fromScale(1, 1), Text = "Hatch bots from the crates in the Hub!\n\nSelect a bot to manage it.", TextWrapped = true, TextColor3 = C.SubText, MaxTextSize = 18, Parent = detail })
	local info = Theme.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = detail })
	local swatch = Theme.create("Frame", { Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = C.Panel, Parent = info }, { Theme.corner(12), Theme.stroke(3) })
	local nameLabel = Theme.label({ Position = UDim2.fromOffset(0, 124), Size = UDim2.new(1, 0, 0, 26), Font = Theme.TitleFont, MaxTextSize = 24, Parent = info })
	local rarityLabel = Theme.label({ Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 18), Font = Theme.TitleFont, MaxTextSize = 18, Parent = info })
	local statsLabel = Theme.label({ Position = UDim2.fromOffset(0, 170), Size = UDim2.new(1, 0, 0, 20), TextColor3 = C.Cash, MaxTextSize = 17, Parent = info })
	local shownDetail = ""

	local selected: string? = nil
	local deleteArmed = false

	local equipButton = Theme.button({ Position = UDim2.new(0, 0, 1, -150), Size = UDim2.new(1, 0, 0, 42), Text = "Equip", Parent = info }, function()
		local state = State.current
		if not state or not selected then
			return
		end
		if table.find(state.Equipped, selected) then
			State.request("UnequipBot", selected)
		else
			State.request("EquipBot", selected)
		end
	end)
	local goldenButton = Theme.button({ Position = UDim2.new(0, 0, 1, -100), Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.Accent, Text = "Make Golden", Parent = info }, function()
		local state = State.current
		if not state or not selected then
			return
		end
		for _, owned in state.Bots do
			if owned.Uid == selected then
				State.request("GoldenBot", owned.Id)
				selected = nil
			end
		end
	end)
	local deleteButton = Theme.button({ Position = UDim2.new(0, 0, 1, -50), Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C.Bad, Text = "Delete", Parent = info }, function()
		if not selected then
			return
		end
		if not deleteArmed then
			deleteArmed = true
			deleteButton.Text = "Tap again to delete"
			return
		end
		State.request("DeleteBot", selected)
		selected = nil
		deleteArmed = false
	end)

	local function renderDetail(state: any)
		local owned = nil
		for _, candidate in state.Bots do
			if candidate.Uid == selected then
				owned = candidate
			end
		end
		if not owned then
			selected = nil
			info.Visible = false
			empty.Visible = true
			return
		end
		info.Visible = true
		empty.Visible = false
		local bot = Bots.ById[owned.Id]
		local rarity = Config.RarityById[bot.Rarity]
		local key = owned.Uid .. tostring(owned.Golden)
		if shownDetail ~= key then
			shownDetail = key
			Theme.clear(swatch)
			Viewport.new(swatch, BotArt.build(owned.Id, owned.Golden), nil, { Yaw = 25, Pitch = 10, Zoom = 1.1 })
		end
		local stroke = swatch:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if owned.Golden then C.Accent else rarity.Color
		end
		nameLabel.Text = (if owned.Golden then "Golden " else "") .. bot.Name
		nameLabel.TextColor3 = if owned.Golden then C.Accent else C.Text
		rarityLabel.Text = rarity.Name
		rarityLabel.TextColor3 = rarity.Color
		statsLabel.Text = bonusText(bot, owned.Golden)

		local equipped = table.find(state.Equipped, owned.Uid) ~= nil
		equipButton.Text = if equipped then "Unequip" else "Equip"
		equipButton.BackgroundColor3 = if equipped then C.Disabled else C.Good

		local copies = 0
		for _, other in state.Bots do
			if other.Id == owned.Id and not other.Golden then
				copies += 1
			end
		end
		goldenButton.Visible = not owned.Golden
		goldenButton.Text = `Make Golden ({math.min(copies, Bots.MergeCount)}/{Bots.MergeCount})`
		goldenButton.BackgroundColor3 = if copies >= Bots.MergeCount then C.Accent else C.Disabled
		if not deleteArmed then
			deleteButton.Text = "Delete"
		end
	end

	local lastSignature = ""
	local function render(state: any)
		summary.Text = `Equipped {#state.Equipped}/{state.BotSlots}  •  Storage {#state.Bots}/{Bots.MaxInventory}`
		-- Only rebuild the 3D cards when the bot list actually changed.
		local parts = { tostring(selected) }
		for _, owned in state.Bots do
			table.insert(parts, owned.Uid .. owned.Id .. tostring(owned.Golden))
		end
		table.insert(parts, table.concat(state.Equipped, "/"))
		local signature = table.concat(parts, ",")
		if signature == lastSignature then
			renderDetail(state)
			return
		end
		lastSignature = signature
		Theme.clear(grid)
		local sorted = table.clone(state.Bots)
		table.sort(sorted, function(a, b)
			local ea = table.find(state.Equipped, a.Uid) ~= nil
			local eb = table.find(state.Equipped, b.Uid) ~= nil
			if ea ~= eb then
				return ea
			end
			return power(a) > power(b)
		end)
		for i, owned in sorted do
			local bot = Bots.ById[owned.Id]
			local rarity = Config.RarityById[bot.Rarity]
			local equipped = table.find(state.Equipped, owned.Uid) ~= nil
			local card = Theme.create("TextButton", {
				Name = "Bot_" .. owned.Uid,
				LayoutOrder = i,
				BackgroundColor3 = if owned.Uid == selected then C.Info else C.PanelLight,
				Text = "",
				AutoButtonColor = true,
				Parent = grid,
			}, { Theme.corner(12), Theme.stroke(3, if owned.Golden then C.Accent else rarity.Color) })
			Viewport.new(card, BotArt.build(owned.Id, owned.Golden), { Size = UDim2.new(1, 0, 0, 62), Position = UDim2.fromOffset(0, 2) }, { Yaw = 25, Pitch = 10, Zoom = 1.1 })
			Theme.label({ Position = UDim2.fromOffset(4, 60), Size = UDim2.new(1, -8, 0, 22), Text = bot.Name, Font = Theme.TitleFont, MaxTextSize = 16, Parent = card })
			Theme.label({ Position = UDim2.fromOffset(4, 82), Size = UDim2.new(1, -8, 0, 16), Text = rarity.Name, TextColor3 = rarity.Color, MaxTextSize = 13, Parent = card })
			if equipped then
				Theme.label({ Position = UDim2.fromOffset(4, 102), Size = UDim2.new(1, -8, 0, 18), Text = "EQUIPPED", Font = Theme.TitleFont, TextColor3 = C.Good, MaxTextSize = 14, Parent = card })
			end
			if owned.Golden then
				Theme.label({ Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(24, 24), Text = "*", Font = Theme.TitleFont, TextColor3 = C.Accent, MaxTextSize = 28, Parent = card })
			end
			card.Activated:Connect(function()
				selected = owned.Uid
				deleteArmed = false
				render(State.current)
			end)
		end
		renderDetail(state)
	end
	State.listen(render)
end
