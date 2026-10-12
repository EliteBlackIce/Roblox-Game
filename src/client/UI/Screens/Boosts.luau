--!strict
-- Gem boosts: timed x2 cash, x2 luck and faster grabs. Buying again stacks time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Windows = require(script.Parent.Parent.Windows)

local C = Theme.Colors

return function()
	local panel = Windows.create("Boosts", "BOOSTS", C.Gems, Vector2.new(720, 420))
	local grid = Theme.scroll(panel.Content, nil, Vector2.new(200, 240))
	local cards = {}
	for i, boost in Config.Boosts do
		local card = Theme.create("Frame", { LayoutOrder = i, BackgroundColor3 = C.PanelLight, Parent = grid }, { Theme.corner(12), Theme.stroke(2, C.Gems), Theme.padding(10) })
		Theme.label({ Size = UDim2.new(1, 0, 0, 32), Text = boost.Name, Font = Theme.TitleFont, TextColor3 = C.Gems, MaxTextSize = 28, Parent = card })
		Theme.label({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 40), Text = `{boost.Description} for {boost.Duration // 60} minutes.`, TextWrapped = true, TextColor3 = C.SubText, MaxTextSize = 15, Parent = card })
		local status = Theme.label({ Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 24), Text = "", TextColor3 = C.Good, MaxTextSize = 18, Parent = card })
		local button = Theme.button({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = C.Gems,
			Text = `{boost.Gems} Gems`,
			Parent = card,
		}, function()
			State.request("BuyBoost", boost.Id)
		end)
		cards[boost.Id] = { status = status, button = button }
	end

	local function render(state: any)
		local now = State.now()
		for _, boost in Config.Boosts do
			local card = cards[boost.Id]
			local expires = state.Boosts[boost.Id]
			card.status.Text = if expires and expires > now then `Active: {Formulas.formatTime(expires - now)}` else "Not active"
			card.status.TextColor3 = if expires and expires > now then C.Good else C.SubText
			card.button.BackgroundColor3 = if state.Gems >= boost.Gems then C.Gems else C.Disabled
		end
	end
	State.listen(render)
	task.spawn(function()
		while true do
			task.wait(1)
			if Windows.isOpen("Boosts") and State.current then
				render(State.current)
			end
		end
	end)
end
