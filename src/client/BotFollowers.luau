--!strict
-- Renders every player's equipped Scrap Bots (the detailed BotArt models) as
-- little robots that hover and hop behind them. Purely visual and local; the
-- server only publishes the "Bots" attribute ("BotId,BotId:g,...").
--
-- Each bot's parts are welded to one anchored root, so moving a bot is a single
-- CFrame write per frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BotArt = require(ReplicatedStorage.Shared.Art.BotArt)
local Bots = require(ReplicatedStorage.Shared.Bots)
local Kit = require(ReplicatedStorage.Shared.Art.Kit)
local State = require(script.Parent.State)

local BotFollowers = {}

local SCALE = 0.7

type Follower = { Model: Model, Root: BasePart, Index: number, Pose: CFrame?, Style: string }
local followers: { [Player]: { Follower } } = {}
local folder: Folder

-- Builds a bot and welds everything to an invisible anchored root at its centre.
local function buildFollower(id: string, golden: boolean): (Model, BasePart)
	local model = BotArt.build(id, golden)
	Kit.scale(model, SCALE)
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.2
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
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
			local model, root = buildFollower(id, flag == "g")
			model.Parent = folder
			table.insert(list, { Model = model, Root = root, Index = i, Style = Bots.ById[id].Style })
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
			local moving = root.AssemblyLinearVelocity.Magnitude > 2
			for _, follower in list do
				local spread = (follower.Index - (count + 1) / 2) * 3.2
				local phase = t * (if moving then 9 else 3) + follower.Index
				-- Walkers hop while you move; flyers float.
				local lift = if follower.Style == "Crawler" or follower.Style == "Cube"
					then math.abs(math.sin(phase)) * (if moving then 0.9 else 0.25)
					else 1.0 + math.sin(phase * 0.6) * 0.4
				local target = root.CFrame * CFrame.new(spread, -1.6 + lift, 4.2 + math.abs(spread) * 0.35)
				local current = follower.Pose
				local nextPose = if not current or (current.Position - target.Position).Magnitude > 40 then target else current:Lerp(target, 0.18)
				follower.Pose = nextPose
				follower.Root.CFrame = nextPose
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

function BotFollowers.count(player: Player): number
	return #(followers[player] or {})
end

return BotFollowers
