--!strict
-- Scrap Bot pets. Every pet follows one model sheet so the roster reads as a
-- single designed family rather than a pile of random shapes:
--
--   * Chibi proportions: a 2-stud head over a ~1.3-stud body (heads ~60% of
--     the height), stubby rounded limbs, no sharp boxes.
--   * Faces built the same way on every pet: big anime eyes (iris, pupil, two
--     highlights) at +-24 degrees, rosy blush, a small expressive mouth.
--   * Two body colours plus one accent, and one "personality prop" per pet
--     (wind-up key, propeller beanie, scarf, crown...).
--
-- Built around the origin (about 3 studs tall), facing -Z. Golden copies swap
-- the main colour for gold and sparkle. Rarer pets get glow and particles.

local Bots = require(script.Parent.Parent.Bots)
local Kit = require(script.Parent.Kit)

local BotArt = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local CN = CFrame.new
local ANG = CFrame.Angles
local V3 = Vector3.new
local rad = math.rad

local GOLD = rgb(255, 208, 64)
local INK = rgb(44, 40, 58)
local BLUSH = rgb(255, 150, 175)
local CREAM = rgb(255, 244, 222)
local WHITE = rgb(255, 255, 255)
local STEEL = rgb(200, 208, 225)

type Paint = { Body: Color3, Trim: Color3, Golden: boolean }
type Builder = (m: Model, p: Paint) -> ()
local B: { [string]: Builder } = {}

---------------------------------------------------------------- shared anatomy

type FaceOpts = {
	Eye: number?, -- eye diameter
	Spread: number?, -- yaw of each eye in degrees
	Height: number?, -- pitch of the eye line in degrees
	Iris: Color3?,
	Mouth: string?, -- "smile" | "open" | "cat" | "grin" | "o" | "none"
	Blush: boolean?,
	Brows: Color3?,
}

local function face(m: Model, head: CFrame, r: number, o: FaceOpts)
	local eye = o.Eye or r * 0.6
	local spread = o.Spread or 24
	local h = o.Height or 2
	local iris = o.Iris or rgb(70, 150, 255)
	for _, side in { -1, 1 } do
		Kit.cuteEye(m, Kit.onSphere(head, r, side * spread, h, eye * 0.3), eye, iris)
		if o.Blush ~= false then
			Kit.ball(m, Kit.onSphere(head, r, side * (spread + 20), h - 22, r * 0.13), r * 0.32, BLUSH)
		end
		if o.Brows then
			local brow = Kit.onSphere(head, r, side * spread, h + 26, r * 0.05)
			Kit.pill(m, brow * ANG(0, 0, rad(side * 12)), eye * 0.75, eye * 0.18, o.Brows)
		end
	end
	local mouth = o.Mouth or "smile"
	local dot = r * 0.1
	if mouth == "smile" or mouth == "grin" then
		local n = if mouth == "grin" then 4 else 2
		for t = -n, n do
			Kit.ball(m, Kit.onSphere(head, r, t * 5, h - 26 + (t * t) * (if mouth == "grin" then 0.9 else 1.8), dot * 0.35), dot, INK)
		end
	elseif mouth == "open" then
		Kit.ball(m, Kit.onSphere(head, r, 0, h - 27, r * 0.14), r * 0.34, INK)
		Kit.ball(m, Kit.onSphere(head, r, 0, h - 31, r * 0.1), r * 0.2, rgb(255, 110, 130))
	elseif mouth == "cat" then
		for _, side in { -1, 1 } do
			for t = 0, 2 do
				Kit.ball(m, Kit.onSphere(head, r, side * (t * 4.5 + 2), h - 25 - (if t == 1 then 2 else 0), dot * 0.35), dot * 0.9, INK)
			end
		end
	elseif mouth == "o" then
		Kit.ball(m, Kit.onSphere(head, r, 0, h - 26, r * 0.1), r * 0.18, INK)
	end
end

-- Little body under a head: torso, cream belly, arms and feet.
local function walkerBody(m: Model, body: Color3, belly: Color3?, y: number?)
	local base = y or -0.55
	Kit.ball(m, CN(0, base, 0.05), 1.35, body)
	-- Soft neck so the head melts into the body instead of perching on it.
	Kit.ball(m, CN(0, base + 0.5, 0.05), 1.05, body)
	if belly then
		Kit.ball(m, CN(0, base - 0.02, -0.22), 1.0, belly)
	end
	for _, side in { -1, 1 } do
		Kit.pillBetween(m, V3(side * 0.42, base + 0.2, 0), V3(side * 0.7, base - 0.08, -0.1), 0.42, body)
		Kit.ball(m, CN(side * 0.36, base - 0.6, -0.12), 0.6, Kit.shade(body, -0.18))
	end
end

local function antenna(m: Model, from: Vector3, to: Vector3, stem: Color3, tip: Color3, glow: boolean?)
	Kit.pillBetween(m, from, to, 0.12, stem)
	Kit.ball(m, CN(to), 0.36, tip, { Neon = glow })
