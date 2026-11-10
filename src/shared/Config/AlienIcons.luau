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

-- Uploaded sheets (assets/aliens/icons/icons-<main kind>.png) by guardian post. A guardian with
-- no sheet yet shows the ball the windows had before.
local SHEETS: { [number]: string } = {}

-- The icon of `alienId`; nil for an unknown alien or a guardian with no sheet yet.
local function iconOf(alienId: string): Icon?
	local alien = AlienConfig.ALIENS[alienId]
	local sheet = alien and SHEETS[alien.grade]
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
