--!strict
-- Crate opening, played in 3D right in front of the camera (client-only parts
-- under the Camera), escalating with the best rarity in the hatch:
--
--   every hatch   blur in -> crate drops and bounces -> charge pulses with
--                 rising pitch -> the crate shatters into pieces with a flash,
--                 shockwave and particles -> the pet pops out over 3D light rays
--   Epic          brighter pulses, coloured rays
--   Legendary /   an extra pulse that flashes the rarity colour, camera shake,
--   Mythic        a giant title slam and confetti
--   SECRET        the world goes dark, the crate floats up and rumbles while
--                 rainbow cracks spread over it, lightning strikes three times,
--                 then a rainbow explosion, "SECRET!!!", hue-cycling screen
--                 and a long confetti storm

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Art = ReplicatedStorage.Shared.Art
local BotArt = require(Art.BotArt)
local Bots = require(ReplicatedStorage.Shared.Bots)
local Config = require(ReplicatedStorage.Shared.Config)
local CrateArt = require(Art.CrateArt)
local Kit = require(Art.Kit)
local Effects = require(script.Parent.Parent.Effects)
local Theme = require(script.Parent.Theme)

local Hatch = {}

local CAMERA_PRIORITY = 201 -- just after Roblox's camera update
local overlay: Frame
local flash: Frame
local title: TextLabel
local nameLabel: TextLabel
local rarityLabel: TextLabel
local confettiLayer: Frame
local busy = false

---------------------------------------------------------------- helpers

local function camera(): Camera
	return Workspace.CurrentCamera :: Camera
end

local function rainbow(t: number): Color3
	return Color3.fromHSV(t % 1, 0.7, 1)
end

local function outBack(t: number): number
	local c = 1.7
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

-- Runs fn(t) every frame for `duration` seconds (t: 0 -> 1), yielding until done.
local function animate(duration: number, fn: (number) -> ())
	local start = os.clock()
	local done = false
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / duration, 1)
		fn(t)
		if t >= 1 then
			connection:Disconnect()
			done = true
		end
	end)
	while not done do
		task.wait()
	end
end

-- Camera shake applied after the normal camera update.
local shakeUntil, shakePower = 0, 0
local function shake(power: number, duration: number)
	shakePower = math.max(shakePower, power)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

type Puppet = { Model: Model, Parts: { BasePart }, Rel: { CFrame }, Size: { Vector3 } }

