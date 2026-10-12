--!strict
-- 3D models for the 16 Scrap Bots: cute, chunky robots with big cartoon eyes.
-- Built around the origin (roughly 3 studs tall), facing -Z. Golden copies swap
-- the body colour for gold and gain sparkles.

local Bots = require(script.Parent.Parent.Bots)
local Kit = require(script.Parent.Kit)

local BotArt = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local GOLD = rgb(255, 205, 55)
local DARK = rgb(50, 52, 62)
local STEEL = rgb(190, 196, 210)
local WHITE = rgb(250, 250, 255)
local CN = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

type Paint = { Body: Color3, Trim: Color3, Accent: Color3 }
type Builder = (m: Model, p: Paint) -> ()
local B: { [string]: Builder } = {}

local function eyes(m: Model, y: number, z: number, spacing: number, size: number, iris: Color3?)
	Kit.eye(m, CN(-spacing / 2, y, z), size, iris)
	Kit.eye(m, CN(spacing / 2, y, z), size, iris)
end

local function feet(m: Model, color: Color3, spacing: number, y: number)
	for _, x in { -spacing / 2, spacing / 2 } do
		Kit.roundBox(m, CN(x, y, -0.1), Vector3.new(0.7, 0.4, 0.9), 0.18, color, nil, false)
	end
end

local function antenna(m: Model, base: Vector3, height: number, stem: Color3, tip: Color3)
	Kit.cylY(m, CN(base + Vector3.new(0, height / 2, 0)), height, 0.12, stem)
	Kit.ball(m, CN(base + Vector3.new(0, height, 0)), 0.35, tip, { Neon = true })
end

---------------------------------------------------------------- Rusty Crate

B.BoltBot = function(m, p)
	Kit.roundBox(m, CN(0, 0.1, 0), Vector3.new(2.0, 1.9, 1.8), 0.5, p.Body)
	eyes(m, 0.35, -0.85, 0.75, 0.6)
	Kit.box(m, CN(0, -0.3, -0.9), Vector3.new(0.6, 0.12, 0.05), DARK)
	for _, x in { -1.1, 1.1 } do
		Kit.ball(m, CN(x, 0.1, 0), 0.45, p.Trim)
	end
	-- A big hex bolt on top of the head.
	Kit.cylY(m, CN(0, 1.15, 0), 0.25, 0.5, p.Trim)
	Kit.box(m, CN(0, 1.4, 0), Vector3.new(0.75, 0.3, 0.65), p.Trim)
	Kit.box(m, CN(0, 1.4, 0) * ANG(0, rad(60), 0), Vector3.new(0.75, 0.3, 0.65), p.Trim)
	Kit.box(m, CN(0, 1.4, 0) * ANG(0, rad(-60), 0), Vector3.new(0.75, 0.3, 0.65), p.Trim)
	feet(m, Kit.shade(p.Body, -0.3), 1.0, -1.0)
	Kit.ball(m, CN(-0.55, -0.05, -0.86), 0.28, rgb(255, 150, 150))
	Kit.ball(m, CN(0.55, -0.05, -0.86), 0.28, rgb(255, 150, 150))
end

B.TinDrone = function(m, p)
	Kit.ball(m, CN(0, 0, 0), 2.0, p.Body)
	Kit.cylY(m, CN(0, -0.1, 0), 0.25, 2.1, p.Trim)
	eyes(m, 0.25, -0.8, 0.7, 0.55)
	Kit.cylY(m, CN(0, 1.05, 0), 0.4, 0.2, DARK)
	Kit.cylY(m, CN(0, 1.25, 0), 0.12, 0.35, DARK)
	for i = 0, 1 do
		Kit.roundBox(m, CN(0, 1.3, 0) * ANG(0, i * math.pi / 2 + rad(20), 0), Vector3.new(2.4, 0.08, 0.35), 0.04, Kit.shade(p.Trim, 0.2), nil, false)
	end
	for _, x in { -1.05, 1.05 } do
		Kit.ball(m, CN(x, -0.1, 0), 0.3, p.Trim, { Neon = true })
	end
	Kit.cylY(m, CN(0, -1.05, 0), 0.2, 0.6, DARK)
end

