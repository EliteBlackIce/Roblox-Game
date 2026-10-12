--!strict
-- Local view of zone gates: barriers you've unlocked stop colliding for you and
-- turn see-through. Characters are simulated on the client, so this is all it
-- takes to let you through; the server still refuses to let you collect in a
-- zone you haven't paid for.

local CollectionService = game:GetService("CollectionService")

local State = require(script.Parent.State)

local Gates = {}

local function apply(gate: Instance, unlocked: boolean)
	local barrier = gate:FindFirstChild("Barrier")
	if barrier and barrier:IsA("BasePart") then
		barrier.CanCollide = not unlocked
		barrier.Transparency = if unlocked then 0.9 else 0.45
	end
	local sign = gate:FindFirstChild("PriceSign")
	if sign and sign:IsA("BasePart") then
		sign.Transparency = if unlocked then 1 else 0
		sign.CanCollide = not unlocked
		local gui = sign:FindFirstChildOfClass("SurfaceGui")
		if gui then
			gui.Enabled = not unlocked
		end
	end
	local anchor = gate:FindFirstChild("PromptAnchor")
	local prompt = anchor and anchor:FindFirstChild("UnlockPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = not unlocked
	end
end

function Gates.init()
	local function refresh(state: any)
		for _, gate in CollectionService:GetTagged("ZoneGate") do
			apply(gate, state.Zones[gate:GetAttribute("ZoneId") or ""] == true)
		end
	end
	State.listen(refresh)
	CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(function()
		if State.current then
			refresh(State.current)
		end
	end)
end

return Gates
