-- Headless playtest: boots the real server and client code against
-- tests/mock.luau and drives every system like a player (and an exploiter) would.
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

---------------------------------------------------------------- formulas
print("== Formulas")
M.context = "server"
local Config = require(shared.Config)
local Formulas = require(shared.Formulas)
local Zones = require(shared.Zones)
local Bots = require(shared.Bots)
local Tools = require(shared.Tools)
local Rebirth = require(shared.Rebirth)
local Quests = require(shared.Quests)

check(Formulas.capacityFor(0, false) == 10, "starting capacity is 10")
check(Formulas.capacityFor(2, true) == 30, "mega backpack gives +50%")
check(math.abs(Formulas.cooldownFor(0) - 1.6) < 1e-9, "base cooldown 1.6s")
check(Formulas.cooldownFor(15) >= Config.Gameplay.MinCooldown, "cooldown clamped at minimum")
check(Formulas.upgradePrice("Backpack", 0) == 40, "first backpack upgrade costs $40")
check(Formulas.upgradePrice("Backpack", 40) == nil, "maxed upgrade has no price")
check(Formulas.formatNumber(1234) == "1,234", "formats thousands")
check(Formulas.formatNumber(12500) == "12.5K", "formats K")
check(Formulas.formatNumber(3400000) == "3.4M", "formats M")
check(Formulas.formatNumber(250000000000) == "250B", "formats B")
check(#Zones.List == 6 and #Zones.ItemOrder == 42, "6 zones, 42 items")
check(#Tools == 8, "8 tools")
check(#Bots.List == 20 and #Bots.Crates == 4, "20 bots (incl. 4 Secrets) in 4 crates")
for _, crate in Bots.Crates do
	for _, drop in crate.Drops do
		assert(Bots.ById[drop.Bot], "crate drop references missing bot " .. drop.Bot)
	end
end
check(true, "every crate drop exists")
for _, zone in Zones.List do
	local tiers = {}
	for _, item in zone.Items do
		tiers[Config.RarityById[item.Rarity].Tier] = true
	end
	check(#zone.Items == 7 and tiers[0] and tiers[5], `{zone.Name} has a full rarity ladder`)
end

local rng = Random.new(42)
local scrapHeap = Zones.ById.ScrapHeap
local counts = {}
for _ = 1, 20000 do
	local item = Formulas.rollItem(rng, scrapHeap, 1, false)
	counts[item.Rarity] = (counts[item.Rarity] or 0) + 1
end
check((counts.Common or 0) > (counts.Uncommon or 0) and (counts.Uncommon or 0) > (counts.Rare or 0) and (counts.Rare or 0) > (counts.Epic or 0), "rarity ordering at luck 1")
check(counts.Mythic == nil, "Mythic never drops from normal piles")
print(`    luck1: C {counts.Common} U {counts.Uncommon} R {counts.Rare} E {counts.Epic} L {counts.Legendary or 0}`)
local golden = {}
for _ = 1, 5000 do
	local item = Formulas.rollItem(rng, scrapHeap, 8, true)
	golden[item.Rarity] = (golden[item.Rarity] or 0) + 1
end
check(golden.Common == nil and golden.Uncommon == nil, "golden piles skip Common/Uncommon")
check((golden.Mythic or 0) > 50 and (golden.Mythic or 0) < 300, `golden Mythic rate ~3% ({golden.Mythic})`)
local hatchCounts = {}
for _ = 1, 10000 do
	local bot = Formulas.rollBot(rng, Bots.CrateById.Rusty)
	hatchCounts[bot.Id] = (hatchCounts[bot.Id] or 0) + 1
end
check(hatchCounts.BoltBot > hatchCounts.GearGolem * 10, "crate odds respected")
check(Rebirth.cost(0) == 400000 and Rebirth.cost(1) == 1200000, "rebirth cost curve")
local daily = Quests.pickDaily(100, 5)
check(#daily == 3 and daily[1] ~= daily[2] and daily[2] ~= daily[3] and daily[1] ~= daily[3], "3 distinct daily quests")
local again = Quests.pickDaily(100, 5)
check(again[1] == daily[1] and again[3] == daily[3], "daily pick is deterministic")

---------------------------------------------------------------- art
print("== Art")
for _, name in { "Items", "BotArt", "CrateArt", "ToolArt" } do
	local Art = require(shared.Art:FindFirstChild(name))
	local ids = Art.list()
	local okAll, minParts = true, math.huge
	for _, id in ids do
		local built, model = pcall(Art.build, id)
		if not built then
			okAll = false
			print("    build failed: " .. name .. "." .. id .. ": " .. tostring(model))
		else
			local n = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					n += 1
				end
			end
			minParts = math.min(minParts, n)
		end
	end
	check(okAll and minParts >= 5, `{name}: all {#ids} models build with real detail (min {minParts} parts)`)
end
check(#require(shared.Art.Items).list() == 42, "a model for every item")
local goldenBot = require(shared.Art.BotArt).build("BoltBot", true)
check(goldenBot:FindFirstChild("Part", true) ~= nil, "golden bot variant builds")
check(require(shared.Art.CrateArt).build("Gem"):FindFirstChild("Lid") ~= nil, "crates have a detachable lid")

---------------------------------------------------------------- boot
print("== Server boot")
-- Background events are triggered manually below, so park their timers.
Config.Events.FrenzyInterval = 1e9
Config.Events.GoldenPileInterval = { 1e9, 1e9 }
M.spawnPosition = Vector3.new(0, 3, 72)
M.runScript(server.Main, "server")
M.advance(0.1)
check(#M.errors == 0, "server boots without errors")
local map = S.Workspace:FindFirstChild("Junkyard")
check(map ~= nil, "map built")
local partCount, unanchored, textured = 0, 0, 0
local realistic = { CorrodedMetal = true, DiamondPlate = true, Ground = true, Asphalt = true, Pebble = true, Concrete = true, Wood = true, Metal = true, Fabric = true, Grass = true, Slate = true, Brick = true }
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
		if not d.Anchored then
			unanchored += 1
		end
		if d.Material and realistic[d.Material.Name] then
			textured += 1
		end
	end
end
print("    parts: " .. partCount)
check(unanchored == 0, "all scenery anchored")
check(textured == 0, "no realistic textures, only flat colour (SmoothPlastic/Neon)")
check(partCount < 25000, "map part budget")
local CS = S.CollectionService
local piles = CS:GetTagged("ScrapPile")
check(#piles == 96, "96 scrap piles (16 per zone)")
check(#CS:GetTagged("ZoneGate") == 5, "5 locked zone gates")
check(#CS:GetTagged("SellStation") == 6, "a sell pad in every zone")
check(#CS:GetTagged("CrateStand") == 4, "4 crate stands")
check(#CS:GetTagged("ZoneSpawn") == 7, "7 teleport targets")
for _, tag in { "UpgradeShop", "ToolShop", "RebirthAltar", "QuestBoard", "Leaderboard", "CodeTerminal" } do
	check(#CS:GetTagged(tag) == 1, tag .. " exists")
end
check(S.ReplicatedStorage:FindFirstChild("Remotes") ~= nil, "remotes created")

local function pilesIn(zoneId)
	local out = {}
	for _, pile in piles do
		if pile:GetAttribute("ZoneId") == zoneId then
			table.insert(out, pile)
		end
	end
	return out
end
local function tagged(tag, attr, value)
	for _, inst in CS:GetTagged(tag) do
		if attr == nil or inst:GetAttribute(attr) == value then
			return inst
		end
	end
end

---------------------------------------------------------------- join
print("== Player join")
M.datastore = {}
local player = M.addPlayer("Tester", 101)
M.advance(0.5)
check(#M.errors == 0, "join without errors")
check(player.Character ~= nil, "character spawned")
local leaderstats = player:FindFirstChild("leaderstats")
check(leaderstats and leaderstats.Cash.Value == "$0" and leaderstats.Rebirths.Value == 0, "leaderstats show $0 / Rebirth 0")
local function equippedTool()
	for _, c in player.Character:GetChildren() do
		if c:IsA("Tool") then
			return c
		end
	end
end
check(equippedTool() and equippedTool().Name == "Rusty Grabber", "starts with Rusty Grabber equipped")
do
	local tool = equippedTool()
	local welded, total = 0, 0
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Handle" then
			total += 1
			if d:FindFirstChildOfClass("WeldConstraint") and not d.Anchored then
				welded += 1
			end
		end
	end
	check(tool:FindFirstChild("Handle") and total > 5 and welded == total, `tool model welded to its handle ({total} parts)`)
end
check(player.Character.Humanoid.WalkSpeed == 16, "base walk speed")

local DataService = require(server.Services.DataService)
local RequestRouter = require(server.Services.RequestRouter)
local function profile()
	return DataService.get(player)
end
local function request(...)
	local ok, msg, data = RequestRouter.route(player, ...)
	return ok, msg, data
end
local function moveTo(pos)
	player.Character.HumanoidRootPart.CFrame = CFrame.new(pos)
end
local function near(inst)
	moveTo(inst.PromptAnchor.Position + Vector3.new(2, 0, 0))
end
local function lastRemote(name)
	for i = #M.remoteLog, 1, -1 do
		if M.remoteLog[i].name == name then
			return M.remoteLog[i]
		end
	end
end
local function trigger(prompt)
	prompt.Triggered:Fire(player)
	M.advance(0.01)
end
local function used()
	return DataService.getUsedSlots(profile())
end

---------------------------------------------------------------- client
print("== Client boot")
S.Players.LocalPlayer = player
M.clientPlayer = player
M.runScript(client.Main, "client")
M.advance(0.5)
M.context = "server"
check(#M.errors == 0, "client boots without errors")
local gui = player.PlayerGui:FindFirstChild("JunkyardUI")
check(gui ~= nil, "UI created")
check(gui.StatsPanel.Backpack.Text == "Backpack 0/10", "HUD shows 0/10")
check(gui.QuestTracker.Visible and gui.QuestTracker:GetDescendants() ~= nil, "quest tracker visible")
check(gui.Hint.Text:find("scrap pile") ~= nil, "new player hint")
check(gui.Menu:FindFirstChild("StoreButton") == nil, "store hidden when no products are configured")
check(gui.Menu:FindFirstChild("BotsButton") ~= nil and gui.Menu:FindFirstChild("RebirthButton") ~= nil, "menu buttons exist")
check(gui.Menu.BotsButton:FindFirstChildOfClass("ViewportFrame") ~= nil, "menu buttons show 3D icons")
local WorldAnimator
M.context = "client"
WorldAnimator = require(client.WorldAnimator)
M.context = "server"
check(WorldAnimator.count() >= 20, `world animator drives the hover models ({WorldAnimator.count()})`)
S.RunService.RenderStepped:Fire()
M.advance(0.05)
check((M.bulkMoves or 0) > 0, "hover animation moves parts with BulkMoveTo")
local heapPiles = pilesIn("ScrapHeap")
check(math.abs(heapPiles[1].PromptAnchor.CollectPrompt.HoldDuration - 1.6) < 1e-6, "client sets hold duration to cooldown")
local carGate = tagged("ZoneGate", "ZoneId", "CarGraveyard")
check(carGate.Barrier.CanCollide == true, "locked gate barrier blocks the player")

---------------------------------------------------------------- collection
print("== Collection")
local pile = heapPiles[1]
local prompt = pile.PromptAnchor.CollectPrompt
moveTo(Vector3.new(500, 3, 500))
trigger(prompt)
check(used() == 0, "rejects collection from far away")
near(pile)
trigger(prompt)
check(used() == 1, "collects 1 item")
check(lastRemote("Collected") ~= nil, "Collected effect sent")
check(gui.StatsPanel.Backpack.Text == "Backpack 1/10", "HUD updated")
check(profile().Stats.Collected == 1, "Collected stat counted")
local anyDiscovered = next(profile().Discovered) ~= nil
check(anyDiscovered, "item discovered in index")
trigger(prompt)
check(used() == 1, "cooldown blocks instant re-collect")

local carPile = pilesIn("CarGraveyard")[1]
near(carPile)
M.advance(2)
trigger(carPile.PromptAnchor.CollectPrompt)
check(used() == 1, "can't collect in a locked zone")
check(lastRemote("Notify").args[1]:find("unlocked") ~= nil, "locked zone message")

near(pile)
local tool = equippedTool()
tool.Parent = player.Backpack
M.advance(2)
trigger(prompt)
check(used() == 1, "needs tool equipped")
tool.Parent = player.Character

-- Depletion and respawn.
local guard = 0
while pile:GetAttribute("Active") and guard < 20 do
	M.advance(2)
	trigger(prompt)
	guard += 1
end
check(pile:GetAttribute("Active") == false and prompt.Enabled == false, "pile depletes")
local junk
for _, d in pile:GetDescendants() do
	if d:IsA("BasePart") and d.Name ~= "PromptAnchor" and not d:GetAttribute("Persistent") then
		junk = d
	end
end
check(junk.Transparency == 1, "depleted junk hidden")
check(pile.Mound.Transparency == 0, "mound stays")
M.advance(Config.ScrapPiles.RespawnTime + 0.5)
check(pile:GetAttribute("Active") == true and junk.Transparency == junk:GetAttribute("OriginalTransparency"), "pile respawns")

-- Fill up across piles.
local function collectUntilFull()
	local tries = 0
	while used() < Formulas.getCapacity(profile(), DataService.context(player)) and tries < 400 do
		for _, p in heapPiles do
			if p:GetAttribute("Active") then
				near(p)
				M.advance(2)
				trigger(p.PromptAnchor.CollectPrompt)
				break
			end
		end
		tries += 1
	end
end
collectUntilFull()
check(used() == 10, "filled to capacity")
local activePile
for _, p in heapPiles do
	if p:GetAttribute("Active") then
		activePile = p
	end
end
near(activePile)
M.advance(2)
trigger(activePile.PromptAnchor.CollectPrompt)
check(used() == 10, "cannot exceed capacity")
check(lastRemote("Notify").args[1]:find("full") ~= nil, "backpack full message")
check(gui.Hint.Text:find("full") ~= nil, "full hint shown")
check(profile().Quest.Index >= 2, "quest 1 (collect 10) completed automatically")

---------------------------------------------------------------- selling
print("== Selling")
local sellPad = tagged("SellStation")
local expected = math.floor(Formulas.inventoryValue(profile().Inventory) * Formulas.getCashMultiplier(profile(), DataService.context(player)))
local cashBefore = profile().Cash
sellPad.PromptAnchor.SellPrompt.Triggered:Fire(player)
M.advance(0.01)
check(profile().Cash == cashBefore, "sell rejected when far away")
near(sellPad)
sellPad.PromptAnchor.SellPrompt.Triggered:Fire(player)
M.advance(0.5)
check(used() == 0, "backpack emptied")
check(profile().Stats.SoldCash == expected and expected > 0, `sold for the exact server-side total ({expected})`)
check(gui.SalePopup.Visible == true, "sale popup shown")
check(gui.StatsPanel.Cash.Value.Text == Formulas.formatCash(profile().Cash), "HUD cash updated")
local ok, msg = request("Sell")
check(not ok and msg:find("Remote Sell") ~= nil, "remote sell needs the perk")

---------------------------------------------------------------- exploits
print("== Exploit attempts")
check(not request("GiveMeCash"), "unknown action rejected")
check(not request(nil), "nil action rejected")
check(not request({}), "table action rejected")
M.advance(1)
check(not request("BuyUpgrade", { Id = "Backpack" }), "table upgrade id rejected")
check(not request("Teleport", "CrashSite"), "teleport to locked zone rejected")
check(not request("EquipBot", "999"), "equip unowned bot rejected")
check(not request("SetSetting", "Cash", true), "unknown setting rejected")
check(not request("SetSetting", "Sfx", "yes"), "non-boolean setting rejected")
check(not request("UnlockZone", "CarGraveyard"), "unlock away from the gate rejected")
check(not request("Hatch", "Rusty", 1), "hatch away from the crate rejected")
check(not request("BuyTool"), "buy tool away from the shop rejected")
check(not request("RedeemCode", string.rep("A", 100)), "overlong code rejected")
M.advance(1)

---------------------------------------------------------------- upgrades & tools
print("== Upgrades & tools")
local upgradeShop = tagged("UpgradeShop")
profile().Cash = 10
DataService.changed(player)
check(not request("BuyUpgrade", "Backpack"), "upgrade rejected away from shop")
near(upgradeShop)
M.advance(1)
ok, msg = request("BuyUpgrade", "Backpack")
check(not ok and profile().Cash == 10, "unaffordable upgrade rejected: " .. tostring(msg))
profile().Cash = 1000000
M.advance(1)
ok = request("BuyUpgrade", "Backpack")
check(ok and profile().Levels.Backpack == 1 and profile().Cash == 1000000 - 40, "bought Backpack level 1 for $40")
check(not request("BuyUpgrade", "Backpack"), "request throttle")
M.advance(1)
request("BuyUpgrade", "Sneakers")
M.advance(0.1)
check(player.Character.Humanoid.WalkSpeed > 16, "sneakers raise walk speed")
M.advance(1)
request("BuyUpgrade", "Speed")
M.advance(0.1)
check(math.abs(heapPiles[1].PromptAnchor.CollectPrompt.HoldDuration - Formulas.getCooldown(profile(), DataService.context(player))) < 1e-6, "hold duration follows Speed upgrade")
M.advance(1)
request("BuyUpgrade", "Luck")
check(profile().Levels.Luck == 1, "bought Luck")

-- Shop UI button.
S.ReplicatedStorage.Remotes.OpenPanel:FireClient(player, "Upgrades")
M.advance(0.1)
local upgradesPanel = gui.UpgradesPanel
check(upgradesPanel.Visible, "upgrade shop opens from server prompt")
local before = profile().Levels.Backpack
M.advance(1)
M.context = "client"
upgradesPanel.Content:FindFirstChild("Backpack", true).Buy.Activated:Fire()
M.advance(0.5)
M.context = "server"
check(profile().Levels.Backpack == before + 1, "UI buy button purchases")
check(upgradesPanel.Content:FindFirstChild("Backpack", true).Level.Text == `Level {before + 1}/40`, "card refreshes")
moveTo(Vector3.new(0, 3, 70))
M.advance(1)
check(not upgradesPanel.Visible, "shop auto-closes when walking away")

local toolShop = tagged("ToolShop")
near(toolShop)
M.advance(1)
ok = request("BuyTool")
M.advance(0.1)
check(ok and profile().ToolTier == 2 and equippedTool().Name == "Steel Grabber", "bought Steel Grabber")
check(gui.QuestTracker.Visible, "quest tracker still showing the current chain quest")

---------------------------------------------------------------- zones
print("== Zones")
local applianceGate = tagged("ZoneGate", "ZoneId", "ApplianceAlley")
near(applianceGate)
M.advance(1)
ok, msg = request("UnlockZone", "ApplianceAlley")
check(not ok and msg:find("first") ~= nil, "zones unlock in order")
near(carGate)
profile().Cash = 100
M.advance(1)
carGate.PromptAnchor.UnlockPrompt.Triggered:Fire(player)
M.advance(0.1)
check(not profile().Zones.CarGraveyard, "can't unlock without the cash")
profile().Cash = 1000000
M.advance(1)
carGate.PromptAnchor.UnlockPrompt.Triggered:Fire(player)
M.advance(0.1)
check(profile().Zones.CarGraveyard == true and profile().Cash == 1000000 - 750, "unlocked Car Graveyard for $750")
check(carGate.Barrier.CanCollide == false, "client opens the barrier after unlocking")
near(carPile)
M.advance(2)
trigger(carPile.PromptAnchor.CollectPrompt)
check(used() >= 1, "can collect in the newly unlocked zone")
local shipGate = tagged("ZoneGate", "ZoneId", "Shipyard")
profile().Zones.ApplianceAlley = true
profile().Zones.ElectronicsDump = true
profile().Cash = 1e9
near(shipGate)
M.advance(1)
ok, msg = request("UnlockZone", "Shipyard")
check(not ok and msg:find("Rebirth") ~= nil, "Shipyard needs Rebirth 1")
profile().Zones.ApplianceAlley = nil
profile().Zones.ElectronicsDump = nil

M.advance(1)
ok = request("Teleport", "CarGraveyard")
local spawnPart = tagged("ZoneSpawn", "ZoneId", "CarGraveyard")
check(ok and (player.Character.HumanoidRootPart.Position - spawnPart.Position).Magnitude < 6, "teleport to unlocked zone")
M.advance(1)
ok = request("Teleport", "Hub")
check(ok and player.Character.HumanoidRootPart.Position.Z > 50, "teleport to hub")

---------------------------------------------------------------- bots
print("== Scrap Bots")
local rustyStand = tagged("CrateStand", "CrateId", "Rusty")
near(rustyStand)
profile().Cash = 500
M.advance(1)
check(not request("Hatch", "Rusty", 1), "can't hatch without the cash")
profile().Cash = 100000
M.advance(1)
ok, msg, results = request("Hatch", "Rusty", 1)
M.advance(0.1)
check(ok and #profile().Bots == 1 and profile().Cash == 99000, "hatched a bot for $1,000")
check(#profile().Equipped == 1, "first bot auto-equipped")
check(player:GetAttribute("Bots") ~= "", "Bots attribute published for followers")
M.advance(0.1)
local BotFollowers
M.context = "client"
BotFollowers = require(client.BotFollowers)
M.context = "server"
check(BotFollowers.count(player) == 1, "client renders the bot follower")
local followerFolder = S.Workspace:FindFirstChild("BotFollowers")
local followerParts = 0
for _, d in followerFolder:GetDescendants() do
	if d:IsA("BasePart") then
		followerParts += 1
	end
end
check(followerParts > 15, `follower is the detailed bot model ({followerParts} parts)`)
check(gui:FindFirstChild("HatchOverlay") ~= nil, "hatch overlay exists")
-- Drive the 3D crate-opening animation frame by frame.
local function driveHatch(frames)
	local sawCrate, sawBot, titles = false, false, {}
	for _ = 1, frames do
		S.RunService.RenderStepped:Fire()
		if M.renderSteps and M.renderSteps.HatchShake then
			M.renderSteps.HatchShake()
		end
		M.advance(1 / 30)
		local fx = S.Workspace.CurrentCamera:FindFirstChild("HatchFX")
		if fx then
			for _, d in fx:GetChildren() do
				if d:IsA("Model") and d.Name:sub(1, 6) == "Crate_" then
					sawCrate = true
				elseif d:IsA("Model") and Bots.ById[d.Name] then
					sawBot = true
				end
			end
		end
		if gui.HatchOverlay.Title.Visible then
			titles[gui.HatchOverlay.Title.Text] = true
		end
	end
	return sawCrate, sawBot, titles
end
local sawCrate, sawBot = driveHatch(260)
check(sawCrate and sawBot, "hatch shows the 3D crate in front of the camera, then the 3D pet")
check(gui.HatchOverlay.Visible == false, "hatch animation finishes and closes")
-- A SECRET hatch plays its own sequence.
S.ReplicatedStorage.Remotes.Hatched:FireClient(player, "Rusty", { { Uid = "secret-test", Id = "TrashKing" } })
local _, sawSecretPet, titles = driveHatch(600)
check(sawSecretPet and titles["? ? ?"] and titles["SECRET!!!"], "secret hatch: blackout '? ? ?' then 'SECRET!!!'")
check(gui.HatchOverlay.Visible == false and not S.Lighting:FindFirstChild("HatchBlur"), "secret hatch cleans up blur and overlay")
M.advance(3)
ok = request("Hatch", "Rusty", 3)
check(ok and #profile().Bots == 4, "triple hatch")
M.advance(3)
ok = request("Hatch", "Rusty", 999)
check(ok and #profile().Bots == 5, "bogus count treated as 1")
M.advance(3)
rustyStand.PromptAnchor.OpenPrompt.Triggered:Fire(player)
M.advance(3)
check(#profile().Bots == 6, "crate prompt hatches")

local multBefore = Formulas.getCashMultiplier(profile(), DataService.context(player))
for _, owned in profile().Bots do
	if not table.find(profile().Equipped, owned.Uid) then
		M.advance(1)
		request("EquipBot", owned.Uid)
	end
end
check(#profile().Equipped == 3, "equip limited to 3 slots")
check(Formulas.getCashMultiplier(profile(), DataService.context(player)) >= multBefore, "bots raise the multiplier")
M.advance(1)
local firstUid = profile().Equipped[1]
check(request("UnequipBot", firstUid) and #profile().Equipped == 2, "unequip")
M.advance(1)
check(request("EquipBest") and #profile().Equipped == 3, "equip best")

-- Golden merge.
for _ = 1, 5 do
	table.insert(profile().Bots, { Uid = "t" .. profile().NextUid, Id = "SparkBug", Golden = false })
	profile().NextUid += 1
end
local countBefore = #profile().Bots
M.advance(1)
ok = request("GoldenBot", "SparkBug")
local goldenCount = 0
for _, owned in profile().Bots do
	if owned.Golden then
		goldenCount += 1
	end
end
check(ok and goldenCount == 1 and #profile().Bots <= countBefore - 4, "5 copies merge into a golden bot")
M.advance(1)
check(not request("GoldenBot", "NeonOwl"), "golden merge needs 5 copies")
M.advance(1)
local victim = profile().Bots[#profile().Bots].Uid
check(request("DeleteBot", victim) and not table.find(profile().Equipped, victim), "delete bot")

-- Bots UI.
S.ReplicatedStorage.Remotes.OpenPanel:FireClient(player, "Bots")
M.advance(0.1)
local botsPanel = gui.BotsPanel
local cardCount = 0
for _, d in botsPanel:GetDescendants() do
	if d.Name:sub(1, 4) == "Bot_" then
		cardCount += 1
	end
end
check(botsPanel.Visible and cardCount == #profile().Bots, "bots window lists every bot")

---------------------------------------------------------------- boosts & codes
print("== Boosts & codes")
profile().Gems = 10
M.advance(1)
check(not request("BuyBoost", "Cash"), "boost needs gems")
profile().Gems = 100
local m1 = Formulas.getCashMultiplier(profile(), DataService.context(player))
M.advance(1)
check(request("BuyBoost", "Cash") and profile().Gems == 60, "bought x2 cash boost")
local m2 = Formulas.getCashMultiplier(profile(), DataService.context(player))
check(math.abs(m2 / m1 - 2) < 1e-6, "cash boost doubles the multiplier")
M.advance(Config.Boosts[1].Duration + 2)
check(math.abs(Formulas.getCashMultiplier(profile(), DataService.context(player)) - m1) < 1e-6, "boost expires")
M.advance(1)
local gemsBefore = profile().Gems
ok, msg = request("RedeemCode", " release ")
check(ok and profile().Gems == gemsBefore + 20, "code redeemed (case/space-insensitive)")
M.advance(1)
check(not request("RedeemCode", "RELEASE"), "code can't be reused")
M.advance(1)
check(not request("RedeemCode", "NOTACODE"), "invalid code rejected")

---------------------------------------------------------------- quests
print("== Quests & login")
M.advance(1)
ok = request("ClaimLogin")
check(ok and profile().Login.Streak == 1, "claimed day 1 login reward")
M.advance(1)
check(not request("ClaimLogin"), "login reward once per day")
M.timeOffset += 86400
M.advance(1)
ok = request("ClaimLogin")
check(ok and profile().Login.Streak == 2, "streak continues next day")
M.advance(1)
check(not request("ClaimDaily", 1), "unfinished daily can't be claimed")
local dq = Quests.DailyById[profile().Daily.Ids[1]]
DataService.addStat(profile(), dq.Stat, dq.Goal)
gemsBefore = profile().Gems
M.advance(1)
ok = request("ClaimDaily", 1)
check(ok and profile().Gems == gemsBefore + dq.Reward.Gems, "finished daily claimed")
M.advance(1)
check(not request("ClaimDaily", 1), "daily can't be claimed twice")
check(not request("ClaimDaily", 9), "invalid daily index rejected")
S.ReplicatedStorage.Remotes.OpenPanel:FireClient(player, "Quests")
M.advance(0.2)
check(gui.QuestsPanel.Visible, "quests window opens")

---------------------------------------------------------------- events
print("== Events")
local EventService = require(server.Services.EventService)
local goldenPile = EventService.spawnGoldenPile()
M.advance(0.1)
check(goldenPile and goldenPile:GetAttribute("Golden") == true, "golden pile spawned")
check(lastRemote("Announce") and lastRemote("Announce").args[1]:find("GOLDEN") ~= nil, "golden pile announced")
local goldZone = goldenPile:GetAttribute("ZoneId")
check(profile().Zones[goldZone], "golden pile is in a zone the player can reach")
local pieceColor
for _, d in goldenPile:GetDescendants() do
	if d:IsA("BasePart") and d.Name ~= "PromptAnchor" and not d:GetAttribute("Persistent") then
		pieceColor = d.Color
	end
end
check(pieceColor and pieceColor.R > 0.9 and pieceColor.G > 0.7, "golden pile turns gold")
-- Empty the backpack then grab gold.
near(sellPad)
sellPad.PromptAnchor.SellPrompt.Triggered:Fire(player)
M.advance(0.5)
near(goldenPile)
gemsBefore = profile().Gems
M.advance(2)
trigger(goldenPile.PromptAnchor.CollectPrompt)
local got = lastRemote("Collected").args[1]
local allRare = true
for _, id in got do
	if Config.RarityById[Zones.Items[id].Rarity].Tier < 2 then
		allRare = false
	end
end
check(allRare, "golden pile gives Rare or better")
check(profile().Gems >= gemsBefore + Config.Events.GoldenGems, "golden pile gives gems")
check(profile().Stats.GoldenGrabs == 1, "golden grab counted")

local cashMult = Formulas.getCashMultiplier(profile(), DataService.context(player))
EventService.startFrenzy()
M.advance(0.1)
check(math.abs(Formulas.getCashMultiplier(profile(), DataService.context(player)) / cashMult - 2) < 1e-6, "frenzy doubles cash")
check(gui.Timers:FindFirstChild("Frenzy") ~= nil, "frenzy timer on HUD")
M.advance(Config.Events.FrenzyDuration + 2)
check(math.abs(Formulas.getCashMultiplier(profile(), DataService.context(player)) - cashMult) < 1e-6, "frenzy ends")

---------------------------------------------------------------- index
print("== Index")
local bonusBefore = Formulas.indexBonus(profile())
for _, item in Zones.ById.ScrapHeap.Items do
	if item.Rarity ~= "Mythic" then
		profile().Discovered[item.Id] = true
	end
end
check(math.abs(Formulas.indexBonus(profile()) - bonusBefore - 0.05) < 1e-6 or Formulas.completedSets(profile()) >= 1, "completing a zone set adds +5%")
S.ReplicatedStorage.Remotes.OpenPanel:FireClient(player, "Index")
M.advance(0.2)
check(gui.IndexPanel.Visible, "index window opens")
local views = 0
for _, d in gui.IndexPanel:GetDescendants() do
	if d:IsA("ViewportFrame") then
		views += 1
	end
end
check(views == 42, `index shows a 3D model for all 42 items ({views})`)

---------------------------------------------------------------- rebirth
print("== Rebirth")
profile().Cash = 1000
M.advance(1)
check(not request("Rebirth"), "rebirth needs the cash")
profile().Cash = Rebirth.cost(0)
local botsBefore = #profile().Bots
local gemsKeep = profile().Gems
M.advance(1)
ok, msg = request("Rebirth")
M.advance(0.2)
check(ok and profile().Rebirths == 1 and profile().Tokens == 1, "rebirth 1 grants a token: " .. tostring(msg))
check(profile().Cash == 0 and profile().ToolTier == 1 and profile().Levels.Backpack == 0, "cash, tools and upgrades reset")
check(profile().Zones.CarGraveyard == nil and profile().Zones.ScrapHeap, "zones reset")
check(#profile().Bots == botsBefore and profile().Gems == gemsKeep, "bots and gems kept")
check(equippedTool().Name == "Rusty Grabber", "tool reset to Rusty Grabber")
check(lastRemote("Announce").args[1]:find("Rebirth 1") ~= nil, "rebirth announced")
check(leaderstats.Rebirths.Value == 1, "leaderstats rebirths")
M.advance(1)
check(request("BuyPerk", "RemoteSell") == false, "perk needs enough tokens")
profile().Tokens = 10
M.advance(1)
check(request("BuyPerk", "RemoteSell") and profile().Perks.RemoteSell == 1, "bought Remote Sell")
M.advance(1)
check(request("BuyPerk", "AutoCollect") and profile().Perks.AutoCollect == 1, "bought Auto Grabber")
M.advance(1)
check(not request("BuyPerk", "RemoteSell"), "maxed perk rejected")
M.advance(1)
check(request("BuyPerk", "BotSlot") and Formulas.botSlots(profile(), DataService.context(player)) == 4, "extra bot slot")

-- Auto Grabber: stand by a pile with no tool out.
local autoPile
for _, p in heapPiles do
	if p:GetAttribute("Active") then
		autoPile = p
	end
end
equippedTool().Parent = player.Backpack
near(autoPile)
local beforeAuto = used()
M.advance(3)
check(used() > beforeAuto, "Auto Grabber collects without the tool")
moveTo(Vector3.new(0, 3, 70))
M.advance(0.5)
ok = request("Sell")
check(ok and used() == 0, "Remote Sell works from the hub")
check(gui.RemoteSell ~= nil, "remote sell button exists")

---------------------------------------------------------------- settings & UI windows
print("== Settings & windows")
M.advance(1)
check(request("SetSetting", "HideBots", true) and profile().Settings.HideBots == true, "setting saved")
for _, name in { "Teleport", "Codes", "Settings", "Rebirth", "Boosts" } do
	S.ReplicatedStorage.Remotes.OpenPanel:FireClient(player, name)
	M.advance(0.2)
	check(gui[name .. "Panel"].Visible, name .. " window opens")
end
M.context = "client"
gui.CodesPanel.Content.CodeBox.Text = "junkyard"
gemsBefore = profile().Gems
gui.CodesPanel.Content.Redeem.Activated:Fire()
M.advance(0.5)
M.context = "server"
check(profile().Gems == gemsBefore + 50, "code redeemed through the UI")

---------------------------------------------------------------- monetization
print("== Monetization")
local Monetization = require(server.Services.MonetizationService)
Config.Products[1].Id = 777
gemsBefore = profile().Gems
local decision = Monetization.processReceipt({ PlayerId = 101, PurchaseId = "abc", ProductId = 777 })
check(decision == Enum.ProductPurchaseDecision.PurchaseGranted and profile().Gems == gemsBefore + 100, "dev product grants gems")
Monetization.processReceipt({ PlayerId = 101, PurchaseId = "abc", ProductId = 777 })
check(profile().Gems == gemsBefore + 100, "duplicate receipt not granted twice")
Config.Products[1].Id = 0

---------------------------------------------------------------- leaderboard
print("== Leaderboard")
require(server.Services.LeaderboardService).refresh()
local boardList = tagged("Leaderboard"):FindFirstChild("List", true)
check(boardList.Text:find("Tester") ~= nil, "leaderboard falls back to server players")

---------------------------------------------------------------- respawn & persistence
print("== Respawn & persistence")
player.Character.Humanoid.Died:Fire()
M.advance(6)
check(equippedTool() ~= nil, "tool restored after respawn")
profile().Cash = 777
M.removePlayer(player)
M.advance(1)
local saved = M.datastore["player_101"]
check(saved and saved.Cash == 777 and saved.Rebirths == 1 and #saved.Bots > 0, "profile saved on leave")
saved.Cash = -50
saved.Levels.Backpack = 999
saved.Levels.Hack = 5
saved.Inventory.BentNail = 1e9
saved.Bots[1].Id = "FakeBot"
saved.Perks.RemoteSell = 50
local player2 = M.addPlayer("Tester", 101)
M.advance(0.5)
local p2 = DataService.get(player2)
check(p2.Cash == 0 and p2.Levels.Backpack == 40 and p2.Levels.Hack == nil, "corrupt values sanitized")
check(DataService.getUsedSlots(p2) <= Formulas.capacityFor(40, true), "inventory clamped")
check(#p2.Bots == #saved.Bots - 1 and p2.Perks.RemoteSell == 1, "fake bots dropped, perk clamped")

M.datastore["player_303"] = { Cash = 1234, Levels = { Capacity = 3, Speed = 2, BetterTools = 2 }, Inventory = { CommonMetal = 4 } }
local legacy = M.addPlayer("Legacy", 303)
M.advance(0.5)
local p3 = DataService.get(legacy)
check(p3.Cash == 1234 and p3.Levels.Backpack == 3 and p3.ToolTier == 3, "v1 saves migrate")

M.datastoreFails = true
M.datastore["player_202"] = { Cash = 5000 }
local unlucky = M.addPlayer("Unlucky", 202)
M.advance(10)
check(DataService.get(unlucky) and DataService.get(unlucky).Cash == 0, "fresh profile when load fails")
M.datastoreFails = false
DataService.get(unlucky).Cash = 1
M.removePlayer(unlucky)
M.advance(1)
check(M.datastore["player_202"].Cash == 5000, "never overwrites a save that failed to load")

print("")
print(`errors captured: {#M.errors}`)
for _, e in M.errors do
	print(e)
end
print(`RESULT: {passed} passed, {failed} failed`)
if failed > 0 or #M.errors > 0 then
	error("playtest failed", 0)
end