B.SparkBug = function(m, p)
	Kit.ball(m, CN(0, 0.1, 0.2), 2.0, p.Body)
	Kit.box(m, CN(0, 0.6, 0.2), Vector3.new(0.08, 1.0, 2.0), DARK)
	for _, s in { { -0.55, 0.75, 0.4 }, { 0.6, 0.6, 0.6 }, { -0.4, 0.3, 0.95 }, { 0.45, 0.85, -0.1 } } do
		Kit.ball(m, CN(s[1], s[2], s[3]), 0.42, p.Trim)
	end
	Kit.ball(m, CN(0, 0, -0.85), 1.3, p.Trim)
	eyes(m, 0.15, -1.35, 0.55, 0.5)
	for _, side in { -1, 1 } do
		Kit.cylY(m, CN(side * 0.35, 0.85, -1.0) * ANG(rad(-25), 0, rad(-side * 25)), 0.8, 0.08, p.Trim)
		Kit.ball(m, CN(side * 0.55, 1.2, -1.2), 0.25, rgb(255, 240, 120), { Neon = true })
		for i = -1, 1 do
			Kit.cyl(m, CN(side * 0.95, -0.65, 0.2 + i * 0.5) * ANG(0, 0, rad(side * -30)), 0.6, 0.12, p.Trim)
		end
	end
end

B.CoilCrawler = function(m, p)
	for i = 0, 3 do
		local d = 1.4 - i * 0.18
		Kit.ball(m, CN(0, -0.2 + i * 0.08, 0.2 + i * 0.85), d, if i % 2 == 0 then p.Body else Kit.shade(p.Body, 0.15))
		Kit.ring(m, CN(0, -0.2 + i * 0.08, 0.2 + i * 0.85) * ANG(rad(90), 0, 0), d * 0.5, 0.14, p.Trim, 10, nil, false)
		for _, side in { -1, 1 } do
			Kit.ball(m, CN(side * d * 0.4, -0.85, 0.2 + i * 0.85), 0.3, Kit.shade(p.Body, -0.35))
		end
	end
	Kit.ball(m, CN(0, 0.2, -0.75), 1.6, p.Body)
	eyes(m, 0.35, -1.45, 0.6, 0.55)
	Kit.box(m, CN(0, -0.1, -1.55), Vector3.new(0.4, 0.1, 0.05), DARK)
	antenna(m, Vector3.new(0, 0.9, -0.7), 0.6, p.Trim, p.Trim)
end

B.GearGolem = function(m, p)
	Kit.roundBox(m, CN(0, 0, 0), Vector3.new(2.4, 2.0, 1.7), 0.45, p.Body)
	Kit.roundBox(m, CN(0, 1.35, -0.1), Vector3.new(1.3, 0.9, 1.2), 0.3, Kit.shade(p.Body, 0.1))
	Kit.box(m, CN(0, 1.4, -0.71), Vector3.new(0.95, 0.3, 0.05), DARK)
	Kit.box(m, CN(-0.22, 1.4, -0.74), Vector3.new(0.2, 0.16, 0.03), p.Trim, { Neon = true })
	Kit.box(m, CN(0.22, 1.4, -0.74), Vector3.new(0.2, 0.16, 0.03), p.Trim, { Neon = true })
	Kit.gear(m, CN(0, 0.05, -0.88) * ANG(0, rad(90), 0), 0.6, 0.2, 8, p.Trim, Kit.shade(p.Trim, -0.3))
	for _, side in { -1, 1 } do
		Kit.ball(m, CN(side * 1.35, 0.55, 0), 0.75, Kit.shade(p.Body, -0.15))
		Kit.pill(m, CN(side * 1.5, -0.2, 0) * ANG(0, 0, rad(90)), 1.3, 0.6, Kit.shade(p.Body, -0.15))
		Kit.roundBox(m, CN(side * 1.5, -0.95, -0.05), Vector3.new(0.8, 0.6, 0.8), 0.2, p.Trim, nil, false)
	end
	feet(m, Kit.shade(p.Body, -0.35), 1.1, -1.15)
end

---------------------------------------------------------------- Chrome Crate