end

local function sparkleOn(m: Model, at: Vector3, color: Color3, rate: number)
	Kit.sparkle(Kit.ball(m, CN(at), 0.1, color, { Transparency = 1 }), color, rate)
end

local HEAD = CN(0, 0.75, 0)
local R = 1.0

---------------------------------------------------------------- Rusty Crate

-- Wind-up toy robot: a squishy rounded-cube head, wind-up key on its back.
B.BoltBot = function(m, p)
	Kit.roundBox(m, HEAD, V3(2.1, 1.85, 1.9), 0.75, p.Body)
	face(m, HEAD * CN(0, 0, -0.05), 0.95, { Iris = rgb(60, 190, 220), Mouth = "smile", Spread = 22 })
	Kit.ball(m, HEAD * CN(0, -0.45, -0.62), 0.55, CREAM)
	Kit.pill(m, HEAD * CN(0, 0.98, 0) * ANG(0, 0, rad(90)), 0.5, 0.42, Kit.shade(p.Body, -0.25))
	Kit.ball(m, HEAD * CN(0, 1.2, 0), 0.42, p.Trim)
	for _, side in { -1, 1 } do
		Kit.ball(m, HEAD * CN(side * 1.05, 0, 0), 0.5, Kit.shade(p.Body, -0.2))
	end
	walkerBody(m, p.Body, CREAM)
	-- Wind-up key.
	Kit.pillBetween(m, V3(0, -0.45, 0.6), V3(0, -0.45, 1.1), 0.18, STEEL)
	for _, side in { -1, 1 } do
		Kit.ball(m, CN(side * 0.3, -0.45, 1.15), 0.42, STEEL)
	end
end

-- A tin can with a propeller beanie, floating along.
B.TinDrone = function(m, p)
	local can = CN(0, 0.2, 0)
	Kit.cylY(m, can, 2.0, 1.9, p.Body)
	for _, y in { -1.0, 1.0 } do
		Kit.ring(m, can * CN(0, y, 0), 0.92, 0.22, Kit.shade(p.Body, 0.25), 12)
		Kit.ball(m, can * CN(0, y * 0.9, 0), 1.6, p.Body)
	end
	Kit.cylY(m, can * CN(0, -0.35, 0), 0.55, 1.93, p.Trim)
	face(m, can * CN(0, 0.3, 0), 0.97, { Iris = rgb(90, 200, 120), Mouth = "open", Spread = 26, Height = 6 })
	-- Propeller beanie.
	Kit.ball(m, can * CN(0, 1.15, 0), 1.25, rgb(255, 210, 70))
	Kit.cylY(m, can * CN(0, 1.2, 0), 0.12, 1.4, rgb(80, 150, 255))
	Kit.cylY(m, can * CN(0, 1.85, 0), 0.4, 0.12, INK)
	for i = 0, 2 do
		Kit.pill(m, can * CN(0, 2.05, 0) * ANG(0, i * math.pi * 2 / 3, 0) * CN(0.55, 0, 0) * ANG(rad(15), 0, 0), 1.0, 0.18, if i == 0 then rgb(235, 80, 80) elseif i == 1 then rgb(80, 150, 255) else rgb(255, 210, 70))
	end
	for _, side in { -1, 1 } do
		Kit.ball(m, can * CN(side * 1.0, -0.2, 0), 0.4, Kit.shade(p.Body, -0.2))
	end
end

-- Ladybug with lightning-bolt antennae.
B.SparkBug = function(m, p)
	Kit.ball(m, HEAD, 2.0, p.Trim)
	face(m, HEAD, R, { Iris = rgb(255, 190, 40), Mouth = "grin" })
	-- Shell on the back with spots and a centre seam.
	Kit.ball(m, CN(0, -0.25, 0.55), 2.0, p.Body)
	Kit.pillBetween(m, V3(0, 0.75, 0.6), V3(0, -0.6, 1.5), 0.08, INK)
	for _, s in { { -0.55, 0.15, 1.3 }, { 0.6, 0.0, 1.35 }, { -0.4, -0.65, 1.35 }, { 0.45, -0.7, 1.3 }, { 0, 0.55, 1.15 } } do
		Kit.ball(m, CN(s[1], s[2], s[3]), 0.42, INK)
	end
	-- Zig-zag lightning antennae.
	for _, side in { -1, 1 } do
		local a = V3(side * 0.35, 1.6, -0.1)
		local b = V3(side * 0.6, 2.05, -0.25)
		local c = V3(side * 0.45, 2.3, -0.3)
		local d = V3(side * 0.75, 2.75, -0.45)
		Kit.pillBetween(m, a, b, 0.11, INK)
		Kit.pillBetween(m, b, c, 0.11, rgb(255, 230, 90), { Neon = true })
		Kit.pillBetween(m, c, d, 0.11, rgb(255, 230, 90), { Neon = true })
		Kit.ball(m, CN(d), 0.28, rgb(255, 245, 160), { Neon = true })
		for i = -1, 1 do
			Kit.pillBetween(m, V3(side * 0.75, -0.75, 0.4 + i * 0.45), V3(side * 1.1, -1.1, 0.35 + i * 0.5), 0.16, INK)
		end
	end
