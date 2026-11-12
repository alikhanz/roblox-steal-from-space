--!strict
-- Markers of players and eggs on the screen (docs/design/screens/markers.md): who is where, who
-- carries what, where a knocked-out egg floats. Pure Luau: tests load it in Lune. Looks are in the
-- marker's UI (UI/RadarMarker) and Theme.

local EggConfig = require("./EggConfig")
-- selene: allow(unused_variable) -- only its type is used, to keep the toast keys checked.
local Strings = require("../Locale/Strings")

return table.freeze({
	-- The server publishes every player's position and egg in hand on the Player (whose
	-- attributes reach every client, however far the character is streamed) this often, seconds,
	-- and the position only once it has moved this far, studs.
	PUBLISH_SECONDS = 0.5,
	PUBLISH_STEP = 2,
	POSITION_ATTRIBUTE = "RadarAt",
	EGG_ATTRIBUTE = "RadarEgg",
	-- The kind of that egg (Domain/EggKind) when it is a special one; none for a normal egg.
	EGG_KIND_ATTRIBUTE = "RadarEggKind",

	-- A thief with an egg this rare or rarer is shown to the whole server: a bigger marker, its
	-- name at the screen edge too.
	HOT_FROM = "Rare" :: EggConfig.RarityId,
	-- Grabbing an egg this rare or rarer tells everyone else with a toast.
	ANNOUNCED = table.freeze({
		Epic = "radar.epicCarried.toast",
		Legendary = "radar.legendaryCarried.toast",
	} :: { [EggConfig.RarityId]: keyof<typeof(Strings)> }),

	-- No player marker nearer than this, studs: the player is right there, the marker would sit on
	-- the screen like a hat. Everywhere else every player is marked, under a dome too (the user,
	-- 2026-11-12: "a global marker on every player"); the marker stands in for Roblox's name over
	-- the head, which is hidden. A loose egg has none within the grab button's range.
	PLAYER_MIN_DISTANCE = 12,
	LOOSE_MIN_DISTANCE = EggConfig.GRAB_BUTTON_RANGE,
	-- Plain players fade with distance: clear up to `near`, this transparent from `far` on.
	FADE_NEAR = 300,
	FADE_FAR = 2500,
	FADE_MAX = 0.45,

	-- Loose eggs: at most this many markers (own drop first, then the rarest, then the nearest);
	-- at the screen edge only a rare one, one you dropped, or one this near, studs.
	LOOSE_CAP = 4,
	LOOSE_EDGE_RANGE = 800,

	-- The home pin hangs this high over the middle of the island's floor, studs (it hung on the
	-- dome's top, 250 studs up: user, 2026-11-12).
	HOME_PIN_HEIGHT = 15,
})
