-- Runs MapBuilder headlessly and writes the result as Rojo model files, so the
-- built place opens in Studio with the scrapyard already in Workspace.
-- Run with tests/bake.sh

local DIR = __ARGS[2] .. "/tests"
local ROOT = __ARGS[2] .. "/src"
local M = (__loadsrc(__readfile(DIR .. "/mock.luau"), "mock"))()
local S = M.services

local listing = __ARGS[3]
local function filesUnder(prefix)
	local out = {}
	for line in listing:gmatch("[^\n]+") do
		if line:sub(1, #prefix + 1) == prefix .. "/" then
			table.insert(out, line:sub(#prefix + 2))
		end
	end
	return out
end
M.mount(S.ReplicatedStorage, "Shared", ROOT .. "/shared", filesUnder("shared"))
local server = M.mount(S.ServerScriptService, "Server", ROOT .. "/server", filesUnder("server"))

M.context = "server"
local MapBuilder = require(server.World.MapBuilder)
local map = MapBuilder.build()
assert(#M.errors == 0, "map build errors")

---------------------------------------------------------------- JSON
local function num(n)
	if n == math.floor(n) and math.abs(n) < 1e15 then
		return string.format("%d", n)
	end
	local s = string.format("%.5f", n):gsub("0+$", ""):gsub("%.$", "")
	if s == "-0" then
		s = "0"
	end
	return s
end
local function str(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		if c == '"' then
			return '\\"'
		elseif c == "\\" then
			return "\\\\"
		elseif c == "\n" then
			return "\\n"
		end
		return string.format("\\u%04x", string.byte(c))
	end) .. '"'
end
local function arr(list)
	local parts = {}
	for _, v in list do
		table.insert(parts, num(v))
	end
	return "[" .. table.concat(parts, ",") .. "]"
end

local function value(v)
	local t = typeof(v)
	if t == "number" then
		return num(v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "string" then
		return str(v)
	elseif t == "EnumItem" then
		return str(v.Name)
	elseif t == "Vector3" then
		return `\{"Vector3":{arr({ v.X, v.Y, v.Z })}}`
	elseif t == "Vector2" then
		return `\{"Vector2":{arr({ v.X, v.Y })}}`
	elseif t == "Color3" then
		return `\{"Color3":{arr({ v.R, v.G, v.B })}}`
	elseif t == "UDim" then
		return `\{"UDim":{arr({ v.Scale, v.Offset })}}`
	elseif t == "UDim2" then
		return `\{"UDim2":[{arr({ v.X.Scale, v.X.Offset })},{arr({ v.Y.Scale, v.Y.Offset })}]}`
	elseif t == "CFrame" then
		local r, p = v.r, v.p
		return `\{"CFrame":\{"position":{arr({ p.X, p.Y, p.Z })},"orientation":[{arr({ r[1], r[2], r[3] })},{arr({ r[4], r[5], r[6] })},{arr({ r[7], r[8], r[9] })}]}}`
	elseif t == "NumberRange" then
		return `\{"NumberRange":{arr({ v.Min, v.Max })}}`
	elseif t == "NumberSequence" then
		local kps = v.Keypoints
		if type(kps) == "number" then
			kps = { { Time = 0, Value = kps }, { Time = 1, Value = kps } }
		end
		local parts = {}
		for _, kp in kps do
			table.insert(parts, `\{"time":{num(kp.Time)},"value":{num(kp.Value)},"envelope":0}`)
		end
		return `\{"NumberSequence":\{"keypoints":[{table.concat(parts, ",")}]}}`
	elseif t == "ColorSequence" then
		local c = v.Keypoints
		local col = arr({ c.R, c.G, c.B })
		return `\{"ColorSequence":\{"keypoints":[\{"time":0,"color":{col}},\{"time":1,"color":{col}}]}}`
	end
	error("cannot serialize " .. t)
end

-- Instance references (Model.PrimaryPart, gui Adornee) are left out: the game
-- looks parts up by name, and an unset Adornee defaults to the parent part.
local SKIP = { PrimaryPart = true, Adornee = true }

local function serialize(inst, indent, isRoot)
	local d = M.data(inst)
	local pad = string.rep("  ", indent)
	local fields = {}
	if not isRoot then
		table.insert(fields, `{pad}  "name": {str(d.Name)}`)
	end
	table.insert(fields, `{pad}  "className": {str(d.ClassName)}`)

	local keys = {}
	for k in d.props do
		if not SKIP[k] then
			table.insert(keys, k)
		end
	end
	table.sort(keys)
	local props = {}
	for _, k in keys do
		table.insert(props, `{str(k)}: {value(d.props[k])}`)
	end
	-- Rojo reads CollectionService tags from a "Tags" string-array property.
	local tags = M.tagsOf(inst)
	if #tags > 0 then
		local quoted = {}
		for _, tag in tags do
			table.insert(quoted, str(tag))
		end
		table.insert(props, `"Tags": \{"Tags": [{table.concat(quoted, ", ")}]}`)
	end
	if #props > 0 then
		table.insert(fields, `{pad}  "properties": \{{table.concat(props, ", ")}}`)
	end

	local attrKeys = {}
	for k in d.attributes do
		table.insert(attrKeys, k)
	end
	table.sort(attrKeys)
	if #attrKeys > 0 then
		local attrs = {}
		for _, k in attrKeys do
			table.insert(attrs, `{str(k)}: {value(d.attributes[k])}`)
		end
		table.insert(fields, `{pad}  "attributes": \{{table.concat(attrs, ", ")}}`)
	end

	if #d.children > 0 then
		local children = {}
		for _, child in d.children do
			table.insert(children, serialize(child, indent + 2, false))
		end
		table.insert(fields, `{pad}  "children": [\n{table.concat(children, ",\n")}\n{pad}  ]`)
	end
	return `{pad}\{\n{table.concat(fields, ",\n")}\n{pad}}`
end

print("@@FILE map/Junkyard.model.json")
print(serialize(map, 0, true))

-- Lighting: properties go into the project file, effects become model files.
local lightingProps = {}
for k, v in M.data(S.Lighting).props do
	table.insert(lightingProps, `{str(k)}: {value(v)}`)
end
table.sort(lightingProps)
print("@@FILE map/lighting.props.json")
print(`\{{table.concat(lightingProps, ", ")}}`)
for _, child in S.Lighting:GetChildren() do
	print(`@@FILE map/Lighting/{child.Name}.model.json`)
	print(serialize(child, 0, true))
end
print("@@END")
