--!strict
-- Upgrade shop window. Buttons send only the upgrade id; the server decides the
-- price, checks funds and applies the effect, then pushes back the new state.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)
local Notifications = require(script.Parent.Notifications)
local Effects = require(script.Parent.Parent.Effects)

local Shop = {}

type Card = {
	level: TextLabel,
	effect: TextLabel,
	button: TextButton,
}

local window: Frame
local scale: UIScale
local cashLabel: TextLabel
local cards: { [string]: Card } = {}
local state: any = nil
local pending = false
local isOpen = false

local function render()
	if not state or not window then
		return
	end
	local C = Theme.Colors
	cashLabel.Text = "Cash: " .. Formulas.formatCash(state.Cash)
	for _, info in state.Upgrades do
		local card = cards[info.Id]
		if card then
			card.level.Text = `Level {info.Level}/{info.MaxLevel}`
			if info.NextEffect then
				card.effect.Text = `{info.Effect}  ->  {info.NextEffect}`
			else
				card.effect.Text = info.Effect
			end
			if not info.Price then
				card.button.Text = "MAXED"
				card.button.BackgroundColor3 = C.Accent
				card.button.AutoButtonColor = false
			elseif state.Cash >= info.Price then
				card.button.Text = "Buy " .. Formulas.formatCash(info.Price)
				card.button.BackgroundColor3 = C.Good
				card.button.AutoButtonColor = true
			else
				card.button.Text = Formulas.formatCash(info.Price)
				card.button.BackgroundColor3 = C.Disabled
				card.button.AutoButtonColor = true
			end
		end
	end
end

local function purchase(id: string)
	if pending then
		return
	end
	pending = true
	local ok, success, message = pcall(function()
		return Remotes.func("PurchaseUpgrade"):InvokeServer(id)
	end)
	pending = false
	if not ok then
		Notifications.toast("Purchase failed, try again.", "error")
		Effects.playSound(Config.Sounds.Error)
		return
	end
	Notifications.toast(message, if success then "success" else "error")
	Effects.playSound(if success then Config.Sounds.Purchase else Config.Sounds.Error)
end

local function buildCard(parent: Instance, upgrade: Config.UpgradeDef, order: number)
	local C = Theme.Colors
	local card = Theme.create("Frame", {
		Name = upgrade.Id,
		LayoutOrder = order,
		Size = UDim2.new(1 / #Config.Upgrades, -10, 1, 0),
		BackgroundColor3 = C.PanelLight,
		Parent = parent,
	}, { Theme.corner(12), Theme.stroke(2), Theme.padding(10) })

	Theme.label({
		Name = "Title",
		Size = UDim2.fromScale(1, 0.16),
		Text = upgrade.Name,
		Font = Theme.TitleFont,
		TextColor3 = C.Accent,
		MaxTextSize = 26,
		Parent = card,
	})
	Theme.label({
		Name = "Description",
		Position = UDim2.fromScale(0, 0.18),
		Size = UDim2.fromScale(1, 0.2),
		Text = upgrade.Description,
		TextColor3 = C.SubText,
		TextWrapped = true,
		MaxTextSize = 16,
		Parent = card,
	})
	local level = Theme.label({
		Name = "Level",
		Position = UDim2.fromScale(0, 0.4),
		Size = UDim2.fromScale(1, 0.12),
		Text = "",
		MaxTextSize = 20,
		Parent = card,
	})
	local effect = Theme.label({
		Name = "Effect",
		Position = UDim2.fromScale(0, 0.54),
		Size = UDim2.fromScale(1, 0.2),
		Text = "",
		TextColor3 = C.Cash,
		TextWrapped = true,
		MaxTextSize = 18,
		Parent = card,
	})
	local button = Theme.create("TextButton", {
		Name = "Buy",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.2),
		BackgroundColor3 = C.Good,
		Font = Theme.TitleFont,
		Text = "Buy",
		TextColor3 = C.Text,
		TextScaled = true,
		Parent = card,
	}, { Theme.corner(10), Theme.stroke(2), Theme.create("UITextSizeConstraint", { MaxTextSize = 24 }) })
	button.Activated:Connect(function()
		purchase(upgrade.Id)
	end)

	cards[upgrade.Id] = { level = level, effect = effect, button = button }
end

function Shop.init(screen: ScreenGui)
	local C = Theme.Colors
	window = Theme.create("Frame", {
		Name = "ShopWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.55),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = screen,
	}, {
		Theme.corner(16),
		Theme.stroke(4),
		Theme.padding(14),
		Theme.create("UISizeConstraint", { MinSize = Vector2.new(340, 300), MaxSize = Vector2.new(820, 420) }),
	})
	scale = Theme.create("UIScale", { Parent = window })

	local title = Theme.label({
		Name = "Title",
		Size = UDim2.new(1, -60, 0, 40),
		Text = "UPGRADE SHOP",
		Font = Theme.TitleFont,
		TextColor3 = C.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 36,
		Parent = window,
	})
	Theme.textStroke().Parent = title

	cashLabel = Theme.label({
		Name = "Cash",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -56, 0, 6),
		Size = UDim2.new(0.4, 0, 0, 28),
		Text = "",
		TextColor3 = C.Cash,
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 24,
		Parent = window,
	})

	local close = Theme.create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = C.Bad,
		Font = Theme.TitleFont,
		Text = "X",
		TextColor3 = C.Text,
		TextScaled = true,
		Parent = window,
	}, { Theme.corner(10), Theme.stroke(2) })
	close.Activated:Connect(function()
		Shop.close()
	end)

	local list = Theme.create("Frame", {
		Name = "Cards",
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		Parent = window,
	}, {
		Theme.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})
	for i, upgrade in Config.Upgrades do
		buildCard(list, upgrade, i)
	end

	-- Close automatically when the player walks away from the shop.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if isOpen then
				local character = Players.LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local near = false
				if root and root:IsA("BasePart") then
					for _, shop in CollectionService:GetTagged("UpgradeShop") do
						local anchor = shop:FindFirstChild("PromptAnchor")
						if anchor and anchor:IsA("BasePart") and (anchor.Position - root.Position).Magnitude < Config.Gameplay.ShopRange + 6 then
							near = true
						end
					end
				end
				if not near then
					Shop.close()
				end
			end
		end
	end)
end

function Shop.setState(newState: any)
	state = newState
	render()
end

function Shop.open()
	if isOpen then
		return
	end
	isOpen = true
	render()
	window.Visible = true
	scale.Scale = 0.5
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Effects.playSound(Config.Sounds.Click)
end

function Shop.close()
	if not isOpen then
		return
	end
	isOpen = false
	window.Visible = false
end

return Shop
