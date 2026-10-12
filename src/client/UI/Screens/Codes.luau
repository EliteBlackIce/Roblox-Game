--!strict
-- Code redemption window.

local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Windows = require(script.Parent.Parent.Windows)

local C = Theme.Colors

return function()
	local panel = Windows.create("Codes", "CODES", C.Good, Vector2.new(520, 300))
	Theme.label({ Size = UDim2.new(1, 0, 0, 40), Text = "Follow the game for new codes at every update!", TextWrapped = true, TextColor3 = C.SubText, MaxTextSize = 17, Parent = panel.Content })
	local box = Theme.create("TextBox", {
		Name = "CodeBox",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = C.PanelDark,
		PlaceholderText = "Type a code...",
		PlaceholderColor3 = C.SubText,
		Text = "",
		ClearTextOnFocus = false,
		Font = Theme.TitleFont,
		TextColor3 = C.Text,
		TextScaled = true,
		Parent = panel.Content,
	}, { Theme.corner(10), Theme.stroke(2), Theme.create("UITextSizeConstraint", { MaxTextSize = 26 }) })
	Theme.button({ Name = "Redeem", Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 50), Text = "Redeem", Parent = panel.Content }, function()
		if box.Text ~= "" then
			local ok = State.request("RedeemCode", box.Text)
			if ok then
				box.Text = ""
			end
		end
	end)
end
