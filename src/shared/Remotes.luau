--!strict
-- One place for remote names. The server creates them; the client waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local EVENTS = {
	"StateChanged", -- server -> client: full player state snapshot
	"Notify", -- server -> client: toast message
	"Collected", -- server -> client: collection effect data
	"Sold", -- server -> client: sale summary
	"OpenPanel", -- server -> client: player used a station prompt (shop, tools, rebirth...)
	"Hatched", -- server -> client: crate opening result
	"Announce", -- server -> all clients: big server-wide banner
}

local FUNCTIONS = {
	"GetState", -- client -> server: initial snapshot
	"Request", -- client -> server: (action, ...) routed and validated by RequestRouter
}

local folder: Folder

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing then
			existing:Destroy()
		end
		local newFolder = Instance.new("Folder")
		newFolder.Name = "Remotes"
		for _, name in EVENTS do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = newFolder
		end
		for _, name in FUNCTIONS do
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = newFolder
		end
		newFolder.Parent = ReplicatedStorage
		folder = newFolder
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return folder
end

function Remotes.event(name: string): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
