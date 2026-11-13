--!strict
-- What a gem egg wears (decision 122): the egg kit's pieces (World/EggKit) an egg puts on for its
-- rarity and its kind, and how each is painted. Every egg wears the shell and the girdle; its
-- rarity adds a tip (uncommon and up), fins (rare and up), an orbit (epic and up) and a gold
-- crown (legendary); a meteor egg adds lava cracks and a flame, the star egg a gold star on top
-- and star specks. A special egg wears no tip: its flame or star stands there. The shapes:
-- assets/blender/lowpoly/lowpoly_eggs.py (its export lists the same, for the budget). The colours
-- of each paint: Config/EggLooks.GEM. Pure Luau.

local EggConfig = require("../Config/EggConfig")
local EggKind = require("./EggKind")

-- How a piece is painted:
--   Shell    - the egg's body: its rarity's colour, scorched on a meteor egg, night on the star egg;
--   Line     - the rarity's light (Neon; plain pale plastic on a common egg);
--   Fins     - the rarity's colour darkened (plastic);
--   Gold     - polished gold;
--   Lava     - the meteor's glowing lava;
--   Flame    - the meteor's flame;
--   StarGold - the star egg's gold light.
export type Paint = "Shell" | "Line" | "Fins" | "Gold" | "Lava" | "Flame" | "StarGold"

export type Piece = {
	read id: string,
	read paint: Paint,
}

local EggPieces = {}

-- The pieces an egg of `rarity` and `kind` wears, the shell first.
function EggPieces.of(rarity: EggConfig.RarityId, kind: EggKind.Kind): { Piece }
	local tier = assert(table.find(EggConfig.RARITY_ORDER, rarity), `unknown rarity {rarity}`)
	local girdle: Paint = if kind == "Meteor" then "Lava" elseif kind == "Star" then "StarGold" else "Line"
	local pieces: { Piece } = {}
	local function add(id: string, paint: Paint)
		local piece: Piece = { id = id, paint = paint }
		table.insert(pieces, piece)
	end
	add("GemShell", "Shell")
	add("GemGirdle", girdle)
	if tier >= 2 and kind == "Normal" then
		add("GemTip", "Line")
	end
	if tier >= 3 then
		add("GemFins", "Fins")
	end
	if tier >= 4 then
		add("GemOrbit", "Line")
	end
	if tier >= 5 then
		add("GemCrown", "Gold")
	end
	if kind == "Meteor" then
		add("MeteorCracks", "Lava")
		add("MeteorFlame", "Flame")
	elseif kind == "Star" then
		add("StarTop", "StarGold")
		add("StarDots", "StarGold")
	end
	return pieces
end

return table.freeze(EggPieces)
