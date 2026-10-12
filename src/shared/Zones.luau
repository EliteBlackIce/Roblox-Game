--!strict
-- The six yards and the scrap each one drops. Every zone has one item per
-- rarity; the Mythic only ever comes out of a Golden Pile.

local Zones = {}

export type Item = {
	Id: string,
	Name: string,
	Rarity: string,
	Value: number,
	Weight: number, -- relative drop weight (Mythic weight is unused)
	Color: Color3,
	Zone: string?, -- filled in below
}

export type Zone = {
	Id: string,
	Name: string,
	Order: number,
	Price: number, -- cash to unlock (0 = always open)
	RebirthsRequired: number,
	Theme: { Ground: Color3, Accent: Color3, Pile: { Color3 } },
	Items: { Item },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local list: { Zone } = {
	{
		Id = "ScrapHeap",
		Name = "Scrap Heap",
		Order = 1,
		Price = 0,
		RebirthsRequired = 0,
		Theme = {
			Ground = rgb(196, 152, 104),
			Accent = rgb(230, 120, 60),
			Pile = { rgb(200, 110, 60), rgb(160, 90, 55), rgb(170, 170, 180), rgb(230, 170, 70) },
		},
		Items = {
			{ Id = "BentNail", Name = "Bent Nail", Rarity = "Common", Value = 2, Weight = 60, Color = rgb(170, 170, 180) },
			{ Id = "TinCan", Name = "Tin Can", Rarity = "Common", Value = 4, Weight = 45, Color = rgb(200, 205, 210) },
			{ Id = "CopperWire", Name = "Copper Wire", Rarity = "Uncommon", Value = 10, Weight = 22, Color = rgb(230, 130, 60) },
			{ Id = "OldBattery", Name = "Old Battery", Rarity = "Rare", Value = 35, Weight = 8, Color = rgb(80, 200, 120) },
			{ Id = "GoldenSpring", Name = "Golden Spring", Rarity = "Epic", Value = 150, Weight = 1.5, Color = rgb(250, 210, 70) },
			{ Id = "AncientGear", Name = "Ancient Gear", Rarity = "Legendary", Value = 1000, Weight = 0.15, Color = rgb(255, 175, 40) },
			{ Id = "GoldenRobotHead", Name = "Golden Robot Head", Rarity = "Mythic", Value = 12000, Weight = 0, Color = rgb(255, 215, 60) },
		},
	},
	{
		Id = "CarGraveyard",
		Name = "Car Graveyard",
		Order = 2,
		Price = 750,
		RebirthsRequired = 0,
		Theme = {
			Ground = rgb(150, 150, 140),
			Accent = rgb(220, 70, 60),
			Pile = { rgb(220, 70, 60), rgb(60, 120, 220), rgb(240, 200, 60), rgb(90, 90, 100) },
		},
		Items = {
			{ Id = "Hubcap", Name = "Hubcap", Rarity = "Common", Value = 12, Weight = 60, Color = rgb(200, 200, 210) },
			{ Id = "SparkPlug", Name = "Spark Plug", Rarity = "Common", Value = 18, Weight = 40, Color = rgb(240, 240, 240) },
			{ Id = "CarBattery", Name = "Car Battery", Rarity = "Uncommon", Value = 45, Weight = 22, Color = rgb(60, 60, 70) },
			{ Id = "ChromeBumper", Name = "Chrome Bumper", Rarity = "Rare", Value = 120, Weight = 8, Color = rgb(210, 220, 235) },
			{ Id = "V8Engine", Name = "V8 Engine", Rarity = "Epic", Value = 600, Weight = 1.5, Color = rgb(200, 50, 50) },
			{ Id = "HoodOrnament", Name = "Vintage Hood Ornament", Rarity = "Legendary", Value = 4000, Weight = 0.15, Color = rgb(255, 200, 80) },
			{ Id = "DiamondWheel", Name = "Diamond Steering Wheel", Rarity = "Mythic", Value = 80000, Weight = 0, Color = rgb(150, 240, 255) },
		},
	},
	{
		Id = "ApplianceAlley",
		Name = "Appliance Alley",
		Order = 3,
		Price = 6000,
		RebirthsRequired = 0,
		Theme = {
			Ground = rgb(170, 200, 190),
			Accent = rgb(120, 200, 230),
			Pile = { rgb(245, 245, 245), rgb(255, 170, 190), rgb(140, 220, 210), rgb(250, 220, 120) },
		},
		Items = {
			{ Id = "Toaster", Name = "Toaster", Rarity = "Common", Value = 50, Weight = 60, Color = rgb(220, 220, 225) },
			{ Id = "MicrowaveDoor", Name = "Microwave Door", Rarity = "Common", Value = 70, Weight = 40, Color = rgb(60, 60, 70) },
			{ Id = "FridgeCoil", Name = "Fridge Coil", Rarity = "Uncommon", Value = 180, Weight = 22, Color = rgb(120, 200, 230) },
			{ Id = "WasherDrum", Name = "Washer Drum", Rarity = "Rare", Value = 450, Weight = 8, Color = rgb(190, 200, 210) },
			{ Id = "RetroTV", Name = "Retro TV", Rarity = "Epic", Value = 2200, Weight = 1.5, Color = rgb(255, 140, 170) },
			{ Id = "GoldenToaster", Name = "Golden Toaster", Rarity = "Legendary", Value = 15000, Weight = 0.15, Color = rgb(255, 200, 50) },
			{ Id = "PlatinumBlender", Name = "Platinum Blender", Rarity = "Mythic", Value = 300000, Weight = 0, Color = rgb(230, 240, 255) },
		},
	},
	{
		Id = "ElectronicsDump",
		Name = "Electronics Dump",
		Order = 4,
		Price = 40000,
		RebirthsRequired = 0,
		Theme = {
			Ground = rgb(60, 120, 80),
			Accent = rgb(70, 255, 150),
			Pile = { rgb(40, 140, 70), rgb(30, 30, 40), rgb(70, 200, 255), rgb(230, 230, 230) },
		},
		Items = {
			{ Id = "Keyboard", Name = "Old Keyboard", Rarity = "Common", Value = 200, Weight = 60, Color = rgb(230, 230, 225) },
			{ Id = "CircuitBoard", Name = "Circuit Board", Rarity = "Common", Value = 300, Weight = 40, Color = rgb(40, 160, 80) },
			{ Id = "HardDrive", Name = "Hard Drive", Rarity = "Uncommon", Value = 750, Weight = 22, Color = rgb(150, 150, 160) },
			{ Id = "GraphicsCard", Name = "Graphics Card", Rarity = "Rare", Value = 2000, Weight = 8, Color = rgb(50, 50, 60) },
			{ Id = "ServerRack", Name = "Server Rack", Rarity = "Epic", Value = 9000, Weight = 1.5, Color = rgb(70, 200, 255) },
			{ Id = "QuantumChip", Name = "Quantum Chip", Rarity = "Legendary", Value = 60000, Weight = 0.15, Color = rgb(160, 90, 255) },
			{ Id = "AICore", Name = "Sentient AI Core", Rarity = "Mythic", Value = 1200000, Weight = 0, Color = rgb(255, 80, 80) },
		},
	},
	{
		Id = "Shipyard",
		Name = "Shipyard Wrecks",
		Order = 5,
		Price = 250000,
		RebirthsRequired = 1,
		Theme = {
			Ground = rgb(235, 215, 160),
			Accent = rgb(60, 150, 230),
			Pile = { rgb(60, 110, 170), rgb(200, 80, 60), rgb(240, 240, 240), rgb(120, 90, 70) },
		},
		Items = {
			{ Id = "RustyChain", Name = "Rusty Chain", Rarity = "Common", Value = 900, Weight = 60, Color = rgb(170, 100, 60) },
			{ Id = "Porthole", Name = "Porthole", Rarity = "Common", Value = 1300, Weight = 40, Color = rgb(200, 170, 90) },
			{ Id = "Propeller", Name = "Ship Propeller", Rarity = "Uncommon", Value = 3500, Weight = 22, Color = rgb(220, 180, 80) },
			{ Id = "Anchor", Name = "Anchor", Rarity = "Rare", Value = 9000, Weight = 8, Color = rgb(60, 60, 70) },
			{ Id = "CaptainsWheel", Name = "Captain's Wheel", Rarity = "Epic", Value = 40000, Weight = 1.5, Color = rgb(150, 100, 60) },
			{ Id = "SunkenTreasure", Name = "Sunken Treasure", Rarity = "Legendary", Value = 250000, Weight = 0.15, Color = rgb(255, 210, 60) },
			{ Id = "KrakenTooth", Name = "Kraken Tooth", Rarity = "Mythic", Value = 5000000, Weight = 0, Color = rgb(120, 255, 220) },
		},
	},
	{
		Id = "CrashSite",
		Name = "Crash Site",
		Order = 6,
		Price = 1500000,
		RebirthsRequired = 2,
		Theme = {
			Ground = rgb(80, 60, 110),
			Accent = rgb(190, 90, 255),
			Pile = { rgb(140, 80, 220), rgb(60, 220, 200), rgb(200, 200, 220), rgb(255, 120, 200) },
		},
		Items = {
			{ Id = "SpaceRock", Name = "Space Rock", Rarity = "Common", Value = 4000, Weight = 60, Color = rgb(120, 100, 140) },
			{ Id = "SatelliteDish", Name = "Satellite Dish", Rarity = "Common", Value = 6000, Weight = 40, Color = rgb(230, 230, 240) },
			{ Id = "RocketFin", Name = "Rocket Fin", Rarity = "Uncommon", Value = 15000, Weight = 22, Color = rgb(230, 60, 60) },
			{ Id = "AlienAlloy", Name = "Alien Alloy", Rarity = "Rare", Value = 40000, Weight = 8, Color = rgb(60, 230, 200) },
			{ Id = "UFOCore", Name = "UFO Core", Rarity = "Epic", Value = 180000, Weight = 1.5, Color = rgb(150, 255, 120) },
			{ Id = "AlienArtifact", Name = "Alien Artifact", Rarity = "Legendary", Value = 1000000, Weight = 0.15, Color = rgb(255, 120, 230) },
			{ Id = "CosmicShard", Name = "Cosmic Shard", Rarity = "Mythic", Value = 25000000, Weight = 0, Color = rgb(255, 255, 255) },
		},
	},
}

Zones.List = list
Zones.ById = {} :: { [string]: Zone }
Zones.Items = {} :: { [string]: Item }
Zones.ItemOrder = {} :: { string } -- stable display order for UI

for _, zone in list do
	Zones.ById[zone.Id] = zone
	for _, item in zone.Items do
		item.Zone = zone.Id
		Zones.Items[item.Id] = item
		table.insert(Zones.ItemOrder, item.Id)
	end
end

function Zones.previous(zoneId: string): Zone?
	local zone = Zones.ById[zoneId]
	if not zone then
		return nil
	end
	return list[zone.Order - 1]
end

return Zones