local function dog(m: Model, p: Paint, glow: boolean)
	Kit.pill(m, CN(0, -0.35, 0.35) * ANG(0, rad(90), 0), 1.9, 1.15, p.Body)
	Kit.roundBox(m, CN(0, 0.5, -0.65), Vector3.new(1.6, 1.3, 1.3), 0.45, p.Body)
	Kit.roundBox(m, CN(0, 0.25, -1.3), Vector3.new(0.8, 0.5, 0.4), 0.18, Kit.shade(p.Body, 0.15), nil, false)
	Kit.ball(m, CN(0, 0.35, -1.52), 0.28, DARK)
	eyes(m, 0.7, -1.28, 0.62, 0.45, if glow then p.Trim else nil)
	for _, side in { -1, 1 } do
		Kit.wedge(m, CN(side * 0.55, 1.35, -0.6) * ANG(0, rad(180), rad(side * 12)), Vector3.new(0.35, 0.6, 0.5), p.Trim)
		for _, z in { -0.2, 0.9 } do
			Kit.cylY(m, CN(side * 0.4, -1.0, z), 0.55, 0.32, Kit.shade(p.Body, -0.2))
			Kit.ball(m, CN(side * 0.4, -1.25, z - 0.05), 0.4, p.Trim)
		end
	end
	Kit.cylY(m, CN(0, 0.15, 1.2) * ANG(rad(35), 0, 0), 0.8, 0.12, p.Trim)
	Kit.ball(m, CN(0, 0.5, 1.45), 0.3, p.Trim, { Neon = glow })
	Kit.cylY(m, CN(0, 0.05, -0.15), 0.18, 1.2, p.Trim, { Neon = glow })
end

B.ChromePup = function(m, p)
	dog(m, p, false)
end

B.MagnetMite = function(m, p)
	-- Horseshoe magnet with a face.
	for _, side in { -1, 1 } do
		Kit.cylY(m, CN(side * 0.75, -0.1, 0), 1.4, 0.8, p.Body)
		Kit.cylY(m, CN(side * 0.75, -0.95, 0), 0.4, 0.82, p.Trim)
	end
	for i = 0, 6 do
		local a = i / 6 * math.pi
		Kit.ball(m, CN(math.cos(a) * 0.75, 0.6 + math.sin(a) * 0.75, 0), 0.82, p.Body)
	end
	eyes(m, 1.15, -0.42, 0.55, 0.45)
	for _, side in { -1, 1 } do
		Kit.box(m, CN(side * 0.75, -1.35, 0), Vector3.new(0.1, 0.3, 0.1), rgb(255, 240, 120), { Neon = true })
	end
	Kit.sparkle(Kit.ball(m, CN(0, -1.2, 0), 0.2, rgb(255, 240, 120), { Neon = true }), rgb(255, 240, 120), 2)
end

B.TurboTank = function(m, p)
	for _, side in { -1, 1 } do
		Kit.pill(m, CN(side * 0.85, -0.75, 0) * ANG(0, rad(90), 0), 2.4, 0.7, DARK)
		for z = -0.8, 0.8, 0.4 do
			Kit.cylZ(m, CN(side * 0.85, -0.75, z) * ANG(0, rad(90), 0), 0.75, 0.3, STEEL)
		end
	end
	Kit.roundBox(m, CN(0, -0.15, 0), Vector3.new(1.9, 0.7, 2.2), 0.25, p.Body)
	Kit.roundBox(m, CN(0, 0.55, 0.1), Vector3.new(1.4, 0.8, 1.4), 0.35, Kit.shade(p.Body, 0.1))
	Kit.cylZ(m, CN(0, 0.6, -1.05), 1.0, 0.32, p.Trim)
	Kit.cylZ(m, CN(0, 0.6, -1.55), 0.15, 0.42, Kit.shade(p.Trim, -0.2))
	eyes(m, 0.75, -0.6, 0.6, 0.42)
	Kit.cylY(m, CN(0.45, 1.05, 0.4), 0.3, 0.3, p.Trim)
end

