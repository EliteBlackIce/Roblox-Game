--!strict
-- Renders every player's equipped Scrap Bots as little low-poly robots that
-- hover behind them. Purely visual and local; the server only publishes the
-- "Bots" attribute ("BotId,BotId:g,...").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Bots = require(ReplicatedStorage.Shared.Bots)
local State = require(script.Parent.State)

local BotFollowers = {}

local GOLD = Color3.fromRGB(255, 205, 50)

type Follower = { Model: Model, Root: Part, Index: number, Pose: CFrame? }
local followers: { [Player]: { Follower } } = {}
-- Each part's offset from the bot's pose, kept in Lua rather than attributes.
local offsets: { [BasePart]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local folder: Folder

local function part(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, neon: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	offsets[p] = offset
	p.Parent = model
	return p
end

local function buildBot(id: string, golden: boolean): (Model, Part)
	local bot = Bots.ById[id]
	local body = if golden then GOLD else bot.Body
	local trim = bot.Trim
	local model = Instance.new("Model")
	model.Name = id
	local root = part(model, "Body", Vector3.new(1.4, 1.4, 1.4), CFrame.new(), body)
	if bot.Style == "Drone" then
		root.Size = Vector3.new(1.6, 0.8, 1.6)
		for _, x in { -1.1, 1.1 } do
			part(model, "Rotor", Vector3.new(0.15, 1.3, 1.3), CFrame.new(x, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), trim)
		end
		part(model, "Eye", Vector3.new(0.9, 0.3, 0.1), CFrame.new(0, 0, -0.82), trim, true)
	elseif bot.Style == "Crawler" then
		root.Size = Vector3.new(1.4, 0.8, 1.8)
		for _, x in { -0.7, 0.7 } do
			for _, z in { -0.6, 0.6 } do
				part(model, "Leg", Vector3.new(0.25, 0.7, 0.25), CFrame.new(x, -0.55, z) * CFrame.Angles(0, 0, math.rad(if x < 0 then 20 else -20)), trim)
			end
		end
		part(model, "Head", Vector3.new(0.9, 0.7, 0.7), CFrame.new(0, 0.3, -1.0), body)
		part(model, "Eye", Vector3.new(0.7, 0.2, 0.1), CFrame.new(0, 0.35, -1.36), trim, true)
	elseif bot.Style == "Orb" then
		root.Size = Vector3.new(1.3, 1.3, 1.3)
		offsets[root] = CFrame.Angles(math.rad(45), math.rad(45), 0)
		part(model, "Ring", Vector3.new(2.4, 0.2, 2.4), CFrame.Angles(0, math.rad(45), 0), trim, true)
		part(model, "Eye", Vector3.new(0.5, 0.5, 0.1), CFrame.new(0, 0.1, -0.95), trim, true)
	else -- Cube
		part(model, "Eye", Vector3.new(1.0, 0.3, 0.1), CFrame.new(0, 0.2, -0.72), trim, true)
		part(model, "Antenna", Vector3.new(0.15, 0.6, 0.15), CFrame.new(0, 1.0, 0), trim)
		part(model, "Tip", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 1.4, 0), trim, true)
	end
	if golden then
		part(model, "Crown", Vector3.new(0.8, 0.3, 0.8), CFrame.new(0, 1.0, 0.1), GOLD, true)
	end
	model.PrimaryPart = root
	return model, root
end

local function clear(player: Player)
	for _, follower in followers[player] or {} do
		follower.Model:Destroy()
	end
	followers[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local raw = player:GetAttribute("Bots")
	if type(raw) ~= "string" or raw == "" then
		return
	end
	local settings = State.current and State.current.Settings
	if player ~= Players.LocalPlayer and settings and settings.HideBots then
		return
	end
	local list = {}
	for i, entry in string.split(raw, ",") do
		local id, flag = string.match(entry, "^(%w+):?(%w*)$")
		if id and Bots.ById[id] then
			local model, root = buildBot(id, flag == "g")
			model.Parent = folder
			table.insert(list, { Model = model, Root = root, Index = i })
		end
	end
	followers[player] = list
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Bots"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

local function step()
	local t = os.clock()
	for player, list in followers do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local count = #list
			for _, follower in list do
				local spread = (follower.Index - (count + 1) / 2) * 3
				local bob = math.sin(t * 3 + follower.Index) * 0.35
				local target = root.CFrame * CFrame.new(spread, 1.5 + bob, 4.5 + math.abs(spread) * 0.3)
				local current = follower.Pose
				local nextCFrame = if not current or (current.Position - target.Position).Magnitude > 40 then target else current:Lerp(target, 0.15)
				follower.Pose = nextCFrame
				for _, p in follower.Model:GetChildren() do
					if p:IsA("BasePart") then
						p.CFrame = nextCFrame * (offsets[p] or CFrame.new())
					end
				end
			end
		end
	end
end

function BotFollowers.init()
	folder = Instance.new("Folder")
	folder.Name = "BotFollowers"
	folder.Parent = Workspace

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)

	-- Re-apply the "hide other bots" setting when it changes.
	local lastHide = nil
	State.listen(function(state)
		if state.Settings.HideBots ~= lastHide then
			lastHide = state.Settings.HideBots
			for _, player in Players:GetPlayers() do
				rebuild(player)
			end
		end
	end)

	RunService.RenderStepped:Connect(step)
end

BotFollowers.count = function(player: Player): number
	return #(followers[player] or {})
end

return BotFollowers
