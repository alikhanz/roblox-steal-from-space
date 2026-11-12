--!strict
-- Which marker a player or a loose egg gets on the screen, and whether at all
-- (docs/design/screens/markers.md). Pure Luau.

local EggConfig = require("../Config/EggConfig")
local RadarConfig = require("../Config/RadarConfig")

local Radar = {}

export type Kind = "Player" | "Thief" | "HotThief"

-- A loose egg as the client sees it.
export type Loose = {
	read id: string,
	read rarity: string,
	read distance: number,
	-- Knocked out of this player's own hands.
	read isOwn: boolean,
}

-- 1 for common up to 5 for legendary; 0 for anything else.
local function rank(rarity: string?): number
	return if rarity then table.find(EggConfig.RARITY_ORDER, rarity :: EggConfig.RarityId) or 0 else 0
end

local HOT_RANK = rank(RadarConfig.HOT_FROM)

function Radar.isHot(rarity: string?): boolean
	return rank(rarity) >= HOT_RANK
end

-- A player carrying `rarity` (nil: empty hands).
function Radar.kindOf(rarity: string?): Kind
	if rank(rarity) == 0 then
		return "Player"
	end
	return if Radar.isHot(rarity) then "HotThief" else "Thief"
end

-- Whether a player's marker shows at `distance` studs (nearer, they are right there), whatever
-- they carry.
function Radar.isFarEnough(distance: number): boolean
	return distance >= RadarConfig.PLAYER_MIN_DISTANCE
end

-- The marker's transparency: plain players fade with distance, thieves never do.
function Radar.fade(kind: Kind, distance: number): number
	if kind ~= "Player" then
		return 0
	end
	local share = (distance - RadarConfig.FADE_NEAR) / (RadarConfig.FADE_FAR - RadarConfig.FADE_NEAR)
	return math.clamp(share, 0, 1) * RadarConfig.FADE_MAX
end

-- Whether the server should publish a position again: none yet, or moved far enough.
function Radar.shouldPublish(last: Vector3?, now: Vector3): boolean
	return last == nil or (now - last).Magnitude >= RadarConfig.PUBLISH_STEP
end

-- The toast's string key when a player's egg in hand turns from `before` to `after`: only on
-- picking up an egg rare enough to announce.
function Radar.announcement(before: string?, after: string?): string?
	if after == nil or after == before then
		return nil
	end
	return (RadarConfig.ANNOUNCED :: { [string]: string })[after]
end

-- The loose eggs that get a marker, most wanted first: your own drop, then the rarest, then the
-- nearest; not those within the grab button's range; at most LOOSE_CAP.
function Radar.pickLoose(eggs: { Loose }): { Loose }
	local shown: { Loose } = {}
	for _, egg in eggs do
		if egg.distance >= RadarConfig.LOOSE_MIN_DISTANCE then
			table.insert(shown, egg)
		end
	end
	table.sort(shown, function(a: Loose, b: Loose): boolean
		if a.isOwn ~= b.isOwn then
			return a.isOwn
		end
		local rankA, rankB = rank(a.rarity), rank(b.rarity)
		if rankA ~= rankB then
			return rankA > rankB
		end
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end
		return a.id < b.id
	end)
	for index = #shown, RadarConfig.LOOSE_CAP + 1, -1 do
		shown[index] = nil
	end
	return shown
end

-- Whether a loose egg's marker waits at the screen edge when the egg is out of view.
function Radar.isLooseOnEdge(egg: Loose): boolean
	return egg.isOwn or Radar.isHot(egg.rarity) or egg.distance <= RadarConfig.LOOSE_EDGE_RANGE
end

-- The share of its time a loose egg has left before it flies home, 0 to 1.
function Radar.timeLeft(droppedAt: number, now: number): number
	return math.clamp(1 - (now - droppedAt) / EggConfig.LOOSE_SECONDS, 0, 1)
end

return table.freeze(Radar)