B.NeonOwl = function(m, p)
	Kit.ball(m, CN(0, -0.1, 0), 2.1, p.Body)
	Kit.ball(m, CN(0, -0.4, -0.6), 1.2, Kit.shade(p.Body, 0.3))
	for _, side in { -1, 1 } do
		Kit.cylZ(m, CN(side * 0.42, 0.35, -0.78), 0.2, 0.8, p.Trim, { Neon = true })
		Kit.eye(m, CN(side * 0.42, 0.35, -0.86), 0.55, rgb(255, 160, 40))
		Kit.wedge(m, CN(side * 0.55, 1.05, 0) * ANG(0, 0, rad(side * -20)), Vector3.new(0.3, 0.6, 0.5), p.Trim)
		Kit.roundBox(m, CN(side * 1.05, -0.1, 0.1) * ANG(0, 0, rad(side * 12)), Vector3.new(0.3, 1.3, 1.1), 0.14, Kit.shade(p.Body, -0.2), nil, false)
		Kit.ball(m, CN(side * 0.35, -1.15, -0.2), 0.35, rgb(255, 170, 40))
	end
	Kit.wedge(m, CN(0, 0.0, -1.05) * ANG(rad(180), 0, 0), Vector3.new(0.3, 0.35, 0.3), rgb(255, 170, 40))
	Kit.sparkle(Kit.ball(m, CN(0, 0, 0), 0.2, p.Trim, { Neon = true }), p.Trim, 4)
end

---------------------------------------------------------------- Galaxy Crate

B.PlasmaPup = function(m, p)
	dog(m, p, true)
	Kit.sparkle(Kit.ball(m, CN(0, -0.3, 0.35), 0.5, p.Body, { Neon = true }), p.Body, 3)
end

B.RocketRaptor = function(m, p)
	Kit.pill(m, CN(0, -0.2, 0.3) * ANG(0, rad(90), rad(-15)), 2.0, 1.3, p.Body)
	Kit.roundBox(m, CN(0, 0.75, -0.7), Vector3.new(1.3, 1.1, 1.6), 0.4, p.Body)
	Kit.roundBox(m, CN(0, 0.45, -1.45), Vector3.new(1.0, 0.45, 0.7), 0.2, Kit.shade(p.Body, 0.1), nil, false)
	for x = -0.3, 0.3, 0.3 do
		Kit.wedge(m, CN(x, 0.18, -1.6) * ANG(rad(180), 0, 0), Vector3.new(0.14, 0.18, 0.12), WHITE)
	end
	eyes(m, 1.0, -1.4, 0.6, 0.45)
	for i = 0, 2 do
		Kit.wedge(m, CN(0, 1.3 - i * 0.25, -0.4 + i * 0.5), Vector3.new(0.12, 0.45, 0.45), p.Trim)
	end
	for _, side in { -1, 1 } do
		Kit.cylY(m, CN(side * 0.45, -1.05, 0.4), 0.7, 0.4, Kit.shade(p.Body, -0.2))
		Kit.roundBox(m, CN(side * 0.45, -1.35, 0.25), Vector3.new(0.5, 0.25, 0.75), 0.1, Kit.shade(p.Body, -0.3), nil, false)
		-- Rocket boosters with flames.
		Kit.cylY(m, CN(side * 0.55, 0.15, 1.05), 1.0, 0.45, STEEL)
		Kit.cone(m, CN(side * 0.55, -0.35, 1.05) * ANG(rad(180), 0, 0), 0.6, 0.4, rgb(255, 150, 40), 3, { Neon = true })
	end
	Kit.cylY(m, CN(0, -0.7, 1.3) * ANG(rad(-60), 0, 0), 1.0, 0.35, p.Body)
end

B.StarSentinel = function(m, p)
	Kit.ball(m, CN(0, 0, 0), 2.1, p.Body)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		Kit.wedge(m, CN(0, 0, -1.0) * ANG(0, 0, a) * CN(0, 0.42, 0), Vector3.new(0.35, 0.55, 0.12), p.Trim, { Neon = true })
	end
	Kit.ball(m, CN(0, 0, -1.0), 0.6, p.Trim, { Neon = true })
	Kit.eye(m, CN(0, 0, -1.1), 0.42, DARK)
	Kit.ring(m, CN(0, 0, 0) * ANG(rad(15), 0, rad(-20)), 1.45, 0.14, p.Trim, 14, { Neon = true }, false)
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		Kit.ball(m, CN(math.cos(a) * 1.45, math.sin(a) * 0.3, math.sin(a) * 1.4), 0.3, p.Trim, { Neon = true })
	end
	Kit.sparkle(Kit.ball(m, CN(0, 0, 0), 0.3, p.Trim, { Neon = true }), p.Trim, 6)
