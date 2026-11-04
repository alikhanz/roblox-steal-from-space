--!strict
-- The new player's funnel: the first-time milestones from joining to the second zone. Each is
-- logged once per account; the steps reached are kept in the profile as a bit mask, so a step
-- reached out of order (training to guardian 4 before buying anything) is still counted once.
-- Pure Luau.

local Onboarding = {}

export type Step = {
	read number: number,
	read name: string,
}

-- In funnel order. Numbers are what analytics shows; never renumber a step once live.
Onboarding.STEPS = table.freeze({
	table.freeze({ number = 1, name = "Joined" }),
	table.freeze({ number = 2, name = "LeftStation" }),
	table.freeze({ number = 3, name = "GrabbedEgg" }),
	table.freeze({ number = 4, name = "DeliveredEgg" }),
	table.freeze({ number = 5, name = "HatchedAlien" }),
	table.freeze({ number = 6, name = "FirstPurchase" }),
	table.freeze({ number = 7, name = "StoleFromPost4" }),
	table.freeze({ number = 8, name = "StoleFromPost6" }),
	table.freeze({ number = 9, name = "StoleInIceRings" }),
} :: { Step })

local BY_NAME: { [string]: Step } = {}
for _, step in Onboarding.STEPS do
	BY_NAME[step.name] = step
end

function Onboarding.step(name: string): Step
	local step = BY_NAME[name]
	assert(step, `Unknown onboarding step "{name}"`)
	return step
end

function Onboarding.has(mask: number, step: Step): boolean
	return bit32.btest(mask, bit32.lshift(1, step.number - 1))
end

-- The mask with `step` reached, and whether it was new.
function Onboarding.mark(mask: number, step: Step): (number, boolean)
	if Onboarding.has(mask, step) then
		return mask, false
	end
	return bit32.bor(mask, bit32.lshift(1, step.number - 1)), true
end

-- The steps a delivered egg of guardian post `grade` reaches (from post 4, from post 6, from
-- the Ice Rings, whose first post is `iceRingsFirstPost`).
function Onboarding.stealSteps(grade: number, iceRingsFirstPost: number): { Step }
	local steps = {}
	if grade >= 4 then
		table.insert(steps, BY_NAME.StoleFromPost4)
	end
	if grade >= 6 then
		table.insert(steps, BY_NAME.StoleFromPost6)
	end
	if grade >= iceRingsFirstPost then
		table.insert(steps, BY_NAME.StoleInIceRings)
	end
	return steps
end

return table.freeze(Onboarding)
