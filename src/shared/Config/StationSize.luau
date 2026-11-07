--!strict
-- The station's size, and every distance that follows from it (decision 068). Two numbers are
-- set by hand: the central platform's radius and an island's; the rest is a chain. Each dome
-- from its platform; the islands (one per player's bay) on a ring around the central dome, their
-- domes a gap apart; the border around the whole ring; and the map (ZoneConfig, WorldConfig)
-- from the border. Change a platform, and the domes, the islands, the line where guardians stop,
-- the solar storm's edge, the spawn and the zones all move together. Plain numbers, so the
-- balance calculator and tests load it in Lune; StationConfig builds the shapes from it.

local ServerConfig = require("./ServerConfig")

-- The central platform's radius, studs: the spawn of new players, the jetpack kiosk, the coin
-- board.
local PLATFORM_RADIUS = 60
-- A dome over its platform, this many times the platform.
local DOME_SHARE = 1.5
local DOME_RADIUS = PLATFORM_RADIUS * DOME_SHARE
-- An island's platform: a player's bay, with room for aliens eight players tall.
local ISLAND_RADIUS = 55
local ISLAND_DOME_RADIUS = ISLAND_RADIUS * DOME_SHARE
-- One island per player, around the center.
local ISLAND_COUNT = ServerConfig.MAX_PLAYERS
-- Air between two neighbouring island domes, studs.
local ISLAND_GAP = 20
-- The ring the island centers stand on: neighbours' domes ISLAND_GAP apart.
local ISLAND_RING_RADIUS = (2 * ISLAND_DOME_RADIUS + ISLAND_GAP) / (2 * math.sin(math.pi / ISLAND_COUNT))
-- Room between the islands' outer domes and the border, studs.
local BORDER_MARGIN = 40
-- The station border, from the central dome's center: around the whole ring of islands.
-- Guardians never cross it, a chase ends once the thief is inside, and the solar storm keeps
-- everyone within it.
local BORDER_RADIUS = ISLAND_RING_RADIUS + ISLAND_DOME_RADIUS + BORDER_MARGIN

return table.freeze({
	PLATFORM_RADIUS = PLATFORM_RADIUS,
	DOME_RADIUS = DOME_RADIUS,
	ISLAND_RADIUS = ISLAND_RADIUS,
	ISLAND_DOME_RADIUS = ISLAND_DOME_RADIUS,
	ISLAND_COUNT = ISLAND_COUNT,
	ISLAND_RING_RADIUS = ISLAND_RING_RADIUS,
	BORDER_RADIUS = BORDER_RADIUS,
	-- The central spawn: halfway from the platform center to its edge.
	SPAWN_DISTANCE = PLATFORM_RADIUS * 0.5,
	-- Bays are the islands: on the island ring, facing the center.
	BAY_RING_RADIUS = ISLAND_RING_RADIUS,
	-- A player's spawn on their island: this far from its center, toward the station center.
	ISLAND_SPAWN_DISTANCE = ISLAND_RADIUS * 0.75,
})
