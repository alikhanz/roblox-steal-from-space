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
	-- Server clock until which a shield holds; 0 for none.
	read shieldUntil: number,
}

export type Refusal =
	"AttackerInStation"
	| "VictimInStation"
	| "AttackerNewbie"
	| "VictimNewbie"
	| "VictimJustSpawned"
	| "VictimShielded"
	| "VictimTooWeak"

function Pvp.isNewbie(playSeconds: number, rules: Rules): boolean
	return playSeconds < rules.newbieSeconds
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
	if now < victim.shieldUntil then
		return "VictimShielded"
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
