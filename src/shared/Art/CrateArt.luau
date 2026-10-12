--!strict
-- 3D models for the four Scrap Bot crates (the game's "eggs"). Built with the
-- bottom at the origin, about 6 studs wide, facing -Z. The lid lives in a child
-- Model named "Lid" so the opening animation can pop it off.

local Bots = require(script.Parent.Parent.Bots)
local Kit = require(script.Parent.Kit)

local CrateArt = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local CN = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local DARK = rgb(50, 52, 62)

type Style = {
	Body: Color3,
	Trim: Color3,
	Glow: Color3,
	Rivet: Color3,
}

local STYLES: { [string]: Style } = {
	Rusty = { Body = rgb(200, 115, 60), Trim = rgb(120, 75, 50), Glow = rgb(255, 210, 90), Rivet = rgb(235, 190, 120) },
	Chrome = { Body = rgb(205, 215, 232), Trim = rgb(110, 120, 140), Glow = rgb(80, 200, 255), Rivet = rgb(240, 245, 255) },
	Galaxy = { Body = rgb(115, 70, 210), Trim = rgb(55, 30, 110), Glow = rgb(255, 110, 230), Rivet = rgb(255, 230, 120) },
	Gem = { Body = rgb(60, 200, 140), Trim = rgb(30, 110, 80), Glow = rgb(150, 255, 210), Rivet = rgb(220, 255, 240) },
}

-- Big "?" badge on the front, built from rounded pieces.
local function questionMark(m: Model, cf: CFrame, color: Color3)
	for i = 0, 6 do
		local a = rad(200 - i * 40)
		Kit.ball(m, cf * CN(math.cos(a) * 0.55, 0.45 + math.sin(a) * 0.55, 0), 0.34, color, { Neon = true })
	end
	Kit.cylY(m, cf * CN(0.1, -0.15, 0), 0.4, 0.3, color, { Neon = true })
	Kit.ball(m, cf * CN(0.1, -0.7, 0), 0.36, color, { Neon = true })
end

local function crate(m: Model, s: Style)
	local w, h = 6, 4.4
	-- Feet.
	for _, x in { -2.3, 2.3 } do
		for _, z in { -2.3, 2.3 } do
			Kit.roundBox(m, CN(x, 0.25, z), Vector3.new(1.1, 0.5, 1.1), 0.2, s.Trim, nil, false)
		end
	end
	Kit.roundBox(m, CN(0, 0.5 + h / 2, 0), Vector3.new(w, h, w), 0.55, s.Body)
	-- Corner posts and bands.
	for _, x in { -w / 2 + 0.25, w / 2 - 0.25 } do
		for _, z in { -w / 2 + 0.25, w / 2 - 0.25 } do
			Kit.cylY(m, CN(x, 0.5 + h / 2, z), h + 0.1, 0.75, s.Trim)
		end
	end
	for _, y in { 1.3, 0.5 + h - 0.8 } do
		Kit.roundSlab(m, CN(0, y, 0), Vector3.new(w + 0.25, 0.45, w + 0.25), 0.6, s.Trim)
		Kit.rivets(m, Vector3.new(-2.2, y, -w / 2 - 0.15), Vector3.new(2.2, y, -w / 2 - 0.15), 5, 0.22, s.Rivet)
	end
	-- Front badge.
	Kit.cylZ(m, CN(0, 2.75, -w / 2 - 0.05), 0.25, 2.3, s.Trim)
	Kit.cylZ(m, CN(0, 2.75, -w / 2 - 0.15), 0.12, 1.95, Kit.shade(s.Trim, -0.3))
	questionMark(m, CN(0, 2.65, -w / 2 - 0.3), s.Glow)

	-- Lid in its own model so it can fly off.
	local lid = Kit.model(m, "Lid")
	Kit.roundBox(lid, CN(0, 0.5 + h + 0.45, 0), Vector3.new(w + 0.5, 0.9, w + 0.5), 0.4, s.Trim)
	Kit.roundBox(lid, CN(0, 0.5 + h + 1.0, 0), Vector3.new(w - 0.8, 0.5, w - 0.8), 0.25, s.Body, nil, false)
	Kit.box(lid, CN(0, 0.5 + h + 0.45, -w / 2 - 0.27), Vector3.new(w - 1, 0.12, 0.05), s.Glow, { Neon = true })
	-- Carry handle.
	for _, x in { -1.1, 1.1 } do
		Kit.cylY(lid, CN(x, 0.5 + h + 1.55, 0), 0.6, 0.3, DARK)
	end
	Kit.pill(lid, CN(0, 0.5 + h + 1.85, 0), 2.5, 0.4, DARK)
	return lid
end

local function decorate(id: string, m: Model, lid: Model, s: Style)
	if id == "Rusty" then
		-- Rust patches and a padlock.
		for _, patch in { { -1.6, 3.6, 1.0 }, { 1.7, 1.9, 0.8 }, { -1.9, 1.9, 0.6 } } do
			Kit.cylZ(m, CN(patch[1], patch[2], -3.02), 0.05, patch[3], Kit.shade(s.Body, -0.3))
		end
		Kit.roundBox(m, CN(0, 4.45, -3.25), Vector3.new(0.9, 0.75, 0.35), 0.12, rgb(230, 190, 70), nil, false)
		Kit.ring(m, CN(0, 4.95, -3.25) * ANG(rad(90), 0, 0), 0.3, 0.12, rgb(200, 205, 215), 8, nil, false)
	elseif id == "Chrome" then
		-- Glowing seams.
		for _, x in { -1.5, 1.5 } do
			Kit.box(m, CN(x, 2.7, -3.03), Vector3.new(0.1, 3.0, 0.05), s.Glow, { Neon = true })
		end
		for _, x in { -3.03, 3.03 } do
			Kit.box(m, CN(x, 2.7, 0), Vector3.new(0.05, 3.0, 0.1), s.Glow, { Neon = true })
		end
		Kit.ring(lid, CN(0, 6.0, 0), 1.3, 0.18, s.Glow, 12, { Neon = true }, false)
	elseif id == "Galaxy" then
		-- Stars on the sides and an orbiting ring.
		for _, star in { { -2.0, 3.8 }, { 1.9, 1.7 }, { 2.1, 3.9 }, { -1.8, 1.6 } } do
			Kit.box(m, CN(star[1], star[2], -3.05) * ANG(0, 0, rad(45)), Vector3.new(0.3, 0.3, 0.05), rgb(255, 240, 160), { Neon = true })
		end
		Kit.ring(m, CN(0, 2.9, 0) * ANG(rad(12), 0, rad(8)), 4.6, 0.25, s.Glow, 18, { Neon = true }, false)
		Kit.ball(lid, CN(0, 6.6, 0), 0.9, s.Glow, { Neon = true })
		Kit.sparkle(Kit.ball(m, CN(0, 2.9, 0), 0.4, s.Glow, { Neon = true }), s.Glow, 6)
	elseif id == "Gem" then
		-- Gem clusters on the lid corners.
		for _, x in { -2.6, 2.6 } do
			for _, z in { -2.6, 2.6 } do
				Kit.box(lid, CN(x, 5.95, z) * ANG(rad(45), rad(45), 0), Vector3.new(0.8, 0.8, 0.8), s.Glow, { Neon = true })
			end
		end
		Kit.box(lid, CN(0, 6.4, 0) * ANG(rad(45), rad(45), 0), Vector3.new(1.0, 1.0, 1.0), rgb(120, 230, 255), { Neon = true })
		Kit.sparkle(Kit.ball(m, CN(0, 3, 0), 0.4, s.Glow, { Neon = true }), s.Glow, 5)
	end
end

function CrateArt.list(): { string }
	local ids = {}
	for _, def in Bots.Crates do
		table.insert(ids, def.Id)
	end
	return ids
end

function CrateArt.build(id: string): Model
	local model = Kit.model(nil, "Crate_" .. id)
	local style = STYLES[id] or STYLES.Rusty
	local lid = crate(model, style)
	decorate(id, model, lid, style)
	return model
end

return CrateArt
