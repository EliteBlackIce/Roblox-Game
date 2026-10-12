--!strict
-- Helpers for constructing anchored, low-poly, solid-colour scenery from code.
-- Everything defaults to SmoothPlastic so the world reads as flat colour.

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
}

local function apply(part: BasePart, props: PartProps)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(160, 160, 160)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	if props.Transparency then
		part.Transparency = props.Transparency
	end
	if props.CanCollide ~= nil then
		part.CanCollide = props.CanCollide
	end
	if props.CastShadow ~= nil then
		part.CastShadow = props.CastShadow
	end
end

function Builder.part(parent: Instance, props: PartProps): Part
	local part = Instance.new("Part")
	part.Name = props.Name or "Part"
	if props.Shape then
		part.Shape = props.Shape
	end
	apply(part, props)
	part.Parent = parent
	return part
end

-- WedgePart: flat bottom, vertical back (+Z), slope facing front (-Z / LookVector).
function Builder.wedge(parent: Instance, props: PartProps): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = props.Name or "Wedge"
	apply(part, props)
	part.Parent = parent
	return part
end

-- Shorthand for a box at a position with an optional yaw (degrees).
function Builder.box(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, yaw: number?, material: Enum.Material?): Part
	return Builder.part(parent, {
		Name = name,
		Size = size,
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0),
		Color = color,
		Material = material,
	})
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

-- Four wedges back-to-back: a faceted low-poly pyramid / heap.
function Builder.pyramid(parent: Instance, name: string, base: Vector3, width: number, height: number, color: Color3, yaw: number?): { WedgePart }
	local wedges = {}
	for i = 0, 3 do
		local angle = math.rad((yaw or 0) + i * 90)
		local dir = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local center = base + dir * (width / 4) + Vector3.new(0, height / 2, 0)
		table.insert(
			wedges,
			Builder.wedge(parent, {
				Name = name,
				Size = Vector3.new(width, height, width / 2),
				CFrame = CFrame.lookAt(center, center + dir),
				Color = color,
			})
		)
	end
	return wedges
end

-- An angular rock: a tilted block topped with a wedge.
function Builder.rock(parent: Instance, base: Vector3, size: number, color: Color3, rng: Random)
	local yaw = rng:NextNumber(0, math.pi * 2)
	Builder.part(parent, {
		Name = "Rock",
		Size = Vector3.new(size, size * 0.6, size * 0.8),
		CFrame = CFrame.new(base + Vector3.new(0, size * 0.25, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), yaw, rng:NextNumber(-0.2, 0.2)),
		Color = color,
	})
	Builder.wedge(parent, {
		Name = "Rock",
		Size = Vector3.new(size * 0.9, size * 0.45, size * 0.6),
		CFrame = CFrame.new(base + Vector3.new(0, size * 0.75, 0)) * CFrame.Angles(0, yaw + 0.6, 0),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.12),
	})
end

-- Low-poly tree: square trunk and two stacked pyramids of leaves.
function Builder.tree(parent: Instance, base: Vector3, scale: number, leaves: Color3, rng: Random)
	local model = Builder.model(parent, "Tree")
	local yaw = rng:NextNumber(0, 90)
	Builder.box(model, "Trunk", Vector3.new(1.4, 6, 1.4) * scale, base + Vector3.new(0, 3 * scale, 0), Color3.fromRGB(120, 80, 50), yaw)
	Builder.pyramid(model, "Leaves", base + Vector3.new(0, 4 * scale, 0), 9 * scale, 7 * scale, leaves, yaw)
	Builder.pyramid(model, "Leaves", base + Vector3.new(0, 8.5 * scale, 0), 6.5 * scale, 6 * scale, leaves:Lerp(Color3.new(1, 1, 1), 0.1), yaw + 45)
end

-- Sign board with text on its front face. `facing` is the direction the text faces.
function Builder.sign(parent: Instance, text: string, position: Vector3, facing: Vector3, size: Vector2, background: Color3, textColor: Color3): Part
	local board = Builder.part(parent, {
		Name = "Sign",
		Size = Vector3.new(size.X, size.Y, 0.6),
		CFrame = CFrame.lookAt(position, position + facing),
		Color = background,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = textColor
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.5
	stroke.Parent = label
	return board
end

-- Floating label visible from a distance, used to guide players to key stations.
function Builder.billboard(adornee: BasePart, text: string, color: Color3, offsetY: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Marker"
	gui.Size = UDim2.fromOffset(240, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 220
	gui.LightInfluence = 0
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

-- Invisible part that holds a station's ProximityPrompt.
function Builder.anchor(parent: Instance, position: Vector3, size: number?): Part
	return Builder.part(parent, {
		Name = "PromptAnchor",
		Size = Vector3.one * (size or 2),
		CFrame = CFrame.new(position),
		Transparency = 1,
		CanCollide = false,
	})
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
