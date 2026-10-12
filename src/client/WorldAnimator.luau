--!strict
-- Client-only idle animation for the world: every model tagged "Hover" spins
-- (HoverSpin, degrees per second) and bobs (HoverBob, studs) around its
-- bounding-box centre. Purely visual; the server's copies never move.
-- All parts move with one workspace:BulkMoveTo call per frame.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WorldAnimator = {}

type Entry = {
	Parts: { BasePart },
	Offsets: { CFrame },
	Center: CFrame,
	Spin: number,
	Bob: number,
	Phase: number,
}

local entries: { [Instance]: Entry } = {}
local MAX_DISTANCE = 220

local function register(model: Instance)
	if entries[model] then
		return
	end
	local parts: { BasePart } = {}
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			lo = Vector3.new(math.min(lo.X, d.Position.X), math.min(lo.Y, d.Position.Y), math.min(lo.Z, d.Position.Z))
			hi = Vector3.new(math.max(hi.X, d.Position.X), math.max(hi.Y, d.Position.Y), math.max(hi.Z, d.Position.Z))
		end
	end
	if #parts == 0 then
		return
	end
	local center = CFrame.new((lo + hi) / 2)
	local offsets = table.create(#parts)
	for i, part in parts do
		offsets[i] = center:Inverse() * part.CFrame
	end
	entries[model] = {
		Parts = parts,
		Offsets = offsets,
		Center = center,
		Spin = math.rad(model:GetAttribute("HoverSpin") or 0),
		Bob = model:GetAttribute("HoverBob") or 0,
		Phase = (center.Position.X + center.Position.Z) * 0.1,
	}
end

function WorldAnimator.step(t: number, focus: Vector3?)
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for _, entry in entries do
		if not focus or (entry.Center.Position - focus).Magnitude < MAX_DISTANCE then
			local pose = entry.Center * CFrame.new(0, math.sin(t * 1.6 + entry.Phase) * entry.Bob, 0) * CFrame.Angles(0, t * entry.Spin, 0)
			for i, part in entry.Parts do
				table.insert(parts, part)
				table.insert(cframes, pose * entry.Offsets[i])
			end
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function WorldAnimator.count(): number
	local n = 0
	for _ in entries do
		n += 1
	end
	return n
end

function WorldAnimator.init(getFocus: () -> Vector3?)
	for _, model in CollectionService:GetTagged("Hover") do
		register(model)
	end
	-- With streaming, models can arrive (and leave) at any time.
	CollectionService:GetInstanceAddedSignal("Hover"):Connect(function(model)
		task.defer(register, model)
	end)
	CollectionService:GetInstanceRemovedSignal("Hover"):Connect(function(model)
		entries[model] = nil
	end)
	local start = os.clock()
	RunService.RenderStepped:Connect(function()
		WorldAnimator.step(os.clock() - start, getFocus())
	end)
end

return WorldAnimator
