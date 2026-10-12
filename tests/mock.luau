-- Minimal headless Roblox engine mock for exercising game code.
local M = {}

---------------------------------------------------------------- scheduler
local now = 0
local queue = {} -- { time, co, args }
local function schedule(t, co, ...)
	table.insert(queue, { t = t, co = co, args = table.pack(...) })
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error("Coroutine error: " .. tostring(err) .. "\n" .. debug.traceback(co), 0)
	end
end
M.errors = {}
local function safeResume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		local msg = tostring(err) .. "\n" .. debug.traceback(co)
		table.insert(M.errors, msg)
		print("!! SCRIPT ERROR: " .. msg)
	end
end

task = {
	spawn = function(fn, ...)
		local co = type(fn) == "thread" and fn or coroutine.create(fn)
		safeResume(co, ...)
		return co
	end,
	defer = function(fn, ...)
		local co = coroutine.create(fn)
		schedule(now, co, ...)
		return co
	end,
	delay = function(t, fn, ...)
		local co = coroutine.create(fn)
		schedule(now + (t or 0), co, ...)
		return co
	end,
	wait = function(t)
		local co = coroutine.running()
		schedule(now + (t or 0.03), co)
		coroutine.yield()
		return t or 0.03
	end,
}
os.clock = function()
	return now
end
local realTime = os.time
M.timeOffset = 1760000000
os.time = function(t)
	if t then
		return realTime(t)
	end
	return M.timeOffset + math.floor(now)
end

function M.advance(dt)
	local target = now + dt
	while true do
		table.sort(queue, function(a, b)
			return a.t < b.t
		end)
		local item = queue[1]
		if not item or item.t > target then
			break
		end
		table.remove(queue, 1)
		now = math.max(now, item.t)
		if coroutine.status(item.co) == "suspended" then
			safeResume(item.co, table.unpack(item.args, 1, item.args.n))
		end
	end
	now = target
end
function M.now()
	return now
end

---------------------------------------------------------------- datatypes
-- Seeded Random like Roblox's (LCG; fine for tests).
do
	local R = {}
	R.__index = R
	local seedCounter = 0
	function R:NextNumber(a, b)
		self.state = (self.state * 1103515245 + 12345) % 2147483648
		local t = self.state / 2147483648
		return (a or 0) + t * ((b or 1) - (a or 0))
	end
	function R:NextInteger(a, b)
		return math.min(b, a + math.floor(self:NextNumber() * (b - a + 1)))
	end
	Random = {
		new = function(seed)
			seedCounter += 1
			return setmetatable({ state = math.floor(seed or (seedCounter * 7777 + 13)) % 2147483648 }, R)
		end,
	}
end
local Vector3Meta = {}
Vector3 = {}
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __type = "Vector3" }, Vector3Meta)
end
Vector3.new = v3
Vector3Meta.__index = function(self, k)
	if k == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	elseif k == "Unit" then
		local m = math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
		return v3(self.X / m, self.Y / m, self.Z / m)
	elseif k == "x" then
		return rawget(self, "X")
	elseif k == "Lerp" then
		return function(a, b, t)
			return a + (b - a) * t
		end
	elseif k == "Cross" then
		return function(a, b)
			return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	end
	error("Vector3 has no member " .. tostring(k), 2)
end
Vector3Meta.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vector3Meta.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vector3Meta.__mul = function(a, b)
	if type(a) == "number" then
		return v3(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3Meta.__div = function(a, b)
	return v3(a.X / b, a.Y / b, a.Z / b)
end
Vector3Meta.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
Vector3Meta.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Vector3Meta.__tostring = function(a)
	return string.format("%.2f, %.2f, %.2f", a.X, a.Y, a.Z)
end
Vector3.one = v3(1, 1, 1)
Vector3.zero = v3(0, 0, 0)

local function plain(typeName, fields)
	fields.__type = typeName
	return setmetatable(fields, {
		__index = function(_, k)
			error(typeName .. " has no member " .. tostring(k), 2)
		end,
	})
end
Vector2 = {
	new = function(x, y)
		return plain("Vector2", { X = x or 0, Y = y or 0 })
	end,
}
UDim = {
	new = function(s, o)
		return plain("UDim", { Scale = s, Offset = o })
	end,
}
UDim2 = {
	new = function(xs, xo, ys, yo)
		return plain("UDim2", { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) })
	end,
	fromScale = function(x, y)
		return UDim2.new(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		return UDim2.new(0, x, 0, y)
	end,
}
local Color3Meta = {}
Color3Meta.__index = function(self, k)
	if k == "Lerp" then
		return function(a, b, t)
			return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
		end
	end
	error("Color3 has no member " .. tostring(k), 2)
end
Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = r or 0, G = g or 0, B = b or 0, __type = "Color3" }, Color3Meta)
	end,
}
Color3.fromHSV = function(h, sat, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - sat), v * (1 - f * sat), v * (1 - (1 - f) * sat)
	local m = i % 6
	if m == 0 then return Color3.new(v, t, p) elseif m == 1 then return Color3.new(q, v, p)
	elseif m == 2 then return Color3.new(p, v, t) elseif m == 3 then return Color3.new(p, q, v)
	elseif m == 4 then return Color3.new(t, p, v) end
	return Color3.new(v, p, q)
