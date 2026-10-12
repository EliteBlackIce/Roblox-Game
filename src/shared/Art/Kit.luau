--!strict
-- Art kit: primitives for the chunky, rounded "toy" look used by every model in
-- the game (scrap items, bots, crates, tools, stations and props).
--
-- All builders create anchored, solid-colour SmoothPlastic parts (Neon for
-- glow) that don't collide unless asked. Cylinders run along their CFrame's
-- local X axis; use cylY / cylZ for other axes.

local Kit = {}

export type Opts = {
	Name: string?,
	Neon: boolean?,
	Collide: boolean?,
	Transparency: number?,
	Shadow: boolean?,
}

local RIGHT_TO_UP = CFrame.Angles(0, 0, math.rad(90))
local RIGHT_TO_BACK = CFrame.Angles(0, math.rad(90), 0)

function Kit.shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

local function make(className: string, parent: Instance, cf: CFrame, size: Vector3, color: Color3, opts: Opts?): BasePart
	local part = Instance.new(className) :: BasePart
	part.Name = (opts and opts.Name) or "Part"
	part.Anchored = true
	part.CanCollide = opts ~= nil and opts.Collide == true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = if opts and opts.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if opts and opts.Transparency then
		part.Transparency = opts.Transparency
	end
	if opts and (opts.Shadow == false or opts.Neon) then
		part.CastShadow = false
	end
	part.Parent = parent
	return part
end

function Kit.box(parent: Instance, cf: CFrame, size: Vector3, color: Color3, opts: Opts?): Part
	return make("Part", parent, cf, size, color, opts) :: Part
end

function Kit.ball(parent: Instance, cf: CFrame, diameter: number, color: Color3, opts: Opts?): Part
	local p = make("Part", parent, cf, Vector3.one * diameter, color, opts) :: Part
	p.Shape = Enum.PartType.Ball
	return p
end

function Kit.cyl(parent: Instance, cf: CFrame, length: number, diameter: number, color: Color3, opts: Opts?): Part
	local p = make("Part", parent, cf, Vector3.new(length, diameter, diameter), color, opts) :: Part
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Upright cylinder (axis along cf's Y).
function Kit.cylY(parent: Instance, cf: CFrame, height: number, diameter: number, color: Color3, opts: Opts?): Part
	return Kit.cyl(parent, cf * RIGHT_TO_UP, height, diameter, color, opts)
end

-- Cylinder along cf's Z (facing the viewer, e.g. wheels seen from the side).
function Kit.cylZ(parent: Instance, cf: CFrame, length: number, diameter: number, color: Color3, opts: Opts?): Part
	return Kit.cyl(parent, cf * RIGHT_TO_BACK, length, diameter, color, opts)
end

function Kit.wedge(parent: Instance, cf: CFrame, size: Vector3, color: Color3, opts: Opts?): WedgePart
	return make("WedgePart", parent, cf, size, color, opts) :: WedgePart
end

-- Capsule along cf's X axis.
function Kit.pill(parent: Instance, cf: CFrame, length: number, diameter: number, color: Color3, opts: Opts?)
	local body = math.max(0.01, length - diameter)
	Kit.cyl(parent, cf, body, diameter, color, opts)
	Kit.ball(parent, cf * CFrame.new(body / 2, 0, 0), diameter, color, opts)
	Kit.ball(parent, cf * CFrame.new(-body / 2, 0, 0), diameter, color, opts)
end

-- Box with every edge and corner rounded (radius r). 23 parts, or 15 without
-- corner balls; use for hero objects.
function Kit.roundBox(parent: Instance, cf: CFrame, size: Vector3, r: number, color: Color3, opts: Opts?, corners: boolean?)
	r = math.min(r, size.X / 2, size.Y / 2, size.Z / 2)
	local d = r * 2
	local inner = size - Vector3.one * d
	Kit.box(parent, cf, Vector3.new(size.X, inner.Y, inner.Z), color, opts)
	Kit.box(parent, cf, Vector3.new(inner.X, size.Y, inner.Z), color, opts)
	Kit.box(parent, cf, Vector3.new(inner.X, inner.Y, size.Z), color, opts)
	local hx, hy, hz = inner.X / 2, inner.Y / 2, inner.Z / 2
	for _, sy in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.cyl(parent, cf * CFrame.new(0, sy * hy, sz * hz), inner.X, d, color, opts)
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.cylY(parent, cf * CFrame.new(sx * hx, 0, sz * hz), inner.Y, d, color, opts)
		end
		for _, sy in { -1, 1 } do
			Kit.cylZ(parent, cf * CFrame.new(sx * hx, sy * hy, 0), inner.Z, d, color, opts)
		end
	end
	if corners ~= false then
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					Kit.ball(parent, cf * CFrame.new(sx * hx, sy * hy, sz * hz), d, color, opts)
				end
			end
		end
	end
end

-- Box with only its vertical edges rounded (flat top and bottom). 6 parts;
-- cheap enough for buildings and platforms.
function Kit.roundSlab(parent: Instance, cf: CFrame, size: Vector3, r: number, color: Color3, opts: Opts?)
	r = math.min(r, size.X / 2, size.Z / 2)
	local d = r * 2
	Kit.box(parent, cf, Vector3.new(size.X - d, size.Y, size.Z), color, opts)
	Kit.box(parent, cf, Vector3.new(size.X, size.Y, size.Z - d), color, opts)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.cylY(parent, cf * CFrame.new(sx * (size.X / 2 - r), 0, sz * (size.Z / 2 - r)), size.Y, d, color, opts)
		end
	end
end

-- Torus-like ring lying in cf's XZ plane (around cf's Y axis).
function Kit.ring(parent: Instance, cf: CFrame, radius: number, thickness: number, color: Color3, segments: number?, opts: Opts?, smooth: boolean?)
	local n = segments or 12
	local chord = 2 * radius * math.sin(math.pi / n)
	for i = 0, n - 1 do
		local angle = (i + 0.5) / n * math.pi * 2
		local at = cf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius * math.cos(math.pi / n))
		Kit.cyl(parent, at, chord + thickness * 0.15, thickness, color, opts)
		if smooth ~= false then
			Kit.ball(parent, cf * CFrame.Angles(0, i / n * math.pi * 2, 0) * CFrame.new(0, 0, -radius), thickness, color, opts)
		end
	end
