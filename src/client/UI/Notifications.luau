--!strict
-- Toasts, the sale popup, server-wide announcement banners and big rare-find
-- banners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Theme = require(script.Parent.Theme)

local Notifications = {}

local MAX_TOASTS = 4
local container: Frame
local saleFrame: Frame
local saleLabel: TextLabel
local saleDetail: TextLabel
local saleScale: UIScale
local saleToken = 0
local toastCount = 0
local bannerFrame: Frame
local bannerLabel: TextLabel
local bannerQueue: { { Text: string, Color: Color3 } } = {}
local bannerBusy = false
local bigLabel: TextLabel
local bigSub: TextLabel
local bigScale: UIScale
local bigToken = 0

local EVENT_COLORS = {
	Golden = Color3.fromRGB(255, 210, 60),
	Frenzy = Color3.fromRGB(255, 120, 60),
	Rebirth = Color3.fromRGB(255, 120, 210),
}

function Notifications.init(screen: ScreenGui)
	container = Theme.create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.new(0.42, 0, 0, 200),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = screen,
	}, {
		Theme.create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	saleFrame = Theme.create("Frame", {
		Name = "SalePopup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(460, 130),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = screen,
	})
	saleScale = Theme.create("UIScale", { Parent = saleFrame })
	saleLabel = Theme.label({
		Name = "Amount",
		Size = UDim2.fromScale(1, 0.68),
		Font = Theme.TitleFont,
		TextColor3 = Theme.Colors.Cash,
		MaxTextSize = 84,
		Parent = saleFrame,
	})
	Theme.textStroke(4).Parent = saleLabel
	saleDetail = Theme.label({
		Name = "Detail",
		Position = UDim2.fromScale(0, 0.7),
		Size = UDim2.fromScale(1, 0.3),
		MaxTextSize = 20,
		TextWrapped = true,
		Parent = saleFrame,
	})
	Theme.textStroke().Parent = saleDetail

	bannerFrame = Theme.create("Frame", {
		Name = "Announcement",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -80),
		Size = UDim2.new(0.5, 0, 0, 48),
		BackgroundColor3 = Theme.Colors.Panel,
		ZIndex = 25,
		Parent = screen,
	}, { Theme.corner(14), Theme.stroke(3) })
	bannerLabel = Theme.label({
		Size = UDim2.new(1, -20, 1, -10),
		Position = UDim2.fromOffset(10, 5),
		Font = Theme.TitleFont,
		MaxTextSize = 26,
		Parent = bannerFrame,
	})
	Theme.textStroke().Parent = bannerLabel

	local big = Theme.create("Frame", {
		Name = "BigFind",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromOffset(560, 120),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = screen,
	})
	bigScale = Theme.create("UIScale", { Scale = 0, Parent = big })
	bigLabel = Theme.label({ Size = UDim2.fromScale(1, 0.62), Font = Theme.TitleFont, MaxTextSize = 72, Parent = big })
	Theme.textStroke(4).Parent = bigLabel
	bigSub = Theme.label({ Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.38), Font = Theme.TitleFont, MaxTextSize = 32, Parent = big })
	Theme.textStroke(3).Parent = bigSub
end

local KIND_COLORS = {
	success = Theme.Colors.Good,
	error = Theme.Colors.Bad,
	info = Theme.Colors.Info,
}

function Notifications.toast(message: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or Theme.Colors.Info

	local toasts = {}
	for _, child in container:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #toasts >= MAX_TOASTS do
		table.remove(toasts, 1):Destroy()
	end

	toastCount += 1
	local toast = Theme.create("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.Colors.Panel,
		LayoutOrder = toastCount,
		Parent = container,
	}, { Theme.corner(10), Theme.stroke(3, color) })
	local label = Theme.label({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = message,
		TextColor3 = color,
		MaxTextSize = 20,
		Parent = toast,
	})
	local scale = Theme.create("UIScale", { Scale = 0.6, Parent = toast })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	task.delay(3.2, function()
		if toast.Parent then
			local info = TweenInfo.new(0.4)
			TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

function Notifications.sale(total: number, count: number, breakdown: { { Id: string, Count: number } }, multiplier: number)
	saleToken += 1
	local token = saleToken

	-- Summarise by rarity so big sales stay readable.
	local byRarity: { [string]: number } = {}
	for _, entry in breakdown do
		local item = Zones.Items[entry.Id]
		if item then
			byRarity[item.Rarity] = (byRarity[item.Rarity] or 0) + entry.Count
		end
	end
	local parts = {}
	for _, rarity in Config.Rarities do
		if byRarity[rarity.Id] then
			table.insert(parts, `{byRarity[rarity.Id]} {rarity.Name}`)
		end
	end
	saleLabel.Text = "+" .. Formulas.formatCash(total)
	local multText = if multiplier > 1.001 then string.format("  (x%.2f bonus)", multiplier) else ""
	saleDetail.Text = `Sold {count} item{if count == 1 then "" else "s"}: {table.concat(parts, ", ")}{multText}`

	saleFrame.Visible = true
	saleLabel.TextTransparency = 0
	saleDetail.TextTransparency = 0
	saleScale.Scale = 0.3
	TweenService:Create(saleScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.delay(2.2, function()
		if token ~= saleToken then
			return
		end
		local info = TweenInfo.new(0.5)
		TweenService:Create(saleLabel, info, { TextTransparency = 1 }):Play()
		TweenService:Create(saleDetail, info, { TextTransparency = 1 }):Play()
		task.wait(0.5)
		if token == saleToken then
			saleFrame.Visible = false
		end
	end)
end

local function nextBanner()
	if bannerBusy or #bannerQueue == 0 then
		return
	end
	bannerBusy = true
	local entry = table.remove(bannerQueue, 1) :: { Text: string, Color: Color3 }
	bannerLabel.Text = entry.Text
	bannerLabel.TextColor3 = entry.Color
	local stroke = bannerFrame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = entry.Color
	end
	TweenService:Create(bannerFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 12) }):Play()
	task.delay(3.6, function()
		TweenService:Create(bannerFrame, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
		task.wait(0.35)
		bannerBusy = false
		nextBanner()
	end)
end

-- Server-wide announcement (golden piles, frenzy, rare finds by anyone).
function Notifications.announce(text: string, kind: string?)
	local color = EVENT_COLORS[kind or ""]
	if not color then
		local rarity = Config.RarityById[kind or ""]
		color = if rarity then rarity.Color else Theme.Colors.Accent
	end
	if #bannerQueue < 5 then
		table.insert(bannerQueue, { Text = text, Color = color :: Color3 })
	end
	nextBanner()
end

-- Big centre-screen banner for your own Epic+ finds and hatches.
function Notifications.bigFind(title: string, subtitle: string, color: Color3)
	bigToken += 1
	local token = bigToken
	bigLabel.Text = title
	bigLabel.TextColor3 = color
	bigSub.Text = subtitle
	bigSub.TextColor3 = Theme.Colors.Text
	bigLabel.TextTransparency = 0
	bigSub.TextTransparency = 0
	bigScale.Scale = 0.2
	TweenService:Create(bigScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.4, function()
		if token ~= bigToken then
			return
		end
		local info = TweenInfo.new(0.5)
		TweenService:Create(bigLabel, info, { TextTransparency = 1 }):Play()
		TweenService:Create(bigSub, info, { TextTransparency = 1 }):Play()
	end)
end

return Notifications