end

-- Caterpillar made of springy coils, wearing flight goggles.
B.CoilCrawler = function(m, p)
	for i = 0, 3 do
		local z = 0.55 + i * 0.75
		local d = 1.35 - i * 0.12
		local seg = CN(0, -0.55 + math.sin(i * 1.3) * 0.08, z)
		Kit.ball(m, seg, d, if i % 2 == 0 then p.Body else Kit.shade(p.Body, 0.15))
		Kit.ring(m, seg * ANG(rad(90), 0, 0), d * 0.5, 0.13, p.Trim, 12)
		for _, side in { -1, 1 } do
			Kit.ball(m, seg * CN(side * d * 0.33, -0.55, -0.05), 0.32, Kit.shade(p.Body, -0.25))
		end
	end
	Kit.ball(m, HEAD * CN(0, -0.1, -0.15), 2.0, p.Body)
	face(m, HEAD * CN(0, -0.1, -0.15), R, { Iris = rgb(140, 90, 40), Mouth = "smile" })
	-- Goggles pushed up on the forehead.
	Kit.pill(m, Kit.onSphere(HEAD * CN(0, -0.1, -0.15), R, 0, 32, 0.05) * ANG(0, rad(90), 0), 1.6, 0.18, INK)
	for _, side in { -1, 1 } do
		local lens = Kit.onSphere(HEAD * CN(0, -0.1, -0.15), R, side * 20, 34, -0.05)
		Kit.cylZ(m, lens, 0.18, 0.55, p.Trim)
		Kit.cylZ(m, lens * CN(0, 0, -0.06), 0.1, 0.38, rgb(170, 230, 255))
		antenna(m, V3(side * 0.35, 1.6, -0.2), V3(side * 0.6, 2.25, -0.35), INK, p.Trim)
	end
end

-- Chunky gorilla-bot: big arms, little head, gear in its tummy.
B.GearGolem = function(m, p)
	Kit.ball(m, CN(0, -0.25, 0.1), 2.0, p.Body)
	Kit.ball(m, CN(0, -0.3, -0.35), 1.45, Kit.shade(p.Body, 0.2))
	Kit.gear(m, CN(0, -0.3, -0.92) * ANG(0, rad(90), 0), 0.42, 0.18, 8, p.Trim, Kit.shade(p.Trim, -0.3))
	local head = CN(0, 1.05, -0.1)
	Kit.ball(m, head, 1.45, Kit.shade(p.Body, 0.08))
	face(m, head, 0.725, { Iris = p.Trim, Mouth = "o", Eye = 0.5, Spread = 26, Brows = INK })
	for _, side in { -1, 1 } do
		Kit.ball(m, CN(side * 1.05, 0.3, 0), 0.9, Kit.shade(p.Body, -0.1))
		Kit.pillBetween(m, V3(side * 1.15, 0.2, 0), V3(side * 1.3, -0.75, -0.15), 0.62, Kit.shade(p.Body, -0.1))
		Kit.ball(m, CN(side * 1.3, -0.95, -0.2), 0.85, p.Trim)
		Kit.ball(m, CN(side * 0.45, -1.15, 0), 0.7, Kit.shade(p.Body, -0.25))
	end
	antenna(m, V3(0, 1.75, -0.1), V3(0.25, 2.25, -0.1), INK, p.Trim, true)
end

