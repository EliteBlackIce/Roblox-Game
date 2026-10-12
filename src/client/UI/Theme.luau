--!strict
-- Shared colours, fonts and small factories for the UI modules. Bright,
-- bubbly Pet-Simulator-style look: cream panels, thick ink outlines, chunky
-- Fredoka text, glossy coloured buttons with white stroked labels.

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(252, 250, 255),
	PanelLight = Color3.fromRGB(236, 238, 252),
	PanelDark = Color3.fromRGB(212, 216, 236),
	Stroke = Color3.fromRGB(38, 32, 60),
	Text = Color3.fromRGB(48, 42, 72), -- ink text on panels
	OnColor = Color3.fromRGB(255, 255, 255), -- text on buttons, headers and the 3D world
	SubText = Color3.fromRGB(118, 112, 145),
	Cash = Color3.fromRGB(80, 215, 90),
	Gems = Color3.fromRGB(60, 195, 255),
	Tokens = Color3.fromRGB(255, 110, 205),
	Accent = Color3.fromRGB(255, 195, 40),
	Good = Color3.fromRGB(80, 205, 100),
	Bad = Color3.fromRGB(240, 80, 80),
	Disabled = Color3.fromRGB(172, 172, 192),
	Info = Color3.fromRGB(80, 160, 255),
	Purple = Color3.fromRGB(170, 110, 255),
	Orange = Color3.fromRGB(255, 150, 60),
}

Theme.TitleFont = Enum.Font.FredokaOne
Theme.BodyFont = Enum.Font.FredokaOne

type Props = { [string]: any }

-- create("Frame", { Size = ... }, { child1, child2 })
function Theme.create(className: string, props: Props?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- Light-to-dark vertical gradient that gives flat colours a glossy, toy-like look.
function Theme.gloss(amount: number?): UIGradient
	local shade = 1 - (amount or 0.22)
	return Theme.create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(shade, shade, shade)),
		}),
	})
end

function Theme.corner(radius: number?): UICorner
	return Theme.create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Theme.stroke(thickness: number?, color: Color3?): UIStroke
	return Theme.create("UIStroke", {
		Thickness = thickness or 2,
		Color = color or Theme.Colors.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.textStroke(thickness: number?): UIStroke
	return Theme.create("UIStroke", { Thickness = thickness or 2, Color = Theme.Colors.Stroke, Transparency = 0.15 })
end

function Theme.padding(px: number): UIPadding
	local p = UDim.new(0, px)
	return Theme.create("UIPadding", { PaddingLeft = p, PaddingRight = p, PaddingTop = p, PaddingBottom = p })
end

function Theme.label(props: Props): TextLabel
	local defaults: Props = {
		BackgroundTransparency = 1,
		Font = Theme.BodyFont,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local label = Theme.create("TextLabel", defaults)
	Theme.create("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28, Parent = label })
	-- Coloured or white text gets a thin ink stroke so it pops on any background.
	local color = label.TextColor3
	if color ~= Theme.Colors.Text and color ~= Theme.Colors.SubText then
		Theme.create("UIStroke", { Name = "Ink", Thickness = 1.5, Color = Theme.Colors.Stroke, Parent = label })
	end
	return label
end

-- Chunky button. `onClick` runs on Activated.
function Theme.button(props: Props, onClick: () -> ()): TextButton
	local defaults: Props = {
		BackgroundColor3 = Theme.Colors.Good,
		Font = Theme.TitleFont,
		TextColor3 = Theme.Colors.OnColor,
		TextScaled = true,
		AutoButtonColor = true,
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local button = Theme.create("TextButton", defaults, {
		Theme.corner(12),
		Theme.stroke(3),
		Theme.gloss(),
		Theme.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
		Theme.create("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 22 }),
		Theme.create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }),
	})
	button.Activated:Connect(onClick)
	return button
end

-- Vertical scrolling list that grows with its content.
function Theme.scroll(parent: Instance, props: Props?, grid: Vector2?): ScrollingFrame
	local defaults: Props = {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	}
	for key, value in props or {} do
		defaults[key] = value
	end
	local frame = Theme.create("ScrollingFrame", defaults)
	if grid then
		Theme.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(grid.X, grid.Y),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = frame,
		})
	else
		Theme.create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = frame,
		})
	end
	Theme.create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), Parent = frame })
	return frame
end

function Theme.clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Progress bar; returns the bar and its fill.
function Theme.bar(parent: Instance, props: Props, color: Color3): (Frame, Frame)
	local defaults: Props = { BackgroundColor3 = Theme.Colors.PanelDark, Parent = parent }
	for key, value in props do
		defaults[key] = value
	end
	local bar = Theme.create("Frame", defaults, { Theme.corner(8) })
	local fill = Theme.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, Parent = bar }, { Theme.corner(8) })
	return bar, fill
end

return Theme
