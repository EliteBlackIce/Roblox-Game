--!strict
-- Collection tools, bought in order at the Tool Shop.

export type Tool = {
	Name: string,
	Price: number,
	Yield: number, -- items per grab (capped by free backpack space)
	Luck: number, -- multiplies the odds of rarer scrap
	Color: Color3,
	Glow: boolean,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Tools: { Tool } = {
	{ Name = "Rusty Grabber", Price = 0, Yield = 1, Luck = 1.0, Color = rgb(170, 100, 60), Glow = false },
	{ Name = "Steel Grabber", Price = 300, Yield = 1, Luck = 1.2, Color = rgb(190, 195, 205), Glow = false },
	{ Name = "Magnet Claw", Price = 2500, Yield = 2, Luck = 1.4, Color = rgb(230, 60, 60), Glow = false },
	{ Name = "Hydraulic Claw", Price = 15000, Yield = 2, Luck = 1.7, Color = rgb(250, 200, 40), Glow = false },
	{ Name = "Laser Cutter", Price = 90000, Yield = 3, Luck = 2.0, Color = rgb(255, 80, 80), Glow = true },
	{ Name = "Plasma Extractor", Price = 500000, Yield = 3, Luck = 2.5, Color = rgb(80, 220, 255), Glow = true },
	{ Name = "Gravity Gun", Price = 3000000, Yield = 4, Luck = 3.0, Color = rgb(170, 90, 255), Glow = true },
	{ Name = "Quantum Vacuum", Price = 20000000, Yield = 5, Luck = 4.0, Color = rgb(255, 255, 255), Glow = true },
}

return Tools