-- SECRET: a raccoon-bot king of the junkyard, with crown, cape and scepter.
B.TrashKing = function(m, p)
	local head = HEAD * CN(0, 0.1, 0)
	Kit.ball(m, head, 2.1, p.Body)
	-- Raccoon mask and muzzle.
	for _, side in { -1, 1 } do
		Kit.ball(m, Kit.onSphere(head, 1.05, side * 24, 4, 0.32), 0.85, INK)
		Kit.ball(m, head * CN(side * 0.72, 0.85, 0.1), 0.75, p.Body)
		Kit.ball(m, head * CN(side * 0.72, 0.88, 0.0), 0.42, rgb(255, 180, 190))
	end
	Kit.ball(m, Kit.onSphere(head, 1.05, 0, -18, 0.2), 0.75, CREAM)
	Kit.ball(m, Kit.onSphere(head, 1.05, 0, -10, -0.12), 0.22, INK)
	face(m, head, 1.05, { Iris = rgb(255, 200, 60), Mouth = "grin", Blush = false, Height = 4 })
	-- Crown.
	Kit.cylY(m, head * CN(0, 1.05, 0), 0.5, 1.1, GOLD)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		Kit.softCone(m, head * CN(math.cos(a) * 0.45, 1.3, math.sin(a) * 0.45), 0.5, 0.3, GOLD)
		Kit.ball(m, head * CN(math.cos(a) * 0.45, 1.85, math.sin(a) * 0.45), 0.16, if i % 2 == 0 then rgb(255, 80, 120) else rgb(80, 200, 255), { Neon = true })
	end
	walkerBody(m, p.Body, CREAM, -0.6)
	-- Royal cape and striped tail.
	Kit.ball(m, CN(0, -0.45, 0.45), 1.55, rgb(200, 50, 80))
	Kit.ring(m, CN(0, 0.05, 0.1), 0.62, 0.22, CREAM, 10)
	for i = 0, 3 do
		Kit.ball(m, CN(0.35 + i * 0.15, -0.9 + i * 0.25, 0.95 + i * 0.12), 0.55 - i * 0.05, if i % 2 == 0 then INK else p.Body)
	end
	-- Scepter made of scrap.
	Kit.pillBetween(m, V3(0.85, -1.0, -0.3), V3(0.95, 0.6, -0.35), 0.14, GOLD)
	Kit.ball(m, CN(0.95, 0.75, -0.35), 0.45, rgb(80, 200, 255), { Neon = true })
	sparkleOn(m, V3(0, 1.9, 0), GOLD, 6)
end

---------------------------------------------------------------- Chrome Crate

local function puppy(m: Model, p: Paint, iris: Color3)
	Kit.ball(m, HEAD, 2.0, p.Body)
	face(m, HEAD, R, { Iris = iris, Mouth = "open", Height = 6 })
	Kit.ball(m, Kit.onSphere(HEAD, R, 0, -14, 0.35), 0.95, Kit.shade(p.Body, 0.12))
	Kit.ball(m, Kit.onSphere(HEAD, R, 0, -4, -0.1), 0.3, INK)
	-- Floppy ears.
	for _, side in { -1, 1 } do
		Kit.pillBetween(m, HEAD.Position + V3(side * 0.8, 0.55, 0.1), HEAD.Position + V3(side * 1.15, -0.25, 0.05), 0.55, p.Trim)
	end
	walkerBody(m, p.Body, WHITE)
	-- Collar with a bone tag, and a waggy tail.
	Kit.ring(m, CN(0, -0.05, 0.05), 0.6, 0.16, p.Trim, 10)
	Kit.pill(m, CN(0, -0.25, -0.62), 0.42, 0.16, GOLD)
	Kit.pillBetween(m, V3(0, -0.5, 0.65), V3(0, 0.05, 1.05), 0.22, p.Body)
	Kit.ball(m, CN(0, 0.1, 1.08), 0.32, p.Trim)
end

B.ChromePup = function(m, p)
	puppy(m, p, rgb(70, 140, 230))
end

-- A horseshoe magnet that grew legs and a face.
B.MagnetMite = function(m, p)
	local top = CN(0, 0.85, 0)
	for i = 0, 8 do
		local a = math.pi * i / 8
		Kit.ball(m, top * CN(math.cos(a) * 0.72, math.sin(a) * 0.72, 0), 0.95, p.Body)
	end
	for _, side in { -1, 1 } do
		Kit.cylY(m, CN(side * 0.72, 0.15, 0), 1.4, 0.95, p.Body)
		Kit.cylY(m, CN(side * 0.72, -0.7, 0), 0.4, 0.97, p.Trim)
		Kit.ball(m, CN(side * 0.72, -0.9, 0), 0.97, p.Trim)
		Kit.ball(m, CN(side * 0.72, -1.25, -0.05), 0.55, Kit.shade(p.Body, -0.25))
		Kit.pillBetween(m, V3(side * 0.72, -1.35, 0.05), V3(side * 0.72, -1.25, -0.4), 0.26, rgb(255, 240, 140), { Neon = true })
	end
	local head = CN(0, 1.15, -0.25)
	Kit.ball(m, head, 1.9, Kit.shade(p.Body, 0.08))
	face(m, head, 0.95, { Iris = rgb(90, 90, 230), Mouth = "smile" })
	Kit.sparkle(Kit.ball(m, CN(0, -1.3, 0), 0.1, WHITE, { Transparency = 1 }), rgb(255, 240, 140), 2)
end

