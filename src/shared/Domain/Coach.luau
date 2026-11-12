--!strict
-- The hints after the tutorial (decision 110, docs/design/screens/aliens-and-hints.md): one at a
-- time, each shown while what it asks for makes sense and gone for good once the player has done
-- it. Which tips are done is kept as a bit mask in the profile (`coachDone`); which one shows now
-- is worked out from the player's facts, like the tutorial's hint. Pure Luau.

local Coach = {}

export type Tip = "Shelf" | "Jetpack" | "Quest" | "Crossbreed" | "Sell"

-- Highest priority first: when several are wanted, the first shows. A tip's bit in the mask is
-- its position here; never reorder a tip once live.
Coach.TIPS = table.freeze({ "Shelf", "Jetpack", "Quest", "Crossbreed", "Sell" } :: { Tip })

local BITS: { [Tip]: number } = {}
for position, tip in Coach.TIPS do
	BITS[tip] = bit32.lshift(1, position - 1)
end

-- What the coach looks at.
export type Facts = {
	-- The tutorial is over (its farewell included: that is the pace's business).
	read tutorialDone: boolean,
	-- Carrying an egg: no hint while in a chase.
	read carrying: boolean,
	read freePods: number,
	-- Pods bought on top of the starting ones.
	read boughtPods: number,
	read shelfCount: number,
	read shelfSlots: number,
	read jetpackLevel: number,
	-- The coins cover the next jetpack.
	read canAffordJetpack: boolean,
	-- A daily quest is finished and its reward not taken.
	read questToClaim: boolean,
	-- The shelf holds three aliens that crossbreed together.
	read hasTrio: boolean,
}

function Coach.isDone(mask: number, tip: Tip): boolean
	return bit32.btest(mask, BITS[tip])
end

-- The mask with `tip` done, and whether it was new.
function Coach.mark(mask: number, tip: Tip): (number, boolean)
	if Coach.isDone(mask, tip) then
		return mask, false
	end
	return bit32.bor(mask, BITS[tip]), true
end

-- The mask with the tips the player's state shows done: a pod bought, a jetpack bought. The other
-- tips are done by an action (claim, crossbreed, sell), marked when it happens.
function Coach.doneByState(mask: number, facts: Facts): number
	if facts.boughtPods > 0 then
		mask = Coach.mark(mask, "Shelf")
	end
	if facts.jetpackLevel > 0 then
		mask = Coach.mark(mask, "Jetpack")
	end
	return mask
end

-- True when `tip` makes sense now (done or not).
function Coach.wanted(tip: Tip, facts: Facts): boolean
	if tip == "Shelf" then
		return facts.freePods == 0 and facts.shelfCount > 0
	elseif tip == "Jetpack" then
		return facts.jetpackLevel == 0 and facts.canAffordJetpack
	elseif tip == "Quest" then
		return facts.questToClaim
	elseif tip == "Crossbreed" then
		return facts.hasTrio
	end
	return facts.shelfCount >= facts.shelfSlots
end

-- The tip that should show now, ignoring the pace: the first one not done that makes sense; nil
-- before the end of the tutorial and while carrying an egg.
function Coach.candidate(mask: number, facts: Facts): Tip?
	if not facts.tutorialDone or facts.carrying then
		return nil
	end
	for _, tip in Coach.TIPS do
		if not Coach.isDone(mask, tip) and Coach.wanted(tip, facts) then
			return tip
		end
	end
	return nil
end

-- What is on screen: the tip shown (nil: none), the last one shown, and when the last one went
-- away (server time).
export type Pace = {
	read shown: Tip?,
	read last: Tip?,
	read hiddenAt: number,
}

-- Nothing shown, and nothing to wait for.
function Coach.idle(): Pace
	return { shown = nil, last = nil, hiddenAt = -math.huge }
end

-- Nothing shown, and the next tip waits `pause` seconds from `now` (the tutorial has just ended:
-- its farewell line goes first).
function Coach.restFrom(now: number): Pace
	return { shown = nil, last = nil, hiddenAt = now }
end

-- The pace after `candidate` is worked out at `now`. A tip goes away at once; a new one shows
-- only `pause` seconds after the last went away, so hints never follow each other in a rush. The
-- same tip coming back (an egg carried home, the condition back) shows at once.
function Coach.pace(current: Pace, candidate: Tip?, now: number, pause: number): Pace
	if candidate == current.shown then
		return current
	end
	if current.shown ~= nil then
		return { shown = nil, last = current.shown, hiddenAt = now }
	end
	if candidate == nil then
		return current
	end
	if candidate == current.last or now - current.hiddenAt >= pause then
		return { shown = candidate, last = candidate, hiddenAt = current.hiddenAt }
	end
	return current
end

return table.freeze(Coach)