end

B.CosmicCore = function(m, p)
	Kit.ball(m, CN(0, 0, 0), 1.7, p.Body, { Neon = true })
	eyes(m, 0.15, -0.72, 0.55, 0.42)
	Kit.ring(m, CN(0, 0, 0) * ANG(rad(70), 0, 0), 1.2, 0.14, p.Trim, 14, { Neon = true }, false)
	Kit.ring(m, CN(0, 0, 0) * ANG(rad(70), rad(60), 0), 1.35, 0.12, rgb(140, 200, 255), 14, { Neon = true }, false)
	Kit.ring(m, CN(0, 1.25, 0), 0.5, 0.12, rgb(255, 230, 120), 12, { Neon = true }, false)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Kit.box(m, CN(math.cos(a) * 1.6, math.sin(i) * 0.4, math.sin(a) * 1.6) * ANG(rad(45), rad(45), 0), Vector3.new(0.22, 0.22, 0.22), p.Trim, { Neon = true })
	end
	Kit.sparkle(Kit.ball(m, CN(0, 0, 0), 0.4, p.Trim, { Neon = true }), p.Trim, 10)
end

---------------------------------------------------------------- Gem Crate

B.GemBeetle = function(m, p)
	Kit.ball(m, CN(0, -0.3, 0.2), 1.9, Kit.shade(p.Trim, 0.05))
	-- Shell studded with faceted gems.
	Kit.ball(m, CN(0, 0.05, 0.3), 1.75, Kit.shade(p.Body, -0.35))
	Kit.box(m, CN(0, 0.55, 0.3), Vector3.new(0.08, 1.0, 1.7), Kit.shade(p.Body, -0.55))
	for _, g in { { -0.45, 0.75, 0.15, 0.5 }, { 0.45, 0.75, 0.15, 0.5 }, { -0.5, 0.55, 0.75, 0.42 }, { 0.5, 0.55, 0.75, 0.42 }, { 0, 0.85, 0.55, 0.36 }, { -0.75, 0.2, 0.45, 0.32 }, { 0.75, 0.2, 0.45, 0.32 } } do
		Kit.box(m, CN(g[1], g[2], g[3]) * ANG(rad(45), rad(45), 0), Vector3.one * g[4], p.Body, { Neon = g[4] < 0.4 })
	end
	Kit.ball(m, CN(0, -0.25, -0.85), 1.1, p.Trim)
	eyes(m, -0.1, -1.3, 0.5, 0.42)
	for _, side in { -1, 1 } do
		Kit.cylY(m, CN(side * 0.25, 0.4, -1.05) * ANG(rad(-35), 0, rad(-side * 20)), 0.7, 0.08, p.Trim)
		Kit.box(m, CN(side * 0.4, 0.75, -1.3) * ANG(rad(45), rad(45), 0), Vector3.new(0.2, 0.2, 0.2), p.Body, { Neon = true })
		for i = -1, 1 do
			Kit.cyl(m, CN(side * 0.95, -0.95, 0.2 + i * 0.5) * ANG(0, 0, rad(side * -30)), 0.6, 0.12, p.Trim)
		end
	end
	Kit.sparkle(Kit.ball(m, CN(0, 0.3, 0.3), 0.2, p.Body, { Neon = true }), p.Body, 3)
end