-- Mini tank with its face on the turret.
B.TurboTank = function(m, p)
	for _, side in { -1, 1 } do
		Kit.pill(m, CN(side * 0.85, -0.95, 0) * ANG(0, rad(90), 0), 2.4, 0.75, INK)
		for z = -0.75, 0.75, 0.5 do
			Kit.cylZ(m, CN(side * 0.85, -0.95, z) * ANG(0, rad(90), 0), 0.8, 0.42, STEEL)
		end
	end
	Kit.roundBox(m, CN(0, -0.45, 0), V3(1.95, 0.7, 2.3), 0.33, Kit.shade(p.Body, -0.12))
	Kit.ball(m, HEAD * CN(0, -0.15, 0.1), 1.9, p.Body)
	face(m, HEAD * CN(0, -0.15, 0.1), 0.95, { Iris = rgb(60, 120, 60), Mouth = "grin", Brows = INK })
	Kit.pillBetween(m, V3(0, 0.95, -0.4), V3(0, 1.0, -1.45), 0.36, p.Trim)
	Kit.ball(m, CN(0, 1.0, -1.5), 0.48, Kit.shade(p.Trim, -0.2))
	Kit.cylY(m, HEAD * CN(0.35, 0.85, 0.3), 0.35, 0.45, p.Trim)
	Kit.ball(m, HEAD * CN(0.35, 1.05, 0.3), 0.3, rgb(255, 90, 90), { Neon = true })
end

-- Round owl with glowing ring eyes and tufted ears.
B.NeonOwl = function(m, p)
	Kit.ball(m, CN(0, 0.2, 0), 2.4, p.Body)
	Kit.ball(m, CN(0, -0.25, -0.55), 1.4, Kit.shade(p.Body, 0.35))
	local head = CN(0, 0.45, 0)
	for _, side in { -1, 1 } do
		local socket = Kit.onSphere(head, 1.2, side * 25, 2, 0.15)
		Kit.cylZ(m, socket * CN(0, 0, 0.05), 0.12, 0.95, p.Trim, { Neon = true })
		Kit.cuteEye(m, socket * CN(0, 0, -0.08), 0.72, rgb(255, 170, 40))
		-- Ear tufts made of three feathers.
		for i = 0, 2 do
			Kit.pillBetween(m, V3(side * (0.55 + i * 0.12), 1.25, 0.05), V3(side * (0.75 + i * 0.22), 1.75 - i * 0.12, 0.1), 0.2, Kit.shade(p.Body, -0.15))
		end
		-- Wings and feet.
		Kit.ball(m, CN(side * 1.1, 0.0, 0.15), 1.0, Kit.shade(p.Body, -0.15))
		Kit.ball(m, CN(side * 1.25, -0.35, 0.2), 0.7, Kit.shade(p.Body, -0.2))
		Kit.ball(m, CN(side * 0.4, -1.0, -0.15), 0.45, rgb(255, 170, 40))
	end
	Kit.softCone(m, Kit.onSphere(head, 1.2, 0, -12, 0.1) * ANG(rad(-90), 0, 0), 0.35, 0.32, rgb(255, 170, 40))
	Kit.ball(m, CN(0, -0.15, -1.05), 0.34, p.Trim, { Neon = true })
	sparkleOn(m, V3(0, 0.3, 0), p.Trim, 4)
end

-- SECRET: a mechanical phoenix with rainbow wings and a flaming crest.
B.PrismPhoenix = function(m, p)
	local rainbow = { rgb(255, 90, 90), rgb(255, 170, 60), rgb(255, 230, 80), rgb(90, 220, 120), rgb(80, 170, 255), rgb(170, 110, 255) }
	Kit.ball(m, HEAD, 1.9, p.Body)
	face(m, HEAD, 0.95, { Iris = rgb(255, 210, 60), Mouth = "none", Blush = true })
	Kit.softCone(m, Kit.onSphere(HEAD, 0.95, 0, -12, 0.05) * ANG(rad(-90), 0, 0), 0.45, 0.42, GOLD)
	-- Flame crest.
	for i = 0, 4 do
		Kit.pillBetween(m, V3(0, 1.55, 0.1 + i * 0.12), V3((i - 2) * 0.18, 2.35 + (2 - math.abs(i - 2)) * 0.25, 0.4 + i * 0.15), 0.24, rainbow[i + 1], { Neon = true })
	end
	Kit.ball(m, CN(0, -0.5, 0.15), 1.4, Kit.shade(p.Body, 0.1))
	Kit.ball(m, CN(0, -0.5, -0.2), 1.0, p.Trim)
	-- Rainbow wings: fanned feathers on each side.
	for _, side in { -1, 1 } do
		for i, color in rainbow do
			local angle = rad(10 + (i - 1) * 16)
			local base = V3(side * 0.6, -0.15, 0.3)
			local tip = base + V3(side * math.cos(angle) * 2.0, math.sin(angle) * 1.6, 0.35)
			Kit.pillBetween(m, base, tip, 0.32, color, { Neon = i % 2 == 0 })
		end
		Kit.pillBetween(m, V3(side * 0.3, -1.05, 0), V3(side * 0.35, -1.4, -0.2), 0.16, GOLD)
	end
	-- Tail streamers.
	for i, color in rainbow do
		Kit.pillBetween(m, V3(0, -0.7, 0.75), V3((i - 3.5) * 0.25, -1.3 - (i % 2) * 0.2, 1.9), 0.18, color, { Neon = true })
	end
	sparkleOn(m, V3(0, 0.6, 0.2), rgb(255, 220, 120), 12)
