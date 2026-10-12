--!strict
-- Shows a 3D model inside a ViewportFrame with a camera fitted to it, like the
-- pet/item cards in Pet Simulator.

local Kit = require(game:GetService("ReplicatedStorage").Shared.Art.Kit)

local Viewport = {}

export type Options = {
	Silhouette: boolean?, -- black shape for undiscovered things
	Yaw: number?, -- degrees around the model
	Pitch: number?,
	Zoom: number?, -- >1 moves the camera closer
}

local function blacken(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = Color3.fromRGB(25, 25, 32)
			d.Material = Enum.Material.SmoothPlastic
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		end
	end
end

-- Points `camera` at `model` so the whole model fits.
function Viewport.fit(camera: Camera, model: Instance, opts: Options?)
	local lo, hi = Kit.extents(model)
	local center = (lo + hi) / 2
	local radius = (hi - lo).Magnitude / 2
	local yaw = math.rad((opts and opts.Yaw) or 25)
	local pitch = math.rad((opts and opts.Pitch) or 15)
	local fov = 30
	local distance = radius / math.sin(math.rad(fov / 2)) / ((opts and opts.Zoom) or 1)
	local dir = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(center + dir * distance, center)
end

-- Creates a ViewportFrame showing `model` (which it takes ownership of).
function Viewport.new(parent: Instance, model: Model, props: { [string]: any }?, opts: Options?): ViewportFrame
	local frame = Instance.new("ViewportFrame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Ambient = Color3.fromRGB(170, 170, 185)
	frame.LightColor = Color3.fromRGB(255, 250, 240)
	frame.LightDirection = Vector3.new(-0.5, -1, -0.6)
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	if opts and opts.Silhouette then
		blacken(model)
	end
	model.Parent = frame
	local camera = Instance.new("Camera")
	camera.Parent = frame
	frame.CurrentCamera = camera
	Viewport.fit(camera, model, opts)
	frame.Parent = parent
	return frame
end

return Viewport
