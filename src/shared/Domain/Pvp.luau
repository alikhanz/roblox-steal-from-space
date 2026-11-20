--!strict
-- Who may attack whom. Every rule that keeps PvP fair lives here, in one function the server
-- asks before any ability lands. Pure Luau.

local BigNum = require("./BigNum")

local Pvp = {}

export type Rules = {
	read newbieSeconds: number,
	read spawnGraceSeconds: number,
	read maxSpeedRatio: number,
}

-- The players who lost an egg since it left its home, by user id (decision 148).
export type LostBy = { read [number]: true }

-- What the rules need to know about a player.
export type Side = {
	read userId: number,
	read speed: BigNum.BigNum,
	read playSeconds: number,
	read isInStation: boolean,
	-- Server clock of the character's spawn.
	read spawnedAt: number,
	-- Who lost the egg this player carries; nil when they carry none or nobody lost it yet.
	read eggLostBy: LostBy?,
}

export type Refusal =
	"AttackerInStation"
	| "VictimInStation"
	| "AttackerNewbie"
	| "VictimNewbie"
	| "VictimJustSpawned"
	| "VictimTooWeak"

function Pvp.isNewbie(playSeconds: number, rules: Rules): boolean
	return playSeconds < rules.newbieSeconds
end

-- The egg's losers with `userId` added: it just came loose from them. A new set; the old one
-- is left as it was.
function Pvp.addLoser(lostBy: LostBy?, userId: number): LostBy
	local next: { [number]: true } = {}
	for id in lostBy or {} do
		next[id] = true
	end
	next[userId] = true
	return table.freeze(next)
end

-- Whether `userId` is among the egg's losers.
function Pvp.lostIt(lostBy: LostBy?, userId: number): boolean
	return lostBy ~= nil and lostBy[userId] == true
end

-- Why `attacker` may not attack a creature (the star serpent, a test dummy) right now, or nil
-- when they may. The rules between players (newbies, a fresh spawn, a stat far apart) are about
-- fairness to the other player and do not apply; only the station stays a safe zone.
function Pvp.creatureRefusal(attacker: Side): Refusal?
	return if attacker.isInStation then "AttackerInStation" else nil
end

-- Why `attacker` may not attack `victim` right now, or nil when they may.
function Pvp.refusal(attacker: Side, victim: Side, now: number, rules: Rules): Refusal?
	if attacker.isInStation then
		return "AttackerInStation"
	end
	if victim.isInStation then
		return "VictimInStation"
	end
	if Pvp.isNewbie(attacker.playSeconds, rules) then
		return "AttackerNewbie"
	end
	if Pvp.isNewbie(victim.playSeconds, rules) then
		return "VictimNewbie"
	end
	if now - victim.spawnedAt < rules.spawnGraceSeconds then
		return "VictimJustSpawned"
	end
	-- Your own egg you may always win back (decision 148): the gap does not shield whoever
	-- carries an egg you lost, however it was lost.
	if Pvp.lostIt(victim.eggLostBy, attacker.userId) then
		return nil
	end
	-- The ratio is taken on the log scale: stats reach hundreds of billions.
	if not BigNum.isZero(victim.speed) and not BigNum.isNegative(victim.speed) then
		local ratio = 10 ^ (BigNum.log10(attacker.speed) - BigNum.log10(victim.speed))
		if ratio >= rules.maxSpeedRatio then
			return "VictimTooWeak"
		end
	end
	return nil
end

return table.freeze(Pvp)
