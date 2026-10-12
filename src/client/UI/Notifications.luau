--!strict
-- Toast messages and the big sale popup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Theme = require(script.Parent.Theme)

local Notifications = {}

local MAX_TOASTS = 4
local container: Frame
local saleLabel: TextLabel
local saleDetail: TextLabel
local saleScale: UIScale
local saleToken = 0
local toastCount = 0

function Notifications.init(screen: ScreenGui)
	container = Theme.create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0.5, 0, 0, 200),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Theme.create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	local sale = Theme.create("Frame", {
		Name = "SalePopup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromOffset(420, 120),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	saleScale = Theme.create("UIScale", { Parent = sale })
	saleLabel = Theme.label({
		Name = "Amount",
		Size = UDim2.fromScale(1, 0.7),
		Font = Theme.TitleFont,
		TextColor3 = Theme.Colors.Cash,
		MaxTextSize = 80,
		Parent = sale,
	})
	Theme.create("UIStroke", { Thickness = 4, Color = Theme.Colors.Stroke, Parent = saleLabel })
	saleDetail = Theme.label({
		Name = "Detail",
		Position = UDim2.fromScale(0, 0.7),
		Size = UDim2.fromScale(1, 0.3),
		MaxTextSize = 22,
		Parent = sale,
	})
	Theme.textStroke().Parent = saleDetail
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
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.1,
		LayoutOrder = toastCount,
		Parent = container,
	}, { Theme.corner(10), Theme.stroke(2, color) })
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

	task.delay(3, function()
		if toast.Parent then
			local info = TweenInfo.new(0.4)
			TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

function Notifications.sale(total: number, count: number, breakdown: { { Id: string, Count: number, Earned: number } })
	saleToken += 1
	local token = saleToken

	local parts = {}
	for _, entry in breakdown do
		local scrap = Formulas.getScrapType(entry.Id)
		if scrap then
			table.insert(parts, `{entry.Count} {scrap.Name}`)
		end
	end
	saleLabel.Text = "+" .. Formulas.formatCash(total)
	saleDetail.Text = `Sold {count} item{if count == 1 then "" else "s"}: {table.concat(parts, ", ")}`

	local frame = saleLabel.Parent :: Frame
	frame.Visible = true
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
			frame.Visible = false
		end
	end)
end

return Notifications