end
Color3.fromRGB = function(r, g, b)
	assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "fromRGB needs numbers")
	return Color3.new(r / 255, g / 255, b / 255)
end
NumberRange = {
	new = function(a, b)
		return plain("NumberRange", { Min = a, Max = b or a })
	end,
}
NumberSequenceKeypoint = {
	new = function(t, v)
		return plain("NumberSequenceKeypoint", { Time = t, Value = v })
	end,
}
NumberSequence = {
	new = function(a)
		return plain("NumberSequence", { Keypoints = a })
	end,
}
ColorSequence = {
	new = function(a, b)
		assert(type(a) == "table", "ColorSequence.new expects Color3(s) or keypoints")
		if a.__type == "Color3" then
			return plain("ColorSequence", { Keypoints = a })
		end
		for _, kp in a do
			assert(kp.__type == "ColorSequenceKeypoint", "bad keypoint")
		end
		return plain("ColorSequence", { Keypoints = a[1].Value })
	end,
}
ColorSequenceKeypoint = {
	new = function(t, c)
		assert(type(t) == "number" and type(c) == "table" and c.__type == "Color3", "ColorSequenceKeypoint.new(number, Color3)")
		return plain("ColorSequenceKeypoint", { Time = t, Value = c })
	end,
}
TweenInfo = {
	new = function(...)
		return plain("TweenInfo", { args = table.pack(...) })
	end,
}

-- CFrame: rotation matrix (columns right, up, back) + position
local CFrameMeta = {}
local function cf(p, r)
	return setmetatable({ p = p, r = r, __type = "CFrame" }, CFrameMeta)
end
local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function matmul(a, b)
	local c = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			c[i * 3 + j + 1] = s
		end
	end
	return c
end
local function matvec(a, v)
	return v3(
		a[1] * v.X + a[2] * v.Y + a[3] * v.Z,
		a[4] * v.X + a[5] * v.Y + a[6] * v.Z,
		a[7] * v.X + a[8] * v.Y + a[9] * v.Z
	)
end
CFrame = {}
CFrame.new = function(x, y, z)
	if type(x) == "table" then
		return cf(x, I)
	end
	return cf(v3(x or 0, y or 0, z or 0), I)
end
CFrame.Angles = function(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(Vector3.zero, matmul(matmul(Rx, Ry), Rz))
end
CFrame.lookAt = function(pos, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - pos).Unit
	local right = look:Cross(up).Unit
	local upv = right:Cross(look)
	return cf(pos, { right.X, upv.X, -look.X, right.Y, upv.Y, -look.Y, right.Z, upv.Z, -look.Z })
end
CFrame.identity = cf(v3(0, 0, 0), I)
CFrameMeta.__index = function(self, k)
	local r = rawget(self, "r")
	if k == "Lerp" then
		return function(a, b, t)
			return cf(a.p:Lerp(b.p, t), b.r)
		end
	end
	if k == "Inverse" then
		return function(a)
			local m = a.r
			local rt = { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
			return cf(-matvec(rt, a.p), rt)
		end
	end
	if k == "Position" then
		return rawget(self, "p")
	elseif k == "LookVector" then
		return v3(-r[3], -r[6], -r[9])
	elseif k == "RightVector" then
		return v3(r[1], r[4], r[7])
	elseif k == "UpVector" then
		return v3(r[2], r[5], r[8])
	elseif k == "X" then
		return rawget(self, "p").X
	elseif k == "Y" then
		return rawget(self, "p").Y
	elseif k == "Z" then
		return rawget(self, "p").Z
	end
	error("CFrame has no member " .. tostring(k), 2)
end
CFrameMeta.__mul = function(a, b)
	if getmetatable(b) == CFrameMeta then
		return cf(a.p + matvec(a.r, b.p), matmul(a.r, b.r))
	elseif getmetatable(b) == Vector3Meta then
		return a.p + matvec(a.r, b)
	end
	error("bad CFrame multiplication", 2)
end
CFrameMeta.__sub = function(a, b)
	assert(getmetatable(b) == Vector3Meta, "CFrame - expects Vector3")
	return cf(a.p - b, a.r)
end
CFrameMeta.__add = function(a, b)
	assert(getmetatable(b) == Vector3Meta, "CFrame + expects Vector3")
	return cf(a.p + b, a.r)
end

---------------------------------------------------------------- Enum
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		if not enumCache[enumName] then
			enumCache[enumName] = setmetatable({}, {
				__index = function(t, itemName)
					local item = setmetatable({ Name = itemName, EnumType = enumName, __type = "EnumItem" }, {
						__tostring = function()
							return "Enum." .. enumName .. "." .. itemName
						end,
					})
					rawset(t, itemName, item)
					return item
				end,
			})
		end
		return enumCache[enumName]
	end,
})

