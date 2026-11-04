--!strict
-- The alien index: every alien a player has ever had. An alien is found the first time it
-- comes to the player (hatched, crossbred); its reward waits in the index until the player
-- takes it. A guardian whose aliens are all found makes a set, with a reward of its own, once.
-- Pure: which aliens make a set is passed in (AlienConfig.GRADES).

local AlienIndex = {}

-- As saved.
export type State = {
	-- Alien id -> its reward is taken. Present: found.
	found: { [string]: boolean },
	-- Grades whose set reward is taken.
	sets: { number },
}

-- One guardian's set: its grade and its aliens, lowest tier first (IndexConfig.SETS).
export type Set = {
	read grade: number,
	read aliens: { string },
}

export type ClaimRefusal = "IndexNothing" | "IndexClaimed"

function AlienIndex.empty(): State
	return { found = {}, sets = {} }
end

function AlienIndex.isFound(state: State, alienId: string): boolean
	return state.found[alienId] ~= nil
end

-- Marks `alienId` found. True when it is new.
function AlienIndex.discover(state: State, alienId: string): boolean
	if state.found[alienId] ~= nil then
		return false
	end
	state.found[alienId] = false
	return true
end

-- Marks every one of `alienIds` found with its reward already taken (aliens a player had before
-- the index existed).
function AlienIndex.seed(state: State, alienIds: { string })
	for _, alienId in alienIds do
		state.found[alienId] = true
	end
end

-- Takes the reward of a found alien, once.
function AlienIndex.claim(state: State, alienId: string): ClaimRefusal?
	local taken = state.found[alienId]
	if taken == nil then
		return "IndexNothing"
	elseif taken then
		return "IndexClaimed"
	end
	state.found[alienId] = true
	return nil
end

-- How many of `alienIds` (one guardian's set) are found.
function AlienIndex.foundOf(state: State, alienIds: { string }): number
	local count = 0
	for _, alienId in alienIds do
		if state.found[alienId] ~= nil then
			count += 1
		end
	end
	return count
end

function AlienIndex.isSetClaimed(state: State, grade: number): boolean
	return table.find(state.sets, grade) ~= nil
end

-- Takes the reward of the set of `grade`, whose aliens are `alienIds`, once it is complete.
function AlienIndex.claimSet(state: State, grade: number, alienIds: { string }): ClaimRefusal?
	if AlienIndex.isSetClaimed(state, grade) then
		return "IndexClaimed"
	elseif AlienIndex.foundOf(state, alienIds) < #alienIds then
		return "IndexNothing"
	end
	table.insert(state.sets, grade)
	return nil
end

-- Rewards waiting to be taken: found aliens not yet claimed, plus complete sets not yet claimed.
function AlienIndex.waiting(state: State, sets: { Set }): number
	local count = 0
	for _, taken in state.found do
		if not taken then
			count += 1
		end
	end
	for _, set in sets do
		if not AlienIndex.isSetClaimed(state, set.grade) and AlienIndex.foundOf(state, set.aliens) == #set.aliens then
			count += 1
		end
	end
	return count
end

return table.freeze(AlienIndex)
