--!strict
-- Grabbing an egg: hold the grab input next to the nest until the progress fills.
-- Letting go or drifting out of reach resets it.

local Grab = {}

-- Progress 0..1 after one step.
function Grab.step(progress: number, holding: boolean, inReach: boolean, grabSeconds: number, deltaTime: number): number
	if not holding or not inReach then
		return 0
	end
	if grabSeconds <= 0 then
		return 1
	end
	return math.min(progress + deltaTime / grabSeconds, 1)
end

function Grab.isComplete(progress: number): boolean
	return progress >= 1
end

return table.freeze(Grab)