end

---------------------------------------------------------------- Galaxy Crate

-- Space pup in a bubble helmet with a plasma tail.
B.PlasmaPup = function(m, p)
	puppy(m, p, rgb(110, 240, 255))
	Kit.ball(m, HEAD * CN(0, 0.05, 0), 2.55, rgb(200, 240, 255), { Transparency = 0.6 })
	Kit.ring(m, HEAD * CN(0, -1.05, 0), 0.95, 0.2, STEEL, 12)
	antenna(m, HEAD.Position + V3(0.45, 1.15, 0.1), HEAD.Position + V3(0.6, 1.65, 0.1), STEEL, p.Trim, true)
	Kit.ball(m, CN(0, 0.1, 1.08), 0.45, p.Trim, { Neon = true })
end

-- Little dinosaur with a twin-rocket backpack.
B.RocketRaptor = function(m, p)
	local head = HEAD * CN(0, 0.05, -0.25)
	Kit.ball(m, head, 1.9, p.Body)
	Kit.ball(m, Kit.onSphere(head, 0.95, 0, -16, 0.35), 1.1, Kit.shade(p.Body, 0.12))
	face(m, head, 0.95, { Iris = rgb(255, 200, 60), Mouth = "grin", Height = 8 })
	for i = 0, 3 do
		Kit.softCone(m, CN(0, 1.55 - i * 0.38, 0.1 + i * 0.45) * ANG(rad(-25 - i * 14), 0, 0), 0.75, 0.42, p.Trim)
	end
	walkerBody(m, p.Body, CREAM)
	Kit.pillBetween(m, V3(0, -0.8, 0.6), V3(0, -0.6, 1.6), 0.45, p.Body)
	for _, side in { -1, 1 } do
		Kit.pill(m, CN(side * 0.45, -0.2, 0.75) * ANG(0, 0, rad(90)), 1.3, 0.5, STEEL)
		Kit.ring(m, CN(side * 0.45, 0.3, 0.75), 0.25, 0.1, rgb(235, 80, 80), 8)
		Kit.softCone(m, CN(side * 0.45, -0.9, 0.75) * ANG(rad(180), 0, 0), 0.55, 0.42, rgb(255, 170, 60), { Neon = true })
	end
end

-- A chubby living star with a sleepy-happy face and orbiting moons.
B.StarSentinel = function(m, p)
	local center = CN(0, 0.35, 0)
	Kit.ball(m, center, 1.9, p.Body)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		local tip = center.Position + V3(math.sin(a) * 1.55, math.cos(a) * 1.55, 0.1)
		Kit.pillBetween(m, center.Position, tip, 0.8, p.Body)
		Kit.ball(m, CN(tip), 0.6, Kit.shade(p.Body, 0.15))
	end
	face(m, center, 0.95, { Iris = p.Trim, Mouth = "smile" })
	Kit.ring(m, center * ANG(rad(70), 0, rad(15)), 1.9, 0.08, rgb(255, 240, 180), 16, { Neon = true })
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		Kit.ball(m, center * CN(math.cos(a) * 1.9, math.sin(a) * 0.5, math.sin(a) * 1.8), 0.38, if i == 0 then rgb(200, 210, 255) else p.Trim, { Neon = i ~= 0 })
	end
	sparkleOn(m, center.Position, rgb(255, 240, 160), 6)
end

-- A glowing spirit orb with a halo, wearing tiny crescent wings.
B.CosmicCore = function(m, p)
	local center = CN(0, 0.3, 0)
	Kit.ball(m, center, 2.0, p.Body, { Neon = true })
	Kit.ball(m, center * CN(0, 0, 0.05), 2.15, rgb(255, 200, 235), { Transparency = 0.55 })
	face(m, center, 1.0, { Iris = rgb(255, 90, 170), Mouth = "cat", Height = 0 })
	Kit.ring(m, center * CN(0, 1.4, 0), 0.6, 0.14, rgb(255, 230, 120), 12, { Neon = true })
	Kit.ring(m, center * ANG(rad(75), 0, rad(20)), 1.45, 0.12, p.Trim, 16, { Neon = true })
	Kit.ring(m, center * ANG(rad(75), rad(70), rad(-10)), 1.6, 0.1, rgb(140, 200, 255), 16, { Neon = true })
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			Kit.pillBetween(m, V3(side * 0.9, 0.4 - i * 0.2, 0.3), V3(side * (1.6 - i * 0.15), 0.9 - i * 0.35, 0.45), 0.24, rgb(255, 230, 250), { Neon = true })
		end
	end
	sparkleOn(m, center.Position, p.Trim, 10)
end

