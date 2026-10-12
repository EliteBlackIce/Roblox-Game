--!strict
-- Scrap Bots: crate hatching, equipping, golden merges and deleting.
-- Equipped bots are mirrored to a "Bots" player attribute so every client can
-- render followers without trusting anything client-side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Bots = require(Shared.Bots)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local RequestRouter = require(script.Parent.RequestRouter)
local Stations = require(script.Parent.Stations)

local BotService = {}

local rng = Random.new()

local function findOwned(profile: DataService.Profile, uid: unknown): (DataService.OwnedBot?, number?)
	if type(uid) ~= "string" then
		return nil, nil
	end
	for index, owned in profile.Bots do
		if owned.Uid == uid then
			return owned, index
		end
	end
	return nil, nil
end

local function power(owned: DataService.OwnedBot): number
	local bot = Bots.ById[owned.Id]
	local mult = if owned.Golden then Bots.GoldenMultiplier else 1
	return (bot.Cash + bot.Luck * 1.5) * mult
end

-- Drops equipped uids that no longer exist or exceed the slot count.
local function tidyEquipped(player: Player, profile: DataService.Profile)
	local slots = Formulas.botSlots(profile, DataService.context(player))
	local kept = {}
	for _, uid in profile.Equipped do
		if #kept < slots and findOwned(profile, uid) and not table.find(kept, uid) then
			table.insert(kept, uid)
		end
	end
	profile.Equipped = kept
end