end

-- Cartoon eye looking along cf's LookVector: white, pupil and a sparkle.
function Kit.eye(parent: Instance, cf: CFrame, size: number, iris: Color3?)
	Kit.ball(parent, cf, size, Color3.fromRGB(255, 255, 255), { Name = "Eye" })
	Kit.ball(parent, cf * CFrame.new(0, -size * 0.04, -size * 0.3), size * 0.58, iris or Color3.fromRGB(25, 25, 35), { Name = "Pupil" })
	Kit.ball(parent, cf * CFrame.new(size * 0.12, size * 0.12, -size * 0.52), size * 0.2, Color3.fromRGB(255, 255, 255), { Name = "Sparkle", Neon = true })
end

-- CFrame on a sphere's surface (centre, radius) facing outward. yaw/pitch in
-- degrees, measured from the sphere's front (-Z). `inset` pushes it inward.
function Kit.onSphere(center: CFrame, radius: number, yaw: number, pitch: number, inset: number?): CFrame
	local a, b = math.rad(yaw), math.rad(pitch)
	local dir = Vector3.new(math.sin(a) * math.cos(b), math.sin(b), -math.cos(a) * math.cos(b))
	local worldDir = center:VectorToWorldSpace(dir)
	local pos = center.Position + worldDir * (radius - (inset or 0))
	return CFrame.lookAt(pos, pos + worldDir)
end

-- Capsule stretched between two points.
function Kit.pillBetween(parent: Instance, a: Vector3, b: Vector3, diameter: number, color: Color3, opts: Opts?)
	local length = (b - a).Magnitude
	if length < 1e-3 then
		Kit.ball(parent, CFrame.new(a), diameter, color, opts)
		return
	end
	Kit.pill(parent, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), length + diameter, diameter, color, opts)
end

-- Big expressive anime-style eye looking along cf's LookVector: white, coloured
-- iris, pupil and two highlights.
function Kit.cuteEye(parent: Instance, cf: CFrame, size: number, iris: Color3)
	Kit.ball(parent, cf, size, Color3.fromRGB(255, 255, 255), { Name = "Eye" })
	Kit.ball(parent, cf * CFrame.new(0, -size * 0.04, -size * 0.2), size * 0.74, iris, { Name = "Iris" })
	Kit.ball(parent, cf * CFrame.new(0, -size * 0.06, -size * 0.3), size * 0.5, Color3.fromRGB(28, 26, 40), { Name = "Pupil" })
	Kit.ball(parent, cf * CFrame.new(size * 0.14, size * 0.16, -size * 0.52), size * 0.24, Color3.fromRGB(255, 255, 255), { Name = "Shine", Neon = true })
	Kit.ball(parent, cf * CFrame.new(-size * 0.12, -size * 0.16, -size * 0.5), size * 0.11, Color3.fromRGB(255, 255, 255), { Name = "Shine", Neon = true })
end

