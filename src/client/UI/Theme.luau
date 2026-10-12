--!strict
-- Shared colours, fonts and small factories for the UI modules. Chunky,
-- rounded, flat-colour style to match the low-poly world.

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(38, 36, 48),
	PanelLight = Color3.fromRGB(56, 53, 70),
	PanelDark = Color3.fromRGB(26, 25, 34),
	Stroke = Color3.fromRGB(14, 13, 20),
	Text = Color3.fromRGB(250, 248, 240),
	SubText = Color3.fromRGB(185, 182, 200),
	Cash = Color3.fromRGB(110, 235, 110),
	Gems = Color3.fromRGB(90, 220, 255),
	Tokens = Color3.fromRGB(255, 120, 210),
	Accent = Color3.fromRGB(255, 200, 50),
	Good = Color3.fromRGB(70, 195, 95),
	Bad = Color3.fromRGB(225, 70, 65),
	Disabled = Color3.fromRGB(95, 92, 108),
	Info = Color3.fromRGB(70, 145, 235),
	Purple = Color3.fromRGB(165, 95, 240),
	Orange = Color3.fromRGB(255, 145, 50),
}

Theme.TitleFont = Enum.Font.FredokaOne
Theme.BodyFont = Enum.Font.GothamBold

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
	return label
end

-- Chunky button. `onClick` runs on Activated.
function Theme.button(props: Props, onClick: () -> ()): TextButton
	local defaults: Props = {
		BackgroundColor3 = Theme.Colors.Good,
		Font = Theme.TitleFont,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		AutoButtonColor = true,
	}
	for key, value in props do
		if key ~= "MaxTextSize" then
			defaults[key] = value
		end
	end
	local button = Theme.create("TextButton", defaults, {
		Theme.corner(10),
		Theme.stroke(2),
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