---------------------------------------------------------------- Signal
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {}, waiting = {} }, Signal)
end
function Signal:Connect(fn)
	local conn = { Connected = true }
	local entry = { fn = fn, conn = conn }
	table.insert(self.handlers, entry)
	function conn.Disconnect()
		conn.Connected = false
	end
	return conn
end
function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn.Disconnect()
		fn(...)
	end)
	return conn
end
function Signal:Fire(...)
	for _, h in table.clone(self.handlers) do
		if h.conn.Connected then
			task.spawn(h.fn, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, co in waiting do
		safeResume(co, ...)
	end
end
function Signal:Wait()
	table.insert(self.waiting, coroutine.running())
	return coroutine.yield()
end
M.Signal = Signal

---------------------------------------------------------------- Instances
local SUPER = {
	Part = "BasePart",
	WedgePart = "BasePart",
	SpawnLocation = "Part",
	BasePart = "PVInstance",
	Model = "PVInstance",
	Workspace = "Model",
	Frame = "GuiObject",
	TextLabel = "GuiObject",
	TextButton = "GuiObject",
	TextBox = "GuiObject",
	ImageLabel = "GuiObject",
	ScrollingFrame = "GuiObject",
	ViewportFrame = "GuiObject",
	StringValue = "ValueBase",
	PointLight = "Light",
	GuiObject = "GuiBase2d",
	ScreenGui = "LayerCollector",
	SurfaceGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	LayerCollector = "GuiBase2d",
	IntValue = "ValueBase",
	NumberValue = "ValueBase",
	SpotLight = "Light",
	Tool = "BackpackItem",
	BackpackItem = "Model",
	BloomEffect = "PostEffect",
	ColorCorrectionEffect = "PostEffect",
	SunRaysEffect = "PostEffect",
	ModuleScript = "LuaSourceContainer",
	Script = "LuaSourceContainer",
	LocalScript = "LuaSourceContainer",
}

local BASEPART = {
	"Anchored", "Size", "CFrame", "Position", "Color", "Material", "Transparency", "Reflectance", "CanCollide",
	"CastShadow", "TopSurface", "BottomSurface", "Massless", "CanQuery", "CanTouch", "Orientation", "AssemblyLinearVelocity",
}
local GUIOBJ = {
	"Size", "Position", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "Visible", "LayoutOrder",
	"ZIndex", "AutomaticSize", "ClipsDescendants", "Rotation", "BorderSizePixel", "Active", "Selectable", "Name",
}
local TEXT = {
	"Text", "TextColor3", "TextScaled", "Font", "TextSize", "TextWrapped", "TextXAlignment", "TextYAlignment",
	"TextTransparency", "RichText", "TextStrokeTransparency",
}
local function merge(...)
	local s = {}
	for _, list in { ... } do
		for _, k in list do
			s[k] = true
		end
	end
	return s
end
local PROPS = {
	Part = merge(BASEPART, { "Shape" }),
	WedgePart = merge(BASEPART),
	SpawnLocation = merge(BASEPART, { "Shape", "Duration", "Neutral", "TeamColor", "AllowTeamChangeOnTouch", "Enabled" }),
	Model = merge({ "PrimaryPart", "WorldPivot", "ModelStreamingMode" }),
	Folder = merge({}),
	SurfaceGui = merge({ "Face", "SizingMode", "PixelsPerStud", "LightInfluence", "Adornee", "AlwaysOnTop", "CanvasSize", "Enabled", "ZIndexBehavior" }),
	BillboardGui = merge({ "Size", "StudsOffset", "StudsOffsetWorldSpace", "MaxDistance", "LightInfluence", "Adornee", "AlwaysOnTop", "Enabled" }),
	ScreenGui = merge({ "ResetOnSpawn", "IgnoreGuiInset", "ZIndexBehavior", "Enabled", "DisplayOrder" }),
	Frame = merge(GUIOBJ),
	TextLabel = merge(GUIOBJ, TEXT),
	TextButton = merge(GUIOBJ, TEXT, { "AutoButtonColor" }),
	UIPadding = merge({ "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" }),
	UIStroke = merge({ "Thickness", "Color", "Transparency", "ApplyStrokeMode", "LineJoinMode" }),
	UICorner = merge({ "CornerRadius" }),
	UIScale = merge({ "Scale" }),
	UIListLayout = merge({ "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "Padding" }),
	UITextSizeConstraint = merge({ "MaxTextSize", "MinTextSize" }),
	UISizeConstraint = merge({ "MinSize", "MaxSize" }),
	ProximityPrompt = merge({ "ActionText", "ObjectText", "HoldDuration", "MaxActivationDistance", "RequiresLineOfSight", "KeyboardKeyCode", "Enabled", "Style", "UIOffset" }),
	ParticleEmitter = merge({ "Texture", "Rate", "Lifetime", "Speed", "Size", "LightEmission", "Color", "SpreadAngle", "Acceleration", "EmissionDirection", "Transparency", "Enabled" }),
	SpotLight = merge({ "Face", "Angle", "Range", "Brightness", "Color", "Shadows", "Enabled" }),
	PointLight = merge({ "Range", "Brightness", "Color", "Shadows", "Enabled" }),
	StringValue = merge({ "Value" }),
	ScrollingFrame = merge(GUIOBJ, { "CanvasSize", "AutomaticCanvasSize", "ScrollBarThickness", "ScrollingDirection", "ScrollBarImageColor3", "ElasticBehavior" }),
	TextBox = merge(GUIOBJ, TEXT, { "PlaceholderText", "ClearTextOnFocus", "PlaceholderColor3" }),
	ImageLabel = merge(GUIOBJ, { "Image", "ImageColor3", "ImageTransparency", "ScaleType" }),
	UIGridLayout = merge({ "CellSize", "CellPadding", "SortOrder", "FillDirection", "HorizontalAlignment", "VerticalAlignment", "FillDirectionMaxCells" }),
	UIGradient = merge({ "Color", "Rotation", "Transparency", "Offset" }),
	UIAspectRatioConstraint = merge({ "AspectRatio", "DominantAxis" }),
	ViewportFrame = merge(GUIOBJ, { "CurrentCamera", "Ambient", "LightColor", "LightDirection" }),
	Camera = merge({ "CFrame", "FieldOfView" }),
	Sky = merge({ "SunAngularSize", "MoonAngularSize", "StarCount", "CelestialBodiesShown" }),
	Atmosphere = merge({ "Density", "Offset", "Color", "Decay", "Glare", "Haze" }),
	BloomEffect = merge({ "Intensity", "Size", "Threshold", "Enabled" }),
	ColorCorrectionEffect = merge({ "Saturation", "Contrast", "TintColor", "Brightness", "Enabled" }),
	Highlight = merge({ "FillColor", "OutlineColor", "FillTransparency", "OutlineTransparency", "Adornee", "DepthMode", "Enabled" }),
	SunRaysEffect = merge({ "Intensity", "Spread", "Enabled" }),
	Tool = merge({ "ToolTip", "CanBeDropped", "RequiresHandle", "Grip", "Enabled", "ManualActivationOnly", "TextureId" }),
	WeldConstraint = merge({ "Part0", "Part1", "Enabled" }),
	Sound = merge({ "SoundId", "Volume", "PlaybackSpeed", "Looped", "Playing" }),
	IntValue = merge({ "Value" }),
	NumberValue = merge({ "Value" }),
	RemoteEvent = merge({}),
	RemoteFunction = merge({ "OnServerInvoke", "OnClientInvoke" }),
	Decal = merge({ "Texture", "Face" }),
	Humanoid = merge({ "Health", "MaxHealth", "WalkSpeed" }),
	Backpack = merge({}),
	PlayerGui = merge({}),
	ModuleScript = merge({}),
	Script = merge({}),
	LocalScript = merge({}),
	Lighting = merge({ "ClockTime", "GeographicLatitude", "Brightness", "Ambient", "OutdoorAmbient", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GlobalShadows", "Technology" }),
	Players = merge({ "CharacterAutoLoads", "RespawnTime", "LocalPlayer" }),
	Player = merge({ "UserId", "Character", "DisplayName" }),
	Workspace = merge({}),
}

local EVENTS = {
	Changed = true, Triggered = true, Activated = true, Died = true, CharacterAdded = true, PlayerAdded = true,
	PlayerRemoving = true, DescendantAdded = true, OnClientEvent = true, OnServerEvent = true, ChildAdded = true,
	Completed = true, Equipped = true, Unequipped = true,
}

local InstanceMeta = {}
local Methods = {}
local nextId = 0

local function isA(className, target)
	local c = className
	while c do
		if c == target then
			return true
		end
		c = SUPER[c]
	end
	return target == "Instance"
end

local function newInstance(className)
	nextId += 1
	local self = setmetatable({}, InstanceMeta)
	rawset(self, "__data", {
		ClassName = className,
		Name = className,
		Parent = nil,
		children = {},
		attributes = {},
		signals = {},
		props = {},
		id = nextId,
	})
	local props = rawget(self, "__data").props
	if isA(className, "BasePart") then
		props.CFrame = CFrame.new()
		props.Size = Vector3.new(4, 1, 2)
		props.Transparency = 0
		props.CanCollide = true
		props.Anchored = false
		props.AssemblyLinearVelocity = Vector3.zero
	end
	if className == "ProximityPrompt" then
		props.Enabled = true
		props.HoldDuration = 0
	end
	return self
end

local function data(inst)
	return rawget(inst, "__data")
end

local function fireDescendantAdded(inst, added)
	local ancestor = inst
	while ancestor do
		local s = data(ancestor).signals.DescendantAdded
		if s then
			s:Fire(added)
		end
		ancestor = data(ancestor).Parent
	end
end

InstanceMeta.__index = function(self, k)
	local d = data(self)
	if k == "ClassName" or k == "Name" or k == "Parent" then
		return d[k]
	end
	if Methods[k] then
		return Methods[k]
	end
	if EVENTS[k] then
		d.signals[k] = d.signals[k] or Signal.new()
		return d.signals[k]
	end
	if k == "Position" and isA(d.ClassName, "BasePart") then
		return d.props.CFrame.Position
	end
	if k == "LookVector" then
		error("LookVector is not an Instance member", 2)
	end
	if d.props[k] ~= nil then
		return d.props[k]
	end
	-- child lookup like Roblox
	for _, child in d.children do
		if data(child).Name == k then
			return child
		end
	end
	if d.special and d.special[k] then
		return d.special[k]
	end
	local valid = PROPS[d.ClassName]
	if valid and valid[k] then
		return nil
	end
	error(tostring(k) .. " is not a valid member of " .. d.ClassName .. ' "' .. d.Name .. '"', 2)
end

InstanceMeta.__newindex = function(self, k, v)
	local d = data(self)
	if k == "Name" then
		d.Name = v
		return
	end
	if k == "Parent" then
		if d.Parent then
			local siblings = data(d.Parent).children
			for i, c in siblings do
				if c == self then
					table.remove(siblings, i)
					break
				end
			end
		end
		d.Parent = v
		if v then
			table.insert(data(v).children, self)
			local s = data(v).signals.ChildAdded
			if s then
				s:Fire(self)
			end
			fireDescendantAdded(v, self)
			for _, desc in Methods.GetDescendants(self) do
				fireDescendantAdded(v, desc)
			end
		end
		return
	end
	local valid = PROPS[d.ClassName]
	if not valid then
		error("mock: unknown class " .. d.ClassName .. " (setting " .. k .. ")", 2)
	end
	if not valid[k] then
		error(tostring(k) .. " is not a valid member of " .. d.ClassName, 2)
	end
	if k == "Position" and isA(d.ClassName, "BasePart") then
		local cur = d.props.CFrame or CFrame.new()
		d.props.CFrame = CFrame.new(v) * cf(Vector3.zero, cur.r)
		return
	end
	if k == "Shape" and d.ClassName == "Part" and v.Name == "Ball" and d.props.Size then
		local s = d.props.Size
		d.props.Size = v3(s.X, s.X, s.X)
	end
	if k == "Size" and d.ClassName == "Part" and d.props.Shape and d.props.Shape.Name == "Ball" then
		if not (v.X == v.Y and v.Y == v.Z) then
			-- Roblox forces uniform size on balls; flag non-uniform so we notice.
			print("note: non-uniform Ball size on " .. d.Name)
		end
	end
	d.props[k] = v
	local ch = d.signals.Changed
	if ch and d.ClassName:find("Value$") and k == "Value" then
		ch:Fire(v)
	end
end
InstanceMeta.__tostring = function(self)
	return data(self).Name
end

function Methods.GetChildren(self)
	return table.clone(data(self).children)
end
function Methods.GetDescendants(self)
	local out = {}
	local function walk(i)
		for _, c in data(i).children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Methods.FindFirstChild(self, name, recursive)
	for _, c in data(self).children do
		if data(c).Name == name then
			return c
		end
	end
	if recursive then
		for _, c in data(self).children do
			local f = Methods.FindFirstChild(c, name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function Methods.FindFirstChildOfClass(self, className)
	for _, c in data(self).children do
		if data(c).ClassName == className then
			return c
		end
	end
	return nil
end
function Methods.FindFirstAncestorWhichIsA(self, className)
	local p = data(self).Parent
	while p do
		if isA(data(p).ClassName, className) then
			return p
		end
		p = data(p).Parent
	end
end
function Methods.WaitForChild(self, name)
	local c = Methods.FindFirstChild(self, name)
	if c then
		return c
	end
	local deadline = now + 5
	while now < deadline do
		task.wait(0.05)
		c = Methods.FindFirstChild(self, name)
		if c then
			return c
		end
	end
	error("Infinite yield: WaitForChild(" .. name .. ") on " .. data(self).Name, 2)
end
function Methods.IsA(self, className)
	return isA(data(self).ClassName, className)
end
function Methods.Destroy(self)
	self.Parent = nil
	data(self).destroyed = true
end
function Methods.SetAttribute(self, k, v)
	data(self).attributes[k] = v
	local sigs = data(self).attrSignals
	if sigs and sigs[k] then
		sigs[k]:Fire(v)
	end
end
function Methods.GetAttributeChangedSignal(self, k)
	local d = data(self)
	d.attrSignals = d.attrSignals or {}
	d.attrSignals[k] = d.attrSignals[k] or Signal.new()
	return d.attrSignals[k]
end
function Methods.GetAttribute(self, k)
	return data(self).attributes[k]
end
function Methods.GetFullName(self)
	local names = {}
	local i = self
	while i do
		table.insert(names, 1, data(i).Name)
		i = data(i).Parent
	end
	return table.concat(names, ".")
end
function Methods.IsDescendantOf(self, other)
	local p = data(self).Parent
	while p do
		if p == other then
			return true
		end
		p = data(p).Parent
	end
	return false
end
-- class-specific methods
function Methods.Emit(self, n)
	assert(data(self).ClassName == "ParticleEmitter")
end
function Methods.EquipTool(self, tool)
	assert(data(self).ClassName == "Humanoid")
	tool.Parent = data(self).Parent
end
function Methods.FireClient(self, player, ...)
	assert(data(self).ClassName == "RemoteEvent", "FireClient on non-RemoteEvent")
	assert(isA(data(player).ClassName, "Player"), "FireClient needs player")
	M.remoteLog[#M.remoteLog + 1] = { name = data(self).Name, player = player, args = table.pack(...) }
	if M.clientPlayer == player then
		self.OnClientEvent:Fire(...)
	end
end
function Methods.FireAllClients(self, ...)
	M.remoteLog[#M.remoteLog + 1] = { name = data(self).Name, player = nil, args = table.pack(...) }
	self.OnClientEvent:Fire(...)
end
function Methods.FireServer(self, ...)
	self.OnServerEvent:Fire(M.clientPlayer, ...)
end
function Methods.InvokeServer(self, ...)
	assert(data(self).ClassName == "RemoteFunction")
	local cb = data(self).props.OnServerInvoke
	assert(cb, "no OnServerInvoke for " .. data(self).Name)
	return cb(M.clientPlayer, ...)
end
function Methods.LoadCharacter(self)
	local d = data(self)
	assert(d.ClassName == "Player")
	if d.props.Character then
		d.props.Character:Destroy()
	end
	local char = newInstance("Model")
	char.Name = d.Name
	local humanoid = newInstance("Humanoid")
	humanoid.Parent = char
	local root = newInstance("Part")
	root.Name = "HumanoidRootPart"
	local spawnPos = M.spawnPosition or Vector3.new(0, 3, 0)
	root.CFrame = CFrame.new(spawnPos)
	root.Parent = char
	d.props.Character = char
	char.Parent = M.services.Workspace
	-- default backpack reset
	local backpack = Methods.FindFirstChildOfClass(self, "Backpack")
	if backpack then
		backpack:Destroy()
	end
	local bp = newInstance("Backpack")
	bp.Name = "Backpack"
	bp.Parent = self
	self.CharacterAdded:Fire(char)
end
function Methods.PivotTo(self, cframe)
	local root = Methods.FindFirstChild(self, "HumanoidRootPart")
	if root then
		root.CFrame = cframe
	elseif data(self).props.PrimaryPart then
		data(self).props.PrimaryPart.CFrame = cframe
	end
end
function Methods.GetPivot(self)
	local root = Methods.FindFirstChild(self, "HumanoidRootPart") or data(self).props.PrimaryPart
	return root and root.CFrame or CFrame.new()
end
function Methods.GetPlayerByUserId(self, userId)
	for _, c in data(self).children do
		if data(c).ClassName == "Player" and data(c).props.UserId == userId then
			return c
		end
	end
	return nil
end
function Methods.GetNameFromUserIdAsync(self, userId)
	return "User" .. tostring(userId)
end
function Methods.BulkMoveTo(self, parts, cframes)
	M.bulkMoves = (M.bulkMoves or 0) + 1
	for i, part in parts do
		part.CFrame = cframes[i]
	end
end
function Methods.Kick(self, msg)
	print("KICK " .. tostring(msg))
end
function Methods.Play(self) end
function Methods.Cancel(self) end
function Methods.Stop(self) end

Instance = {
	new = function(className, parent)
		if not PROPS[className] then
			error("mock: Instance.new of unsupported class " .. tostring(className), 2)
		end
		local inst = newInstance(className)
		if className == "SpawnLocation" then
			local decal = newInstance("Decal")
			decal.Parent = inst
		end
		if parent then
			inst.Parent = parent
		end
		return inst
	end,
}
M.newInstance = newInstance
M.data = data

typeof = function(v)
	if type(v) == "table" then
		if getmetatable(v) == InstanceMeta then
			return "Instance"
		end
		if rawget(v, "__type") then
			return rawget(v, "__type")
		end
	end
	return type(v)
end
warn = function(...)
	local parts = {}
	for _, v in { ... } do
		table.insert(parts, tostring(v))
	end
	print("WARN: " .. table.concat(parts, " "))
	M.warnings = (M.warnings or 0) + 1
end

---------------------------------------------------------------- Services
local services = {}
M.services = services
M.remoteLog = {}

local function service(name, className)
	local s = newInstance(className or name)
	s.Name = name
	services[name] = s
	return s
end
local gameRoot = newInstance("Folder")
gameRoot.Name = "Game"
for _, n in { "Workspace", "Players", "ReplicatedStorage", "ServerScriptService", "Lighting", "StarterPlayer" } do
	local cls = (n == "Workspace" or n == "Players" or n == "Lighting") and n or "Folder"
	local s = service(n, cls)
	s.Parent = gameRoot
end
data(services.Players).props.RespawnTime = 5
data(services.Players).props.CharacterAutoLoads = true

-- CollectionService
local tags = {}
local tagSignals = {}
local CollectionService = {}
function CollectionService:AddTag(inst, tag)
	tags[tag] = tags[tag] or {}
	tags[tag][inst] = true
	if tagSignals[tag] then
		tagSignals[tag]:Fire(inst)
	end
end
function CollectionService:HasTag(inst, tag)
	return tags[tag] ~= nil and tags[tag][inst] == true
end
function CollectionService:GetTagged(tag)
	local out = {}
	for inst in tags[tag] or {} do
		if not data(inst).destroyed then
			table.insert(out, inst)
		end
	end
	return out
end
function CollectionService:GetInstanceRemovedSignal(tag)
	return Signal.new()
end
function CollectionService:GetInstanceAddedSignal(tag)
	tagSignals[tag] = tagSignals[tag] or Signal.new()
	return tagSignals[tag]
end
services.CollectionService = CollectionService
function M.tagsOf(inst)
	local out = {}
	for tag, set in tags do
		if set[inst] then
			table.insert(out, tag)
		end
	end
	table.sort(out)
	return out
end

local TweenService = {}
function TweenService:Create(inst, info, goals)
	assert(typeof(inst) == "Instance", "Tween target must be an Instance")
	assert(typeof(info) == "TweenInfo", "Tween info must be TweenInfo")
	for k in goals do
		local _ = inst[k] -- validates member exists
	end
	local tween = { Completed = Signal.new() }
	function tween:Play()
		for k, v in goals do
			inst[k] = v
		end
		self.Completed:Fire(Enum.PlaybackState.Completed)
	end
	function tween:Cancel() end
	return tween
end
services.TweenService = TweenService

-- DataStore mock
M.datastore = {}
M.datastoreFails = false
local DataStoreService = {}
function DataStoreService:GetDataStore(name)
	local store = {}
	function store:GetAsync(key)
		if M.datastoreFails then
			error("DataStore request failed")
		end
		return M.datastore[key]
	end
	function store:UpdateAsync(key, fn)
		if M.datastoreFails then
			error("DataStore request failed")
		end
		-- emulate serialization: deep copy
		local function copy(t)
			if type(t) ~= "table" then
				return t
			end
			local c = {}
			for k, v in t do
				c[k] = copy(v)
			end
			return c
		end
		M.datastore[key] = copy(fn(M.datastore[key]))
	end
	return store
end
function DataStoreService:GetOrderedDataStore(name)
	if M.orderedFails ~= false then
		error("OrderedDataStore unavailable in mock")
	end
end
services.DataStoreService = DataStoreService

M.ownedPasses = {}
local MarketplaceService = {
	PromptGamePassPurchaseFinished = Signal.new(),
	PromptProductPurchaseFinished = Signal.new(),
}
function MarketplaceService:UserOwnsGamePassAsync(userId, passId)
	return M.ownedPasses[passId] == true
end
function MarketplaceService:PromptGamePassPurchase() end
function MarketplaceService:PromptProductPurchase() end
services.MarketplaceService = MarketplaceService

M.context = "server"
local RunService = {
	RenderStepped = Signal.new(),
	Heartbeat = Signal.new(),
}
function RunService:IsServer()
	return M.context == "server"
end
function RunService:IsClient()
	return M.context == "client"
end
function RunService:IsStudio()
	return true
end
services.RunService = RunService

services.Debris = {
	AddItem = function(_, inst, t)
		task.delay(t, function()
			inst:Destroy()
		end)
	end,
}
local SoundService = service("SoundService", "Folder")
M.soundsPlayed = {}
function Methods.PlayLocalSound(_, sound)
	table.insert(M.soundsPlayed, sound.SoundId)
end

local gameMeta = {}
game = setmetatable({}, {
	__index = function(_, k)
		if k == "GetService" then
			return function(_, name)
				local s = services[name]
				if not s then
					error("mock: no service " .. name)
				end
				return s
			end
		elseif k == "BindToClose" then
			return function(_, fn)
				M.bindToClose = fn
			end
		elseif services[k] then
			return services[k]
		end
		error("game." .. k .. " not mocked")
	end,
})
workspace = services.Workspace

-- Players
function M.addPlayer(name, userId)
	local p = newInstance("Player")
	p.Name = name
	data(p).props.DisplayName = name
	data(p).props.UserId = userId
	local gui = newInstance("PlayerGui")
	gui.Name = "PlayerGui"
	gui.Parent = p
	local bp = newInstance("Backpack")
	bp.Name = "Backpack"
	bp.Parent = p
	p.Parent = services.Players
	services.Players.PlayerAdded:Fire(p)
	return p
end
function M.removePlayer(p)
	services.Players.PlayerRemoving:Fire(p)
	p.Parent = nil
end
SUPER.Player = "Instance"
PROPS.Player.Name = true
function Methods.GetPlayers(self)
	local out = {}
	for _, c in data(self).children do
		if data(c).ClassName == "Player" then
			table.insert(out, c)
		end
	end
	return out
end

---------------------------------------------------------------- require / scripts
local caches = { server = {}, client = {} }
function M.loadScriptInstance(inst)
	local path = data(inst).sourcePath
	local src = __readfile(path)
	assert(src, "cannot read " .. path)
	local fn, err = __loadsrc("local script = ...; " .. src, path)
	if not fn then
		error("COMPILE ERROR in " .. path .. ": " .. err)
	end
	return fn
end
require = function(inst)
	assert(typeof(inst) == "Instance", "require expects an Instance")
	local cache = caches[M.context]
	if cache[inst] ~= nil then
		return cache[inst]
	end
	local fn = M.loadScriptInstance(inst)
	local result = fn(inst)
	assert(result ~= nil, "module returned nil: " .. inst:GetFullName())
	cache[inst] = result
	return result
end

-- Mount a directory listing (given explicitly) as Rojo would.
function M.mount(parent, folderName, root, files)
	local folder = newInstance("Folder")
	folder.Name = folderName
	for _, rel in files do
		local current = folder
		local parts = string.split(rel, "/")
		for i = 1, #parts - 1 do
			local child = Methods.FindFirstChild(current, parts[i])
			if not child then
				child = newInstance("Folder")
				child.Name = parts[i]
				child.Parent = current
			end
			current = child
		end
		local file = parts[#parts]
		local name, kind = file:match("^(.-)%.(%a+)%.luau$")
		local cls = "ModuleScript"
		if kind == "server" then
			cls = "Script"
		elseif kind == "client" then
			cls = "LocalScript"
		else
			name = file:gsub("%.luau$", "")
		end
		local inst = newInstance(cls)
		inst.Name = name
		data(inst).sourcePath = root .. "/" .. rel
		inst.Parent = current
	end
	folder.Parent = parent
	return folder
end

function M.runScript(inst, context)
	M.context = context
	local fn = M.loadScriptInstance(inst)
	task.spawn(fn, inst)
end

return M