-- SECRET: a baby space whale full of stars, spouting a nebula.
B.NebulaWhale = function(m, p)
	local body = CN(0, 0.2, 0.3)
	Kit.ball(m, body, 2.4, p.Body)
	Kit.ball(m, body * CN(0, 0.1, -0.55), 2.0, p.Body)
	Kit.ball(m, body * CN(0, -0.45, -0.5), 1.8, Kit.shade(p.Trim, 0.45))
	face(m, body * CN(0, 0.1, -0.55), 1.0, { Iris = rgb(120, 230, 255), Mouth = "smile", Spread = 30 })
	-- Stars scattered over the back.
	for _, s in { { 0.5, 0.9, 0.6 }, { -0.6, 0.7, 0.9 }, { 0.1, 1.2, 0.2 }, { -0.3, 0.4, 1.35 }, { 0.75, 0.2, 1.2 } } do
		Kit.ball(m, CN(s[1], s[2], s[3]), 0.2, rgb(255, 245, 190), { Neon = true })
	end
	-- Flippers and tail fluke.
	for _, side in { -1, 1 } do
		Kit.pillBetween(m, V3(side * 1.0, -0.4, -0.2), V3(side * 1.55, -0.75, 0.1), 0.45, Kit.shade(p.Body, -0.1))
		Kit.pillBetween(m, V3(0, 0.3, 1.35), V3(side * 0.7, 0.75, 2.0), 0.5, Kit.shade(p.Body, -0.1))
	end
	-- Nebula spout.
	for i = 0, 4 do
		Kit.ball(m, CN(math.sin(i * 1.7) * 0.25, 1.55 + i * 0.32, 0.05 - i * 0.05), 0.42 - i * 0.04, if i % 2 == 0 then p.Trim else rgb(130, 200, 255), { Neon = true })
	end
	Kit.ring(m, body * ANG(rad(80), 0, 0), 1.9, 0.1, rgb(255, 200, 250), 16, { Neon = true })
	sparkleOn(m, body.Position, p.Trim, 12)
end

---------------------------------------------------------------- Gem Crate

-- Beetle with a gem-studded shell.
B.GemBeetle = function(m, p)
	Kit.ball(m, HEAD * CN(0, -0.15, -0.2), 1.8, p.Trim)
	face(m, HEAD * CN(0, -0.15, -0.2), 0.9, { Iris = p.Body, Mouth = "smile" })
	Kit.ball(m, CN(0, -0.3, 0.55), 2.1, p.Body)
	Kit.pillBetween(m, V3(0, 0.75, 0.55), V3(0, -0.45, 1.6), 0.08, p.Trim)
	for _, g in { { -0.5, 0.35, 1.25, 0.42 }, { 0.5, 0.35, 1.25, 0.42 }, { 0, 0.7, 0.95, 0.36 }, { -0.62, -0.25, 1.45, 0.32 }, { 0.62, -0.25, 1.45, 0.32 } } do
		Kit.ball(m, CN(g[1], g[2], g[3] - 0.05), g[4] * 1.15, rgb(170, 255, 230), { Neon = true })
	end
	for _, side in { -1, 1 } do
		antenna(m, V3(side * 0.3, 1.35, -0.4), V3(side * 0.55, 1.95, -0.6), p.Trim, p.Body, true)
		for i = -1, 1 do
			Kit.pillBetween(m, V3(side * 0.85, -0.85, 0.55 + i * 0.45), V3(side * 1.15, -1.2, 0.5 + i * 0.5), 0.16, p.Trim)
		end
	end
end

-- Cat with crystal ears and a faceted tail.
B.CrystalCat = function(m, p)
	Kit.ball(m, HEAD, 2.0, p.Body)
	face(m, HEAD, R, { Iris = p.Trim, Mouth = "cat" })
	Kit.ball(m, Kit.onSphere(HEAD, R, 0, -12, 0.0), 0.2, rgb(255, 140, 180))
	for _, side in { -1, 1 } do
		Kit.softCone(m, HEAD * CN(side * 0.5, 0.6, 0.05) * ANG(0, 0, rad(-side * 22)), 1.15, 0.62, p.Body)
		Kit.softCone(m, HEAD * CN(side * 0.5, 0.68, -0.12) * ANG(0, 0, rad(-side * 22)), 0.85, 0.34, rgb(190, 160, 255), { Neon = true })
		for i = 0, 1 do
			Kit.pillBetween(m, HEAD.Position + V3(side * 0.6, -0.2 - i * 0.12, -0.85), HEAD.Position + V3(side * 1.2, -0.1 - i * 0.22, -0.9), 0.05, INK)
		end
	end
	walkerBody(m, p.Body, WHITE)
	local prevTail = V3(0, -0.65, 0.6)
	for i = 1, 4 do
		local point = V3(0.15 * i, -0.6 + i * 0.35, 0.75 + i * 0.12)
		Kit.pillBetween(m, prevTail, point, 0.36 - i * 0.04, if i == 4 then p.Trim else p.Body, { Neon = i == 4 })
		prevTail = point
	end
	Kit.ball(m, CN(prevTail), 0.42, p.Trim, { Neon = true })
	sparkleOn(m, V3(0.4, 0.6, 1.2), p.Trim, 3)