-- Records every part relative to the model's bounding-box centre so the whole
-- model can be moved and uniformly scaled each frame.
local function puppet(model: Model, parent: Instance): Puppet
	local lo, hi = Kit.extents(model)
	local center = CFrame.new((lo + hi) / 2)
	local parts, rel, size = {}, {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
			table.insert(parts, d)
			table.insert(rel, center:Inverse() * d.CFrame)
			table.insert(size, d.Size)
		end
	end
	model.Parent = parent
	return { Model = model, Parts = parts, Rel = rel, Size = size }
end

local function place(p: Puppet, cf: CFrame, scale: number)
	for i, part in p.Parts do
		local r = p.Rel[i]
		part.Size = p.Size[i] * scale
		part.CFrame = cf * CFrame.new(r.Position * scale) * (r - r.Position)
	end
end

local function holder(): Instance
	local folder = camera():FindFirstChild("HatchFX")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "HatchFX"
		folder.Parent = camera()
	end
	return folder :: Instance
end

local function emitter(position: Vector3, colors: { Color3 }, count: number, speed: number, size: number)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	part.Parent = holder()
	for _, color in colors do
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(color)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
		e.Speed = NumberRange.new(speed * 0.5, speed)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Lifetime = NumberRange.new(0.6, 1.4)
		e.Drag = 3
		e.Rate = 0
		e.Parent = part
		e:Emit(math.ceil(count / #colors))
	end
	task.delay(2, function()
		part:Destroy()
	end)
end

-- 3D light rays behind a reveal, facing the camera.
type Rays = { Parts: { BasePart }, Center: CFrame }
local function makeRays(count: number, color: Color3): { BasePart }
	local parts = {}
	for i = 1, count do
		local ray = Instance.new("Part")
		ray.Anchored = true
		ray.CanCollide = false
		ray.CanQuery = false
		ray.CastShadow = false
		ray.Material = Enum.Material.Neon
		ray.Color = color
		ray.Transparency = 0.55
		ray.Size = Vector3.new(0.55, 14, 0.05)
		ray.Parent = holder()
		parts[i] = ray
	end
	return parts
end

local function placeRays(parts: { BasePart }, center: CFrame, angle: number, scale: number)
	for i, ray in parts do
		local a = angle + (i - 1) / #parts * math.pi * 2
		ray.Size = Vector3.new(0.55 * scale, 14 * scale, 0.05)
		ray.CFrame = center * CFrame.Angles(0, 0, a) * CFrame.new(0, 7 * scale, 0)
	end
end

local function confetti(seconds: number, rainbowMode: boolean, color: Color3)
	local pieces = {}
	for i = 1, (if rainbowMode then 90 else 55) do
		local piece = Theme.create("Frame", {
			Size = UDim2.fromOffset(math.random(8, 16), math.random(12, 22)),
			Position = UDim2.new(math.random(), 0, -0.1 - math.random() * 0.6, 0),
			BackgroundColor3 = if rainbowMode then rainbow(i / 17) elseif i % 3 == 0 then Color3.new(1, 1, 1) else color,
			Rotation = math.random(0, 360),
			BorderSizePixel = 0,
			ZIndex = 45,
			Parent = confettiLayer,
		}, { Theme.corner(3) })
		table.insert(pieces, { Frame = piece, Speed = 0.25 + math.random() * 0.35, Spin = math.random(-400, 400), Sway = math.random() * 6 })
	end
	task.spawn(function()
		animate(seconds, function(t)
			for _, p in pieces do
				local pos = p.Frame.Position
				p.Frame.Position = UDim2.new(pos.X.Scale + math.sin(t * p.Sway * 6) * 0.0015, 0, pos.Y.Scale + p.Speed / 60, 0)
				p.Frame.Rotation += p.Spin / 60
			end
		end)
		for _, p in pieces do
			p.Frame:Destroy()
		end
	end)
end

local function slam(label: TextLabel, text: string, color: Color3)
	label.Text = text
	label.TextColor3 = color
	label.Visible = true
	label.TextTransparency = 0
	local scale = label:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 3
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

---------------------------------------------------------------- UI

function Hatch.init(screen: ScreenGui)
	overlay = Theme.create("Frame", {
		Name = "HatchOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
		Parent = screen,
	})
	-- A soft vignette using gradients on the top and bottom edges.
	for _, edge in { { 0, 0 }, { 1, 180 } } do
		Theme.create("Frame", {
			AnchorPoint = Vector2.new(0, edge[1]),
			Position = UDim2.fromScale(0, edge[1]),
			Size = UDim2.fromScale(1, 0.35),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 31,
			Parent = overlay,
		}, {
			Theme.create("UIGradient", {
				Rotation = 90 + edge[2],
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
			}),
		})
	end
	confettiLayer = Theme.create("Frame", { Name = "Confetti", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 45, Parent = overlay })
	flash = Theme.create("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 50, Parent = overlay })

	local function bigText(name: string, y: number, height: number, maxSize: number): TextLabel
		local label = Theme.create("TextLabel", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.new(0.9, 0, height, 0),
			BackgroundTransparency = 1,
			Font = Theme.TitleFont,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "",
			Visible = false,
			ZIndex = 46,
			Parent = overlay,
		}, {
			Theme.create("UIStroke", { Thickness = 5, Color = Color3.fromRGB(25, 20, 40) }),
			Theme.create("UITextSizeConstraint", { MaxTextSize = maxSize }),
			Theme.create("UIScale", {}),
		})
		return label
	end
	title = bigText("Title", 0.14, 0.16, 110)
	nameLabel = bigText("PetName", 0.8, 0.09, 64)
	rarityLabel = bigText("Rarity", 0.89, 0.06, 40)

	RunService:BindToRenderStep("HatchShake", CAMERA_PRIORITY, function()
		local now = os.clock()
		if now < shakeUntil then
			local p = shakePower * (shakeUntil - now)
			local cam = camera()
			cam.CFrame = cam.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * p * 4), math.rad((math.random() - 0.5) * p * 4), 0)
		else
			shakePower = 0
		end
	end)
end

---------------------------------------------------------------- the show

function Hatch.play(crateId: string, results: { { Uid: string, Id: string } })
	local crateDef = Bots.CrateById[crateId]
	if busy or not crateDef or #results == 0 then
		return
	end
	busy = true

	local best = Bots.ById[results[1].Id]
	for _, r in results do
		local bot = Bots.ById[r.Id]
		if Config.RarityById[bot.Rarity].Tier > Config.RarityById[best.Rarity].Tier then
			best = bot
		end
	end
	local bestRarity = Config.RarityById[best.Rarity]
	local tier = bestRarity.Tier
	local special = tier >= 4
	local secret = tier >= 6
	local color = if secret then rainbow(0) else bestRarity.Color

	-- Screen effects.
	overlay.Visible = true
	title.Visible, nameLabel.Visible, rarityLabel.Visible = false, false, false
	local blur = Instance.new("BlurEffect")
	blur.Name = "HatchBlur"
	blur.Size = 0
	blur.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "HatchGrade"
	grade.Parent = Lighting
	TweenService:Create(blur, TweenInfo.new(0.4), { Size = 14 }):Play()

	-- Crate(s) in front of the camera.
	local count = #results
	local spacing = if count > 1 then 4.4 else 0
	local distance = if count > 1 then 15 else 11
	local scale = if count > 1 then 0.5 else 0.62
	local crates: { Puppet } = {}
	for _ = 1, count do
		table.insert(crates, puppet(CrateArt.build(crateId), holder()))
	end
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 0
	light.Color = crateDef.Color
	light.Parent = crates[1].Parts[1]

	local function slot(i: number, lift: number, wobble: number, extraScale: number?): (CFrame, number)
		local x = (i - (count + 1) / 2) * spacing
		local cf = camera().CFrame * CFrame.new(x, -0.4 + lift, -distance) * CFrame.Angles(math.rad(-10), math.pi + math.rad(18), 0) * CFrame.Angles(0, 0, wobble)
		return cf, scale * (extraScale or 1)
	end

	-- 1. Drop in with a bounce.
	Effects.playSound(Config.Sounds.Hatch, 0.9)
	animate(0.5, function(t)
		for i, p in crates do
			local cf, s = slot(i, (1 - outBack(t)) * 7, 0)
			place(p, cf, s)
		end
	end)

	-- 2. Charge pulses.
	local pulses = if special then 4 else 3
	for pulse = 1, pulses do
		local amp = math.rad(4 + pulse * 4)
		local pulseColor = if pulse == pulses and tier >= 3 then color else crateDef.Color
		animate(0.5, function(t)
			light.Brightness = (pulse - 1 + t) * 1.2
			light.Color = pulseColor
			for i, p in crates do
				local cf, s = slot(i, math.sin(t * math.pi) * 0.4, math.sin(t * 34) * amp * (1 - t * 0.3), 1 + math.sin(t * math.pi) * 0.12)
				place(p, cf, s)
			end
		end)
		for i in crates do
			local cf = slot(i, 0, 0)
			emitter(cf.Position, { pulseColor, Color3.new(1, 1, 1) }, 18 + pulse * 6, 10, 0.35)
		end
		Effects.playSound(Config.Sounds.Rare, 0.7 + pulse * 0.18)
		if pulse == pulses and special then
			flash.BackgroundColor3 = color
			flash.BackgroundTransparency = 0.6
			TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			shake(0.6, 0.35)
		end
	end

	-- 2b. SECRET: blackout, rumble, rainbow cracks and lightning.
	if secret then
		TweenService:Create(grade, TweenInfo.new(0.5), { Brightness = -0.45, Saturation = -0.7 }):Play()
		TweenService:Create(overlay, TweenInfo.new(0.5), { BackgroundTransparency = 0.35 }):Play()
		slam(title, "? ? ?", Color3.new(1, 1, 1))
		local cracks = {}
		for k = 1, 14 do
			local crack = Instance.new("Part")
			crack.Anchored = true
			crack.CanCollide = false
			crack.CanQuery = false
			crack.Material = Enum.Material.Neon
			crack.Transparency = 1
			crack.Size = Vector3.new(0.12, 1.4 + math.random() * 1.2, 0.12)
			crack.Parent = holder()
			cracks[k] = { Part = crack, Offset = CFrame.new((math.random() - 0.5) * 3.2, 2 + (math.random() - 0.5) * 2.4, -1.9) * CFrame.Angles(0, 0, (math.random() - 0.5) * 2.4), Appear = k / 15 }
		end
		local strikes = { 0.3, 0.6, 0.85 }
		local struck = 0
		animate(2.4, function(t)
			light.Color = rainbow(t * 3)
			light.Brightness = 6
			for i, p in crates do
				local cf, s = slot(i, t * 1.4, math.sin(t * 60) * math.rad(3 + t * 6), 1 + t * 0.15)
				place(p, cf, s)
				if i == 1 then
					for k, c in cracks do
						c.Part.Transparency = if t >= c.Appear then 0 else 1
						c.Part.Color = rainbow(t * 2 + k * 0.07)
						c.Part.CFrame = cf * CFrame.new(0, -2.6 * s, 0) * CFrame.new(c.Offset.Position * s) * (c.Offset - c.Offset.Position)
					end
				end
			end
			if struck < #strikes and t >= strikes[struck + 1] then
				struck += 1
				flash.BackgroundColor3 = Color3.new(1, 1, 1)
				flash.BackgroundTransparency = 0
				TweenService:Create(flash, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
				shake(1.2, 0.4)
				Effects.playSound(Config.Sounds.Collect, 0.35)
			end
			title.TextColor3 = rainbow(t * 2)
			title.Rotation = math.sin(t * 50) * 4 * t
		end)
		title.Rotation = 0
		for _, c in cracks do
			c.Part:Destroy()
		end
	end

	-- 3. Explosion: the crate shatters.
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0
	TweenService:Create(flash, TweenInfo.new(if special then 0.6 else 0.35), { BackgroundTransparency = 1 }):Play()
	shake(if secret then 2 elseif special then 1.2 else 0.4, if special then 0.6 else 0.3)
	Effects.playSound(Config.Sounds.Collect, 0.45)
	Effects.playSound(Config.Sounds.Rare, 1.5)
	TweenService:Create(grade, TweenInfo.new(0.4), { Brightness = 0, Saturation = if secret then 0.4 else 0.15 }):Play()
	title.Visible = false

	local shards = {}
	for _, p in crates do
		for i, part in p.Parts do
			table.insert(shards, {
				Part = part,
				Start = part.CFrame,
				Velocity = (part.Position - p.Parts[1].Position).Unit * (8 + math.random() * 10) + Vector3.new(0, 6, 0),
				Spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 12,
				Base = p.Size[i],
			})
		end
	end
	local burstColors = if secret then { rainbow(0), rainbow(0.2), rainbow(0.4), rainbow(0.6), rainbow(0.8) } else { color, crateDef.Color, Color3.new(1, 1, 1) }
	for i in crates do
		local cf = slot(i, 0, 0)
		emitter(cf.Position, burstColors, if special then 160 else 80, if special then 34 else 22, if special then 0.8 else 0.55)
	end
	-- Shockwave disc facing the camera.
	local wave = Instance.new("Part")
	wave.Anchored = true
	wave.CanCollide = false
	wave.CanQuery = false
	wave.Shape = Enum.PartType.Cylinder
	wave.Material = Enum.Material.Neon
	wave.Color = color
	wave.Parent = holder()
	task.spawn(function()
		animate(0.5, function(t)
			local center = slot(1, 0, 0)
			local d = 2 + t * (if special then 22 else 14)
			wave.Size = Vector3.new(0.1, d, d)
			wave.CFrame = CFrame.lookAt(center.Position, camera().CFrame.Position) * CFrame.Angles(0, math.rad(90), 0)
			wave.Transparency = 0.2 + t * 0.8
			if secret then
				wave.Color = rainbow(t * 2)
			end
		end)
		wave:Destroy()
	end)
	animate(0.55, function(t)
		for _, s in shards do
			local pos = s.Start.Position + s.Velocity * t + Vector3.new(0, -14 * t * t, 0)
			s.Part.CFrame = CFrame.new(pos) * CFrame.Angles(s.Spin.X * t, s.Spin.Y * t, s.Spin.Z * t) * (s.Start - s.Start.Position)
			s.Part.Size = s.Base * (1 - t * 0.7)
			s.Part.Transparency = t
		end
	end)
	for _, p in crates do
		p.Model:Destroy()
	end

	-- 4. Reveal.
	local pets: { Puppet } = {}
	local rays: { { BasePart } } = {}
	for i, r in results do
		pets[i] = puppet(BotArt.build(r.Id), holder())
		local rarity = Config.RarityById[Bots.ById[r.Id].Rarity]
		rays[i] = makeRays(if rarity.Tier >= 4 then 14 else 10, if rarity.Tier >= 6 then rainbow(0) else rarity.Color)
		emitter(slot(i, 0, 0).Position, { rarity.Color, Color3.new(1, 1, 1) }, 30, 6, 0.4)
	end
	slam(nameLabel, if count == 1 then best.Name else `{best.Name} + {count - 1} more`, Color3.new(1, 1, 1))
	slam(rarityLabel, bestRarity.Name, color)
	if special then
		slam(title, if secret then "SECRET!!!" else string.upper(bestRarity.Name) .. "!", color)
		confetti(if secret then 5 else 3, secret, color)
		shake(if secret then 1 else 0.5, 0.5)
		Effects.playSound(Config.Sounds.Rare, 1.8)
	end

	local hold = if secret then 5.5 elseif special then 3.8 else 2.6
	local petScale = if count > 1 then 0.75 else 1.05
	animate(hold, function(t)
		local pop = outBack(math.min(t * hold / 0.5, 1))
		for i, p in pets do
			local cf = slot(i, 0.3 + math.sin(t * hold * 2) * 0.15, 0)
			place(p, cf * CFrame.Angles(0, t * hold * (if special then 2.2 else 1.4), 0), petScale * pop)
			local rayCenter = CFrame.lookAt(cf.Position, camera().CFrame.Position) * CFrame.new(0, 0, -2.5)
			placeRays(rays[i], rayCenter, t * hold * 0.6, (if count > 1 then 0.55 else 0.85) * pop)
			if secret then
				for k, ray in rays[i] do
					ray.Color = rainbow(t * 2 + k / #rays[i])
				end
			end
		end
		if secret then
			grade.TintColor = rainbow(t * 3):Lerp(Color3.new(1, 1, 1), 0.65)
			title.TextColor3 = rainbow(t * 4)
			rarityLabel.TextColor3 = rainbow(t * 4 + 0.3)
		end
		if special then
			local titleScale = title:FindFirstChildOfClass("UIScale") :: UIScale
			if t * hold > 0.4 then
				titleScale.Scale = 1 + math.sin(t * hold * 6) * 0.05
			end
		end
	end)

	-- 5. Out.
	TweenService:Create(blur, TweenInfo.new(0.3), { Size = 0 }):Play()
	TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	for _, label in { title, nameLabel, rarityLabel } do
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	end
	animate(0.3, function(t)
		for i, p in pets do
			place(p, slot(i, 0.3, 0) * CFrame.Angles(0, t * 6, 0), petScale * (1 - t))
		end
	end)
	holder():ClearAllChildren()
	blur:Destroy()
	grade:Destroy()
	overlay.Visible = false
	title.Visible, nameLabel.Visible, rarityLabel.Visible = false, false, false
	busy = false
end

function Hatch.isBusy(): boolean
	return busy
end

return Hatch
