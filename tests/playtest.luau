-- Headless playtest: boots the real server and client code against tests/mock.luau.
-- Run with tests/run.sh
local DIR = __ARGS[2] .. "/tests"
local ROOT = __ARGS[2] .. "/src"
local M = (__loadsrc(__readfile(DIR .. "/mock.luau"), "mock"))()
local S = M.services

local passed, failed = 0, 0
local function check(cond, msg)
	if cond then
		passed += 1
		print("  ok   " .. msg)
	else
		failed += 1
		print("  FAIL " .. msg)
	end
end

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

local shared = M.mount(S.ReplicatedStorage, "Shared", ROOT .. "/shared", filesUnder("shared"))
local server = M.mount(S.ServerScriptService, "Server", ROOT .. "/server", filesUnder("server"))
local starterScripts = M.newInstance("Folder")
starterScripts.Name = "StarterPlayerScripts"
starterScripts.Parent = S.StarterPlayer
local client = M.mount(starterScripts, "Client", ROOT .. "/client", filesUnder("client"))

print("== Formulas")
M.context = "server"
local Config = require(shared.Config)
local Formulas = require(shared.Formulas)
check(Formulas.getCapacity({ Capacity = 0 }) == 10, "starting capacity is 10")
check(Formulas.getCapacity({ Capacity = 3 }) == 25, "capacity grows 5 per level")
check(math.abs(Formulas.getCooldown({ Speed = 0 }) - 1.6) < 1e-9, "base cooldown 1.6")
check(Formulas.getCooldown({ Speed = 10 }) >= Config.Gameplay.MinCooldown, "cooldown clamped at min")
check(Formulas.getUpgradePrice("Capacity", 0) == 40, "first capacity price")
check(Formulas.getUpgradePrice("Capacity", 10) == nil, "maxed upgrade has no price")
check(Formulas.getUpgradePrice("BetterTools", 4) == nil, "tools max at level 4")
check(Formulas.formatCash(1234567) == "$1,234,567", "cash formatting")
for _, u in Config.Upgrades do
	check(#u.Prices == u.MaxLevel, `{u.Id} has a price per level`)
end
-- distribution
local rng = Random and Random.new(1) or nil
do
	-- Random isn't in plain Luau; emulate
	local R = {}
	R.__index = R
	function R:NextNumber(a, b)
		a = a or 0
		b = b or 1
		return a + math.random() * (b - a)
	end
	function R:NextInteger(a, b)
		return math.random(a, b)
	end
	_G.Random = { new = function()
		return setmetatable({}, R)
	end }
	Random = _G.Random
	rng = Random.new()
end
local counts = {}
for _ = 1, 20000 do
	local s = Formulas.rollScrap(rng, 1)
	counts[s.Id] = (counts[s.Id] or 0) + 1
end
check(counts.CommonMetal > counts.CopperWire and counts.CopperWire > counts.ElectronicParts and counts.ElectronicParts > counts.RareMechanical, "rarity ordering holds at luck 1")
print(`    luck1: common {counts.CommonMetal} copper {counts.CopperWire} elec {counts.ElectronicParts} rare {counts.RareMechanical}`)
local counts3 = {}
for _ = 1, 20000 do
	local s = Formulas.rollScrap(rng, 3.2 * 1.35)
	counts3[s.Id] = (counts3[s.Id] or 0) + 1
end
print(`    best: common {counts3.CommonMetal} copper {counts3.CopperWire} elec {counts3.ElectronicParts} rare {counts3.RareMechanical}`)
check(counts3.RareMechanical > counts.RareMechanical * 3, "luck boosts rare drops")

print("== Server boot")
M.spawnPosition = Vector3.new(0, 3, 190)
M.runScript(server.Main, "server")
M.advance(0.1)
check(#M.errors == 0, "server boot without errors")
local map = S.Workspace:FindFirstChild("Junkyard")
check(map ~= nil, "map built")
local partCount = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
		if not d.Anchored then
			print("    unanchored: " .. d:GetFullName())
		end
	end
end
print("    part count: " .. partCount)
check(partCount < 1500, "map is reasonably sized")
local piles = S.CollectionService:GetTagged("ScrapPile")
check(#piles == 18, "18 scrap piles")
check(#S.CollectionService:GetTagged("SellStation") == 1, "sell station tagged")
check(#S.CollectionService:GetTagged("UpgradeShop") == 1, "upgrade shop tagged")
check(S.Players.CharacterAutoLoads == false, "manual character loading")
check(S.ReplicatedStorage:FindFirstChild("Remotes") ~= nil, "remotes created")

print("== Player join")
M.datastore = {}
local player = M.addPlayer("Tester", 101)
M.advance(0.5)
check(#M.errors == 0, "join without errors")
check(player.Character ~= nil, "character spawned")
local leaderstats = player:FindFirstChild("leaderstats")
check(leaderstats and leaderstats.Cash.Value == 0, "leaderstats cash 0")
local function equippedTool()
	for _, c in player.Character:GetChildren() do
		if c:IsA("Tool") then
			return c
		end
	end
end
check(equippedTool() and equippedTool().Name == "Rusty Grabber", "starts with Rusty Grabber equipped")

print("== Client boot")
S.Players.LocalPlayer = player
M.clientPlayer = player
M.runScript(client.Main, "client")
M.advance(0.5)
M.context = "server"
check(#M.errors == 0, "client boot without errors")
local gui = player.PlayerGui:FindFirstChild("JunkyardUI")
check(gui ~= nil, "UI created")
local panel = gui.StatsPanel
check(panel.CapacityText.Text == "Backpack 0/10", "HUD shows 0/10")
check(gui.Hint.Text:find("scrap pile") ~= nil, "new player hint shown")
local anyPrompt = piles[1].PromptAnchor.CollectPrompt
check(math.abs(anyPrompt.HoldDuration - 1.6) < 1e-6, "client set hold duration to cooldown")

local DataService = require(server.Services.DataService)
local function profile()
	return DataService.get(player)
end
local function moveTo(pos)
	player.Character.HumanoidRootPart.CFrame = CFrame.new(pos)
end
local function lastRemote(name)
	for i = #M.remoteLog, 1, -1 do
		if M.remoteLog[i].name == name then
			return M.remoteLog[i], i
		end
	end
end
local function trigger(prompt)
	prompt.Triggered:Fire(player)
	M.advance(0.01)
end

print("== Collection")
local pile = piles[1]
local prompt = pile.PromptAnchor.CollectPrompt
-- too far
moveTo(Vector3.new(500, 3, 500))
trigger(prompt)
check(DataService.getUsedSlots(profile()) == 0, "rejects collection from far away")
moveTo(pile.PromptAnchor.Position + Vector3.new(3, 0, 0))
trigger(prompt)
check(DataService.getUsedSlots(profile()) == 1, "collects 1 item")
local col = lastRemote("Collected")
check(col and #col.args[1] == 1, "Collected effect sent")
check(panel.CapacityText.Text == "Backpack 1/10", "HUD updated to 1/10")
trigger(prompt)
check(DataService.getUsedSlots(profile()) == 1, "cooldown blocks instant re-collect")
M.advance(1.6)
local chargesBefore = pile:GetAttribute("Charges")
trigger(prompt)
check(DataService.getUsedSlots(profile()) == 2, "collects after cooldown")
check(pile:GetAttribute("Charges") == chargesBefore - 1, "pile charge consumed")
check(prompt.ObjectText:find("left") ~= nil, "prompt shows charges left")

-- unequip tool -> rejected
local tool = equippedTool()
tool.Parent = player.Backpack
M.advance(2)
trigger(prompt)
check(DataService.getUsedSlots(profile()) == 2, "needs tool equipped")
local note = lastRemote("Notify")
check(note and note.args[1]:find("Equip") ~= nil, "tells player to equip")
tool.Parent = player.Character

-- deplete and respawn
local depleteGuard = 0
while pile:GetAttribute("Active") and depleteGuard < 20 do
	M.advance(2)
	trigger(prompt)
	depleteGuard += 1
end
check(pile:GetAttribute("Active") == false and prompt.Enabled == false, "pile depletes")
local junk
for _, d in pile:GetChildren() do
	if d.Name ~= "Mound" and d.Name ~= "PromptAnchor" then
		junk = d
	end
end
check(junk.Transparency == 1, "depleted junk hidden")
check(pile.Mound.Transparency == 0, "mound stays")
M.advance(Config.ScrapPiles.RespawnTime + 0.5)
check(pile:GetAttribute("Active") == true and prompt.Enabled == true, "pile respawns")
check(junk.Transparency == junk:GetAttribute("OriginalTransparency"), "junk visible again")

-- fill to capacity
local guard = 0
while DataService.getUsedSlots(profile()) < 10 and guard < 100 do
	M.advance(2)
	trigger(prompt)
	guard += 1
end
check(DataService.getUsedSlots(profile()) == 10, "filled to capacity")
M.advance(2)
local activePile = piles[2]
moveTo(activePile.PromptAnchor.Position + Vector3.new(2, 0, 0))
trigger(activePile.PromptAnchor.CollectPrompt)
check(DataService.getUsedSlots(profile()) == 10, "cannot exceed capacity")
note = lastRemote("Notify")
check(note and note.args[1]:find("full") ~= nil, "backpack full message")
check(gui.Hint.Text:find("full") ~= nil, "full hint shown")

print("== Selling")
local sell = S.CollectionService:GetTagged("SellStation")[1]
local sellPrompt = sell.PromptAnchor.SellPrompt
local expected = 0
for _, scrap in Config.ScrapTypes do
	expected += profile().Inventory[scrap.Id] * scrap.Value
end
sellPrompt.Triggered:Fire(player)
M.advance(0.01)
check(profile().Cash == 0, "sell rejected when far away")
moveTo(sell.PromptAnchor.Position + Vector3.new(4, 0, 0))
sellPrompt.Triggered:Fire(player)
M.advance(1)
check(profile().Cash == expected and expected > 0, `sold for correct total ({expected})`)
check(DataService.getUsedSlots(profile()) == 0, "inventory emptied")
check(leaderstats.Cash.Value == expected, "leaderstats updated")
check(gui.StatsPanel.Cash.Text == Formulas.formatCash(expected), "HUD cash updated")
check(gui.SalePopup.Visible == true and gui.SalePopup.Amount.Text == "+" .. Formulas.formatCash(expected), "sale popup shown")
sellPrompt.Triggered:Fire(player)
M.advance(0.01)
check(profile().Cash == expected, "selling empty does nothing")

print("== Shop")
local shop = S.CollectionService:GetTagged("UpgradeShop")[1]
local purchase = S.ReplicatedStorage.Remotes.PurchaseUpgrade
local invoke = function(...)
	return purchase.OnServerInvoke(player, ...)
end
profile().Cash = 30
local ok, msg = invoke("Capacity")
check(ok == false and msg:find("Upgrade Shop") ~= nil, "purchase rejected away from shop")
moveTo(shop.PromptAnchor.Position + Vector3.new(3, 0, 0))
M.advance(1)
ok, msg = invoke("Capacity")
check(ok == false and profile().Cash == 30, "rejects unaffordable: " .. tostring(msg))
M.advance(1)
ok = invoke(nil)
check(ok == false, "rejects nil id")
M.advance(1)
ok = invoke({ Id = "Capacity" })
check(ok == false, "rejects table id")
M.advance(1)
ok = invoke("Cash")
check(ok == false, "rejects unknown id")
M.advance(1)
profile().Cash = 100000
ok, msg = invoke("Capacity")
check(ok == true and profile().Levels.Capacity == 1 and profile().Cash == 100000 - 40, "buys capacity: " .. tostring(msg))
ok = invoke("Capacity")
check(ok == false, "purchase throttle")
M.advance(1)
ok = invoke("Speed")
check(ok and profile().Levels.Speed == 1, "buys speed")
M.advance(0.1)
check(math.abs(prompt.HoldDuration - Formulas.getCooldown(profile().Levels)) < 1e-6, "hold duration follows speed upgrade")
M.advance(1)
ok = invoke("BetterTools")
M.advance(0.1)
check(ok and equippedTool() and equippedTool().Name == "Steel Grabber", "better tool equipped after upgrade")
local toolCount = 0
for _, c in player.Backpack:GetChildren() do
	toolCount += 1
end
check(toolCount == 0, "no duplicate tools in backpack")
for _ = 1, 10 do
	M.advance(1)
	invoke("BetterTools")
end
check(profile().Levels.BetterTools == 4, "tools cap at max level")
check(equippedTool().Name == "Plasma Extractor", "best tool equipped")

print("== Shop UI")
S.ReplicatedStorage.Remotes.OpenShop:FireClient(player)
M.advance(0.1)
local window = gui.ShopWindow
check(window.Visible == true, "shop opens from prompt event")
local capCard = window.Cards.Capacity
check(capCard.Level.Text == "Level 1/10", "card shows level")
M.advance(1)
local cashBefore = profile().Cash
M.context = "client"
capCard.Buy.Activated:Fire()
M.advance(0.5)
M.context = "server"
check(profile().Levels.Capacity == 2 and profile().Cash < cashBefore, "UI buy button purchases")
check(capCard.Level.Text == "Level 2/10", "card refreshes after purchase")
check(window.Cards.BetterTools.Buy.Text == "MAXED", "maxed card shows MAXED")
profile().Cash = 0
DataService.changed(player)
M.advance(0.1)
check(capCard.Buy.Text == Formulas.formatCash(Formulas.getUpgradePrice("Capacity", 2)), "unaffordable price shown")
moveTo(Vector3.new(0, 3, 0))
M.advance(1)
check(window.Visible == false, "shop auto-closes when walking away")

print("== Tool yield")
profile().Cash = 0
moveTo(piles[5].PromptAnchor.Position + Vector3.new(2, 0, 0))
local before = DataService.getUsedSlots(profile())
M.advance(2)
trigger(piles[5].PromptAnchor.CollectPrompt)
check(DataService.getUsedSlots(profile()) - before == 3, "Plasma Extractor yields 3")

print("== Respawn")
player.Character.Humanoid.Died:Fire()
M.advance(6)
check(player.Character and equippedTool() ~= nil and equippedTool().Name == "Plasma Extractor", "tool restored after respawn")

print("== Persistence")
profile().Cash = 777
M.removePlayer(player)
M.advance(1)
local saved = M.datastore["player_101"]
check(saved and saved.Cash == 777 and saved.Levels.BetterTools == 4, "profile saved on leave")
saved.Cash = -50
saved.Levels.Capacity = 999
saved.Levels.Hack = 5
saved.Inventory.CommonMetal = 1e9
local player2 = M.addPlayer("Tester", 101)
M.advance(0.5)
local p2 = DataService.get(player2)
check(p2.Cash == 0 and p2.Levels.Capacity == 10 and p2.Levels.Hack == nil, "corrupt save sanitized")
check(DataService.getUsedSlots(p2) <= Formulas.getCapacity(p2.Levels), "inventory clamped to capacity")

print("== DataStore failure")
M.datastoreFails = true
M.datastore["player_202"] = { Cash = 5000 }
local player3 = M.addPlayer("Unlucky", 202)
M.advance(10)
local p3 = DataService.get(player3)
check(p3 ~= nil and p3.Cash == 0, "loads fresh profile on failure")
M.datastoreFails = false
p3.Cash = 1
M.removePlayer(player3)
M.advance(1)
check(M.datastore["player_202"].Cash == 5000, "does not overwrite save that failed to load")

print("")
print(`errors captured: {#M.errors}`)
for _, e in M.errors do
	print(e)
end
print(`RESULT: {passed} passed, {failed} failed`)
if failed > 0 or #M.errors > 0 then
	error("playtest failed", 0)
end