-- Gear standing in cf's YZ plane (axis along cf's X).
function Kit.gear(parent: Instance, cf: CFrame, radius: number, thickness: number, teeth: number, color: Color3, hub: Color3?)
	Kit.cyl(parent, cf, thickness, radius * 1.7, color)
	for i = 0, teeth - 1 do
		local angle = i / teeth * math.pi * 2
		Kit.box(parent, cf * CFrame.Angles(angle, 0, 0) * CFrame.new(0, radius * 0.92, 0), Vector3.new(thickness, radius * 0.38, radius * 0.36), color)
	end
	Kit.cyl(parent, cf, thickness * 1.25, radius * 0.6, hub or Kit.shade(color, -0.25))
end

-- Coin standing in cf's YZ plane (face along cf's X).
function Kit.coin(parent: Instance, cf: CFrame, diameter: number, color: Color3, opts: Opts?)
	Kit.cyl(parent, cf, diameter * 0.16, diameter, Kit.shade(color, -0.15), opts)
	Kit.cyl(parent, cf, diameter * 0.2, diameter * 0.74, color, opts)
	Kit.box(parent, cf, Vector3.new(diameter * 0.24, diameter * 0.42, diameter * 0.12), Kit.shade(color, 0.35), opts)
end

-- Row of rivets between two points.
function Kit.rivets(parent: Instance, from: Vector3, to: Vector3, count: number, diameter: number, color: Color3)
	for i = 0, count - 1 do
		local t = if count == 1 then 0.5 else i / (count - 1)
		Kit.ball(parent, CFrame.new(from:Lerp(to, t)), diameter, color, { Name = "Rivet" })
	end
end

-- Stack of cylinders narrowing upward (a rounded cone), base at cf.
function Kit.cone(parent: Instance, cf: CFrame, height: number, diameter: number, color: Color3, steps: number?, opts: Opts?)
	local n = steps or 4
	for i = 0, n - 1 do
		local h = height / n
		local d = diameter * (1 - i / n)
		Kit.cylY(parent, cf * CFrame.new(0, h * (i + 0.5), 0), h, d, color, opts)
	end
end

-- Smooth tapered spike (ears, horns, beaks) made of overlapping balls along
-- cf's Y axis, base at cf.
function Kit.softCone(parent: Instance, cf: CFrame, height: number, diameter: number, color: Color3, opts: Opts?)
	-- Teardrop: a round base, a slimmer middle and a capsule tip.
	Kit.ball(parent, cf * CFrame.new(0, diameter / 2, 0), diameter, color, opts)
	local mid = math.max(diameter * 0.75, height * 0.42)
	Kit.ball(parent, cf * CFrame.new(0, mid, 0), diameter * 0.7, color, opts)
	local tipD = diameter * 0.38
	Kit.pillBetween(parent, (cf * CFrame.new(0, mid, 0)).Position, (cf * CFrame.new(0, height - tipD / 2, 0)).Position, tipD, color, opts)
end

-- Low sparkle particle, for anything that should read as valuable.
function Kit.sparkle(part: BasePart, color: Color3, rate: number?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkle"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = rate or 2
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(0.4, 1)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 1
	emitter.Color = ColorSequence.new(color)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = part
end

-- Wraps loose parts built at the origin into a Model with a PrimaryPart.
function Kit.model(parent: Instance?, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	if parent then
		model.Parent = parent
	end
	return model
end

-- Bounding size of every part in a model (for fitting cameras and pickups).
function Kit.extents(model: Instance): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			local cf = part.CFrame
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
						lo = Vector3.new(math.min(lo.X, corner.X), math.min(lo.Y, corner.Y), math.min(lo.Z, corner.Z))
						hi = Vector3.new(math.max(hi.X, corner.X), math.max(hi.Y, corner.Y), math.max(hi.Z, corner.Z))
					end
				end
			end
		end
	end
	return lo, hi
end

-- Uniformly scales every part of a model around `pivot` (sizes and offsets).
function Kit.scale(model: Instance, factor: number, pivot: Vector3?)
	local origin = pivot or Vector3.zero
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local current = part.CFrame
			local offset = current.Position - origin
			part.Size *= factor
			part.CFrame = current - current.Position + origin + offset * factor
		elseif part:IsA("ParticleEmitter") then
			part.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * factor), NumberSequenceKeypoint.new(1, 0) })
		end
	end
end

-- Moves a model built around the origin so its footprint centre sits on `cf`
-- (bottom touching cf's position), rotated by cf.
function Kit.placeOnGround(model: Instance, cf: CFrame)
	local lo, hi = Kit.extents(model)
	local shift = CFrame.new(-(lo.X + hi.X) / 2, -lo.Y, -(lo.Z + hi.Z) / 2)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = cf * shift * part.CFrame
		end
	end
end

-- Moves a model built around the origin so its origin lands on `cf`.
function Kit.transform(model: Instance, cf: CFrame)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = cf * part.CFrame
		end
	end
end

return Kit
