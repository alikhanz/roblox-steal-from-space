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

-- What the rules need to know about a player.
export type Side = {
	read speed: BigNum.BigNum,
	read playSeconds: number,
	read isInStation: boolean,
	-- Server clock of the character's spawn.
	read spawnedAt: number,
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
