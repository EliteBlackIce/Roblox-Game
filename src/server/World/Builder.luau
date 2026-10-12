--!strict
-- Small helpers for constructing anchored scenery from code.

local Builder = {}

export type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	CanCollide: boolean?,
	CastShadow: boolean?,
	Reflectance: number?,
}

function Builder.part(parent: Instance, props: PartProps): Part
	local part = Instance.new("Part")
	part.Name = props.Name or "Part"
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(120, 120, 120)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Reflectance = props.Reflectance or 0
	if props.CanCollide ~= nil then
		part.CanCollide = props.CanCollide
	end
	if props.CastShadow ~= nil then
		part.CastShadow = props.CastShadow
	end
	part.Parent = parent
	return part
end

function Builder.wedge(parent: Instance, props: PartProps): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = props.Name or "Wedge"
	part.Anchored = true
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(120, 120, 120)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	if props.CanCollide ~= nil then
		part.CanCollide = props.CanCollide
	end
	part.Parent = parent
	return part
end

function Builder.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Builder.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Upright cylinder (Roblox cylinders run along X, so rotate onto Y).
function Builder.cylinder(parent: Instance, name: string, position: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?): Part
	return Builder.part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

-- A thin slab lying on the ground between two points.
function Builder.path(parent: Instance, from: Vector3, to: Vector3, width: number, color: Color3, material: Enum.Material, height: number?): Part
	local flatFrom = Vector3.new(from.X, 0, from.Z)
	local flatTo = Vector3.new(to.X, 0, to.Z)
	local length = (flatTo - flatFrom).Magnitude
	local mid = (flatFrom + flatTo) / 2
	local y = height or 0.05
	return Builder.part(parent, {
		Name = "Path",
		Size = Vector3.new(width, 0.2, length + width * 0.5),
		CFrame = CFrame.lookAt(mid + Vector3.new(0, y, 0), flatTo + Vector3.new(0, y, 0)),
		Color = color,
		Material = material,
		CastShadow = false,
	})
end

-- Sign board with text on its front face. `facing` is the direction the text faces.
function Builder.sign(parent: Instance, text: string, position: Vector3, facing: Vector3, size: Vector2, background: Color3, textColor: Color3): Part
	local board = Builder.part(parent, {
		Name = "Sign",
		Size = Vector3.new(size.X, size.Y, 0.4),
		CFrame = CFrame.lookAt(position, position + facing),
		Color = background,
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = textColor
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.4
	stroke.Parent = label
	return board
end

-- Floating label visible from a distance, used to guide players to key stations.
function Builder.billboard(adornee: BasePart, text: string, color: Color3, offsetY: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Marker"
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
end

function Builder.prompt(anchor: BasePart, name: string, action: string, object: string, hold: number, distance: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = distance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = anchor
	return prompt
end

return Builder
