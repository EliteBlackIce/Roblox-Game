-- Builds art in the mock engine and prints every part as JSON for render.py.
-- usage: luaurun dump.luau <repo> <files> <target> [filter]
--   target = an Art module name (Items, Bots, Crates, Tools, Stations) or "map"
local ROOT = __ARGS[2] .. "/src"
local M = (__loadsrc(__readfile(__ARGS[2] .. "/tests/mock.luau"), "mock"))()
local S = M.services
local listing = __ARGS[3]
local target = __ARGS[4]
local filter = __ARGS[5]
local function filesUnder(prefix)
	local out = {}
	for line in listing:gmatch("[^\n]+") do
		if line:sub(1, #prefix + 1) == prefix .. "/" then
			table.insert(out, line:sub(#prefix + 2))
		end
	end
	return out
end
local shared = M.mount(S.ReplicatedStorage, "Shared", ROOT .. "/shared", filesUnder("shared"))
local server = M.mount(S.ServerScriptService, "Server", ROOT .. "/server", filesUnder("server"))
M.context = "server"

local function num(n)
	return string.format("%.4f", n)
end
local function partsOf(root)
	local out = {}
	local list = root:GetDescendants()
	if root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, d in list do
		if d:IsA("BasePart") then
			local cf = d.CFrame
			local r = cf.r
			local shape = "Block"
			if d.ClassName == "WedgePart" then
				shape = "Wedge"
			elseif d.ClassName == "Part" and d.Shape then
				shape = d.Shape.Name
			end
			local c = d.Color
			local neon = d.Material and d.Material.Name == "Neon"
			table.insert(out, string.format(
				'{"shape":"%s","p":[%s,%s,%s],"r":[%s],"s":[%s,%s,%s],"c":[%s,%s,%s],"t":%s,"neon":%s}',
				shape, num(cf.Position.X), num(cf.Position.Y), num(cf.Position.Z),
				table.concat({ num(r[1]), num(r[2]), num(r[3]), num(r[4]), num(r[5]), num(r[6]), num(r[7]), num(r[8]), num(r[9]) }, ","),
				num(d.Size.X), num(d.Size.Y), num(d.Size.Z), num(c.R), num(c.G), num(c.B),
				num(d.Transparency or 0), tostring(neon == true)))
		end
	end
	return table.concat(out, ",")
end

local models = {}
if target == "map" then
	local MapBuilder = require(server.World.MapBuilder)
	local map = MapBuilder.build()
	local root = if filter then map:FindFirstChild(filter, true) else map
	assert(root, "no such map section: " .. tostring(filter))
	table.insert(models, string.format('{"name":"%s","parts":[%s]}', root.Name, partsOf(root)))
else
	local Art = require(shared.Art:FindFirstChild(target))
	local holder = M.newInstance("Folder")
	for _, id in Art.list() do
		local match = filter == nil
		for _, f in string.split(filter or "", ",") do
			if f ~= "" and id:find(f) then
				match = true
			end
		end
		if match then
			local model = Art.build(id)
			model.Parent = holder
			table.insert(models, string.format('{"name":"%s","parts":[%s]}', id, partsOf(model)))
		end
	end
end
assert(#M.errors == 0, "build errors")
print('{"models":[' .. table.concat(models, ",") .. "]}")