end

-- Baby dragon with crystal horns, little wings and a diamond on its brow.
B.DiamondDragon = function(m, p)
	local head = HEAD * CN(0, 0.05, -0.15)
	Kit.ball(m, head, 1.95, p.Body)
	Kit.ball(m, Kit.onSphere(head, 0.97, 0, -18, 0.35), 1.05, Kit.shade(p.Body, 0.15))
	for _, side in { -1, 1 } do
		Kit.ball(m, Kit.onSphere(head, 0.97, side * 9, -14, -0.12), 0.14, INK)
	end
	face(m, head, 0.97, { Iris = p.Trim, Mouth = "none", Height = 10 })
	Kit.ball(m, Kit.onSphere(head, 0.97, 0, 32, 0.02), 0.38, WHITE, { Neon = true })
	walkerBody(m, p.Body, CREAM)
	for _, side in { -1, 1 } do
		Kit.softCone(m, head * CN(side * 0.5, 0.7, 0.25) * ANG(rad(-30), 0, rad(-side * 25)), 0.75, 0.32, rgb(200, 245, 255), { Neon = true })
		-- Wings: three rounded vanes each.
		for i = 0, 2 do
			Kit.pillBetween(m, V3(side * 0.5, -0.2, 0.55), V3(side * (1.35 + i * 0.1), 0.5 - i * 0.35, 0.8), 0.32, if i == 1 then p.Trim else Kit.shade(p.Body, 0.25))
		end
	end
	Kit.pillBetween(m, V3(0, -0.8, 0.6), V3(0.1, -0.55, 1.55), 0.4, p.Body)
	Kit.ball(m, CN(0.1, -0.5, 1.72), 0.4, p.Trim, { Neon = true })
	sparkleOn(m, head.Position + V3(0, 1, 0), rgb(180, 240, 255), 5)
end

-- SECRET: a rainbow cat with a prism collar who leaves glitter everywhere.
B.KaleidoKitty = function(m, p)
	local rainbow = { rgb(255, 110, 130), rgb(255, 180, 80), rgb(255, 235, 100), rgb(110, 225, 140), rgb(100, 180, 255), rgb(180, 130, 255) }
	Kit.ball(m, HEAD, 2.05, p.Body)
	face(m, HEAD, 1.025, { Iris = rgb(255, 110, 200), Mouth = "cat", Eye = 0.66 })
	-- Rainbow stripes across the head.
	for i, color in rainbow do
		if i <= 3 then
			Kit.ball(m, Kit.onSphere(HEAD, 1.025, (i - 2) * 16, 42, 0.12), 0.42, color)
		end
	end
	for _, side in { -1, 1 } do
		Kit.softCone(m, HEAD * CN(side * 0.5, 0.6, 0.05) * ANG(0, 0, rad(-side * 22)), 1.2, 0.64, p.Body)
		Kit.softCone(m, HEAD * CN(side * 0.5, 0.68, -0.12) * ANG(0, 0, rad(-side * 22)), 0.9, 0.36, p.Trim)
	end
	walkerBody(m, p.Body, WHITE)
	-- Prism collar.
	Kit.ring(m, CN(0, -0.05, 0.05), 0.62, 0.16, GOLD, 10)
	Kit.ball(m, CN(0, -0.28, -0.64), 0.4, WHITE, { Neon = true })
	-- Rainbow tail.
	local prev = V3(0, -0.6, 0.6)
	for i, color in rainbow do
		local nextPoint = V3(math.sin(i * 0.7) * 0.25, -0.6 + i * 0.32, 0.75 + i * 0.12)
		Kit.pillBetween(m, prev, nextPoint, 0.34, color, { Neon = i % 2 == 0 })
		prev = nextPoint
	end
	sparkleOn(m, V3(0, 0.5, 0.3), rgb(255, 200, 250), 14)
end

---------------------------------------------------------------- API

function BotArt.list(): { string }
	local ids = {}
	for _, bot in Bots.List do
		table.insert(ids, bot.Id)
	end
	return ids
end

-- Builds a bot model centred on the origin, facing -Z.
function BotArt.build(id: string, golden: boolean?): Model
	local def = Bots.ById[id]
	local model = Kit.model(nil, id)
	local paint: Paint = {
		Body = if golden then GOLD elseif def then def.Body else STEEL,
		Trim = if def then def.Trim else INK,
		Golden = golden == true,
	}
	local builder = B[id]
	if builder then
		builder(model, paint)
	else
		Kit.ball(model, HEAD, 2, paint.Body)
		face(model, HEAD, R, {})
		walkerBody(model, paint.Body, CREAM)
	end
	if golden then
		sparkleOn(model, V3(0, 0.8, 0), GOLD, 8)
	end
	return model
end

return BotArt