function BotService.syncAttribute(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local parts = {}
	for _, uid in profile.Equipped do
		local owned = findOwned(profile, uid)
		if owned then
			table.insert(parts, owned.Id .. (if owned.Golden then ":g" else ""))
		end
	end
	player:SetAttribute("Bots", table.concat(parts, ","))
end

local function grant(profile: DataService.Profile, botId: string, golden: boolean): DataService.OwnedBot
	local owned = { Uid = tostring(profile.NextUid), Id = botId, Golden = golden }
	profile.NextUid += 1
	table.insert(profile.Bots, owned)
	return owned
end

function BotService.hatch(player: Player, crateId: unknown, count: unknown): (boolean, string?, any?)
	if type(crateId) ~= "string" then
		return false, "Invalid crate."
	end
	local crate = Bots.CrateById[crateId]
	if not crate then
		return false, "Invalid crate."
	end
	local amount = if count == 3 then 3 else 1
	if not Stations.near(player, "CrateStand", nil, "CrateId", crate.Id) then
		return false, `Walk up to the {crate.Name} to open it.`
	end
	local profile = DataService.get(player) :: DataService.Profile
	if #profile.Bots + amount > Bots.MaxInventory then
		return false, `Your bot storage is full ({Bots.MaxInventory}). Delete or merge some bots.`
	end
	local cost = crate.Price * amount
	local balance = if crate.Currency == "Gems" then profile.Gems else profile.Cash
	if balance < cost then
		local missing = cost - balance
		local text = if crate.Currency == "Gems" then `{missing} gems` else Formulas.formatCash(missing)
		return false, `You need {text} more.`
	end
	if crate.Currency == "Gems" then
		profile.Gems -= cost
	else
		profile.Cash -= cost
	end

	local results = {}
	for _ = 1, amount do
		local bot = Formulas.rollBot(rng, crate)
		local owned = grant(profile, bot.Id, false)
		table.insert(results, { Uid = owned.Uid, Id = bot.Id })
		if bot.Rarity == "Legendary" or bot.Rarity == "Mythic" then
			Remotes.event("Announce"):FireAllClients(`{player.DisplayName} hatched a {bot.Rarity} {bot.Name}!`, bot.Rarity)
		end
	end
	DataService.addStat(profile, "Hatched", amount)

	-- New players get their first bot equipped automatically.
	if #profile.Equipped < Formulas.botSlots(profile, DataService.context(player)) then
		table.insert(profile.Equipped, results[1].Uid)
	end
	BotService.syncAttribute(player)
	Remotes.event("Hatched"):FireClient(player, crate.Id, results)
	DataService.changed(player)
	return true, nil, results
end

local function equip(player: Player, uid: unknown): (boolean, string?)
	local profile = DataService.get(player) :: DataService.Profile
	local owned = findOwned(profile, uid)
	if not owned then
		return false, "You don't own that bot."
	end
	if table.find(profile.Equipped, owned.Uid) then
		return false, "Already equipped."
	end
	if #profile.Equipped >= Formulas.botSlots(profile, DataService.context(player)) then
		return false, "All bot slots are full. Unequip one first."
	end
	table.insert(profile.Equipped, owned.Uid)
	BotService.syncAttribute(player)
	DataService.changed(player)
	return true, nil
end

local function unequip(player: Player, uid: unknown): (boolean, string?)
	local profile = DataService.get(player) :: DataService.Profile
	local index = if type(uid) == "string" then table.find(profile.Equipped, uid) else nil
	if not index then
		return false, "That bot isn't equipped."
	end
	table.remove(profile.Equipped, index)
	BotService.syncAttribute(player)
	DataService.changed(player)
	return true, nil
end

local function equipBest(player: Player): (boolean, string?)
	local profile = DataService.get(player) :: DataService.Profile
	local sorted = table.clone(profile.Bots)
	table.sort(sorted, function(a, b)
		return power(a) > power(b)
	end)
	local slots = Formulas.botSlots(profile, DataService.context(player))
	profile.Equipped = {}
	for i = 1, math.min(slots, #sorted) do
		table.insert(profile.Equipped, sorted[i].Uid)
	end
	BotService.syncAttribute(player)
	DataService.changed(player)
	return true, "Equipped your best bots!"
end

local function delete(player: Player, uid: unknown): (boolean, string?)
	local profile = DataService.get(player) :: DataService.Profile
	local owned, index = findOwned(profile, uid)
	if not owned or not index then
		return false, "You don't own that bot."
	end
	table.remove(profile.Bots, index)
	tidyEquipped(player, profile)
	BotService.syncAttribute(player)
	DataService.changed(player)
	return true, `Deleted {Bots.ById[owned.Id].Name}.`
end

-- Merges `MergeCount` regular copies of a bot into one Golden copy.
local function makeGolden(player: Player, botId: unknown): (boolean, string?)
	if type(botId) ~= "string" or not Bots.ById[botId] then
		return false, "Invalid bot."
	end
	local profile = DataService.get(player) :: DataService.Profile
	local copies = {}
	for _, owned in profile.Bots do
		if owned.Id == botId and not owned.Golden then
			table.insert(copies, owned.Uid)
		end
	end
	if #copies < Bots.MergeCount then
		return false, `You need {Bots.MergeCount} regular copies (you have {#copies}).`
	end
	local remove = {}
	for i = 1, Bots.MergeCount do
		remove[copies[i]] = true
	end
	local wasEquipped = false
	local kept = {}
	for _, owned in profile.Bots do
		if not remove[owned.Uid] then
			table.insert(kept, owned)
		end
	end
	for _, uid in profile.Equipped do
		if remove[uid] then
			wasEquipped = true
		end
	end
	profile.Bots = kept
	local golden = grant(profile, botId, true)
	tidyEquipped(player, profile)
	if wasEquipped then
		table.insert(profile.Equipped, golden.Uid)
		tidyEquipped(player, profile)
	end
	BotService.syncAttribute(player)
	DataService.changed(player)
	return true, `Created a GOLDEN {Bots.ById[botId].Name}!`
end

local function onCratePrompt(player: Player, stand: Instance)
	local ok, message = BotService.hatch(player, stand:GetAttribute("CrateId"), 1)
	if not ok and message then
		DataService.notify(player, message, "error")
	end
end

function BotService.start()
	RequestRouter.register("Hatch", BotService.hatch)
	RequestRouter.register("EquipBot", equip)
	RequestRouter.register("UnequipBot", unequip)
	RequestRouter.register("EquipBest", equipBest)
	RequestRouter.register("DeleteBot", delete)
	RequestRouter.register("GoldenBot", makeGolden)
	Stations.connectPrompt("CrateStand", "OpenPrompt", onCratePrompt)

	DataService.onLoaded(function(player, profile)
		tidyEquipped(player, profile)
		BotService.syncAttribute(player)
	end)
end

BotService.tidyEquipped = tidyEquipped

return BotService