B.CrystalCat = function(m, p)
	Kit.pill(m, CN(0, -0.55, 0.35) * ANG(0, rad(90), 0), 1.6, 1.1, p.Body)
	Kit.roundBox(m, CN(0, 0.45, -0.45), Vector3.new(1.6, 1.3, 1.3), 0.5, p.Body)
	for _, side in { -1, 1 } do
		Kit.wedge(m, CN(side * 0.5, 1.3, -0.45) * ANG(0, 0, rad(side * 15)), Vector3.new(0.4, 0.55, 0.45), Kit.shade(p.Body, 0.2))
		Kit.wedge(m, CN(side * 0.5, 1.22, -0.55) * ANG(0, 0, rad(side * 15)), Vector3.new(0.2, 0.3, 0.1), rgb(255, 170, 200))
		Kit.cylY(m, CN(side * 0.35, -1.05, -0.2), 0.4, 0.35, p.Body)
		Kit.cylY(m, CN(side * 0.35, -1.05, 0.85), 0.4, 0.35, p.Body)
		for i = 0, 1 do
			Kit.box(m, CN(side * (0.7 + i * 0.15), 0.25 - i * 0.12, -1.12), Vector3.new(0.45, 0.04, 0.04), DARK)
		end
	end
	eyes(m, 0.55, -1.08, 0.6, 0.45, rgb(80, 180, 255))
	Kit.wedge(m, CN(0, 0.25, -1.12) * ANG(rad(180), 0, 0), Vector3.new(0.22, 0.14, 0.1), rgb(255, 150, 190))
	-- Crystal tail.
	for i = 0, 2 do
		Kit.box(m, CN(0, -0.1 + i * 0.45, 1.15 + i * 0.12) * ANG(rad(-20), rad(45), 0), Vector3.new(0.35, 0.5, 0.35) * (1 - i * 0.15), p.Trim, { Neon = true })
	end
	Kit.sparkle(Kit.ball(m, CN(0, 0.9, 1.4), 0.2, p.Trim, { Neon = true }), p.Trim, 4)
end

B.DiamondDragon = function(m, p)
	Kit.pill(m, CN(0, -0.3, 0.3) * ANG(0, rad(90), rad(-12)), 1.9, 1.3, p.Body)
	Kit.roundBox(m, CN(0, 0.75, -0.6), Vector3.new(1.3, 1.15, 1.3), 0.45, p.Body)
	Kit.roundBox(m, CN(0, 0.55, -1.3), Vector3.new(0.9, 0.55, 0.6), 0.22, Kit.shade(p.Body, 0.12), nil, false)
	for _, x in { -0.2, 0.2 } do
		Kit.ball(m, CN(x, 0.62, -1.62), 0.12, DARK)
	end
	eyes(m, 1.0, -1.22, 0.6, 0.42)
	for _, side in { -1, 1 } do
		Kit.cone(m, CN(side * 0.4, 1.3, -0.45) * ANG(rad(-25), 0, rad(-side * 20)), 0.6, 0.3, p.Trim, 3)
		-- Wings: three stacked wedges per side.
		for i = 0, 2 do
			Kit.wedge(m, CN(side * (0.9 + i * 0.45), 0.6 + i * 0.25, 0.55) * ANG(0, rad(side * 90), rad(side * 25)), Vector3.new(0.1, 0.9 - i * 0.15, 1.0 - i * 0.2), if i == 1 then p.Trim else Kit.shade(p.Body, 0.25))
		end
		Kit.cylY(m, CN(side * 0.45, -1.1, 0.3), 0.5, 0.4, Kit.shade(p.Body, -0.2))
	end
	Kit.box(m, CN(0, 1.45, -0.6) * ANG(rad(45), rad(45), 0), Vector3.new(0.4, 0.4, 0.4), WHITE, { Neon = true })
	Kit.cylY(m, CN(0, -0.55, 1.35) * ANG(rad(-70), 0, 0), 1.2, 0.35, p.Body)
	Kit.box(m, CN(0, -0.3, 1.95) * ANG(rad(45), 0, 0), Vector3.new(0.12, 0.45, 0.45), p.Trim)
	Kit.sparkle(Kit.ball(m, CN(0, 1.45, -0.6), 0.2, WHITE, { Neon = true }), rgb(160, 240, 255), 5)
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
		Trim = if def then def.Trim else DARK,
		Accent = WHITE,
	}
	local builder = B[id]
	if builder then
		builder(model, paint)
	else
		Kit.roundBox(model, CFrame.new(), Vector3.new(2, 2, 2), 0.5, paint.Body)
		eyes(model, 0.3, -0.95, 0.7, 0.55)
	end
	if golden then
		local sparkleBase = Kit.ball(model, CFrame.new(0, 0.5, 0), 0.1, GOLD, { Neon = true, Transparency = 1 })
		Kit.sparkle(sparkleBase, GOLD, 6)
	end
	return model
end

return BotArt
