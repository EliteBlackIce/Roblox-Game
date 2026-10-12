--!strict
-- Quest chain, daily quests (claimable) and the daily login streak.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Quests = require(ReplicatedStorage.Shared.Quests)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Windows = require(script.Parent.Parent.Windows)

local C = Theme.Colors

local function section(parent: Instance, order: number, title: string, color: Color3): Frame
	local frame = Theme.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.PanelLight,
		Parent = parent,
	}, {
		Theme.corner(12),
		Theme.stroke(2),
		Theme.padding(10),
		Theme.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.label({ LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 24), Text = title, Font = Theme.TitleFont, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, Parent = frame })
	return frame
end

local function questRow(parent: Instance, order: number, text: string, progress: number, goal: number, reward: string, button: TextButton?)
	local row = Theme.create("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = C.Panel, Parent = parent }, { Theme.corner(10), Theme.padding(6) })
	local width = if button then -130 else 0
	Theme.label({ Size = UDim2.new(1, width, 0, 22), Text = text, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 17, Parent = row })
	local _, fill = Theme.bar(row, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, width, 0, 10) }, C.Accent)
	fill.Size = UDim2.fromScale(math.clamp(progress / goal, 0, 1), 1)
	Theme.label({
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, width, 0, 16),
		Text = `{Formulas.formatNumber(progress)}/{Formulas.formatNumber(goal)}  •  {reward}`,
		TextColor3 = C.Cash,
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 14,
		Parent = row,
	})
	if button then
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.fromScale(1, 0.5)
		button.Size = UDim2.new(0, 120, 1, -6)
		button.Parent = row
	end
end

return function()
	local panel = Windows.create("Quests", "QUESTS", C.Accent, Vector2.new(720, 540))
	local list = Theme.scroll(panel.Content)

	local function render(state: any)
		Theme.clear(list)

		local login = section(list, 1, `DAILY LOGIN  •  Day {state.Login.Streak} streak`, C.Gems)
		local loginRow = Theme.create("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = login })
		local rewards = {}
		for day, gems in Quests.LoginRewards do
			table.insert(rewards, `D{day}: {gems}`)
		end
		Theme.label({ Size = UDim2.new(1, -150, 1, 0), Text = table.concat(rewards, "   "), TextColor3 = C.SubText, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 14, Parent = loginRow })
		Theme.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 140, 1, 0),
			BackgroundColor3 = if state.Login.CanClaim then C.Good else C.Disabled,
			Text = if state.Login.CanClaim then `Claim {state.Login.Reward} Gems` else "Claimed today",
			Parent = loginRow,
		}, function()
			if State.current and State.current.Login.CanClaim then
				State.request("ClaimLogin")
			end
		end)

		local chain = section(list, 2, "QUEST CHAIN", C.Accent)
		if state.Quest then
			questRow(chain, 1, `{state.Quest.Index}. {state.Quest.Text}`, state.Quest.Progress, state.Quest.Goal, `Reward: {state.Quest.Reward}`, nil)
		else
			Theme.label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 24), Text = "You finished every quest. Legend!", MaxTextSize = 18, Parent = chain })
		end

		local dailies = section(list, 3, `DAILY QUESTS  •  new in {Formulas.formatTime(state.DailyResetIn)}`, C.Good)
		for i, daily in state.Dailies do
			local done = daily.Progress >= daily.Goal
			local button = Theme.button({
				BackgroundColor3 = if daily.Claimed then C.Disabled elseif done then C.Good else C.PanelDark,
				Text = if daily.Claimed then "Claimed" elseif done then "Claim" else "In progress",
			}, function()
				State.request("ClaimDaily", i)
			end)
			questRow(dailies, i, daily.Text, daily.Progress, daily.Goal, daily.Reward, button)
		end
		Theme.label({ LayoutOrder = 99, Size = UDim2.new(1, 0, 0, 18), Text = `Finish all three for a bonus {Quests.DailyAllBonus.Gems} gems!`, TextColor3 = C.SubText, MaxTextSize = 14, Parent = dailies })
	end
	State.listen(function(state)
		if Windows.isOpen("Quests") then
			render(state)
		end
	end)
	panel.OnOpen = function()
		if State.current then
			render(State.current)
		end
	end
end
