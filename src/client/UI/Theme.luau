--!strict
-- Shared colors, fonts and a tiny instance factory for the UI modules.

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(32, 30, 36),
	PanelLight = Color3.fromRGB(48, 45, 54),
	Stroke = Color3.fromRGB(15, 14, 18),
	Text = Color3.fromRGB(245, 242, 235),
	SubText = Color3.fromRGB(185, 180, 170),
	Cash = Color3.fromRGB(110, 230, 110),
	Accent = Color3.fromRGB(245, 190, 40),
	Good = Color3.fromRGB(70, 190, 90),
	Bad = Color3.fromRGB(220, 70, 60),
	Disabled = Color3.fromRGB(90, 88, 95),
	Info = Color3.fromRGB(70, 140, 230),
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

function Theme.textStroke(): UIStroke
	return Theme.create("UIStroke", { Thickness = 2, Color = Theme.Colors.Stroke, Transparency = 0.2 })
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

return Theme
