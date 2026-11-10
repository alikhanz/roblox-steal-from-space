--!strict
-- The aliens' icons in the windows (docs/design/screens/alien-icons.md): a picture of each kind at
-- each tier, rendered by assets/blender/aliens/icons.py from the same models the game shows. One
-- sheet per guardian: a row per kind (in the guardian's order, AlienConfig Kind.position), a column
-- per tier, CELL pixels square; a window cuts its cell out (ImageRectOffset). Meteor ones share
-- the usual icon (the index's section and the bay's badge tell them apart).

local AlienConfig = require("./AlienConfig")

-- Where an alien's icon is: its sheet and the cell's top-left corner and size, pixels.
export type Icon = {
	read image: string,
	read x: number,
	read y: number,
	read size: number,
}

local CELL = 128

-- Uploaded sheets (assets/aliens/icons/icons-<main kind>.png, 2026-11-10) by the guardian's main
-- kind: a sheet's rows are that guardian's kinds. A guardian with no sheet yet shows the ball the
-- windows had before; a new or reordered kind needs its guardian's sheet rendered again.
local SHEETS: { [string]: string } = {
	slimeWarden = "rbxassetid://72347321314978",
	crabDrone = "rbxassetid://73392366438488",
	violetCrab = "rbxassetid://97899170125672",
	acidSlime = "rbxassetid://83441101496509",
	rustyCrab = "rbxassetid://110540084285141",
	slimeKing = "rbxassetid://81839832060541",
	iceWorm = "rbxassetid://96404494282204",
	snowCrab = "rbxassetid://96448632226633",
	frostSlime = "rbxassetid://110486855102651",
	crystalWorm = "rbxassetid://109226248361856",
	iceRay = "rbxassetid://118742559041451",
	wormMother = "rbxassetid://125445202122156",
	devourerSwarm = "rbxassetid://138874372725205",
	starRay = "rbxassetid://108421195279313",
	fireSlime = "rbxassetid://108797622311117",
	redSwarm = "rbxassetid://80422216906045",
	lightningRay = "rbxassetid://78995717925143",
	devourerQueen = "rbxassetid://84792892103859",
	shadowWorm = "rbxassetid://72567383334883",
	blackRay = "rbxassetid://92897548936933",
	voidSwarm = "rbxassetid://87658420801974",
	gravityCrab = "rbxassetid://85705020204475",
	whaleCalf = "rbxassetid://131288254401808",
	spaceWhale = "rbxassetid://99085017373858",
}

-- The icon of `alienId`; nil for an unknown alien or a guardian with no sheet yet.
local function iconOf(alienId: string): Icon?
	local alien = AlienConfig.ALIENS[alienId]
	local grade = alien and AlienConfig.GRADES[alien.grade]
	local sheet = grade and SHEETS[grade.kinds[1]]
	if not alien or not sheet then
		return nil
	end
	local kind = AlienConfig.KINDS[alien.kind]
	return {
		image = sheet,
		x = (AlienConfig.TIER_POSITIONS[alien.tier] - 1) * CELL,
		y = (kind.position - 1) * CELL,
		size = CELL,
	}
end

return table.freeze({
	CELL = CELL,
	SHEETS = table.freeze(SHEETS),
	iconOf = iconOf,
})
