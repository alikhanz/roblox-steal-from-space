--!strict
-- The alien index: every alien a player has ever had. An alien is found the first time it
-- comes to the player (hatched, crossbred); its reward waits in the index until the player
-- takes it. A guardian whose aliens of one variant are all found makes a set, with a reward of
-- its own, once. Pure: which aliens make a set is passed in (IndexConfig.SETS).

local AlienIndex = {}

-- As saved.
export type State = {
	-- Alien id -> its reward is taken. Present: found.
	found: { [string]: boolean },
	-- Sets whose reward is taken, by set id.
	sets: { string },
}

-- One guardian's aliens of one variant, lowest tier first (IndexConfig.SETS).
export type Set = {
	-- Stable: "3" for the usual aliens of grade 3, "3.Meteor" for its meteor ones (save format).
	read id: string,
	read grade: number,
	read variant: string,
	read aliens: { string },
}

-- The id of the set of `grade` in `variant`.
function AlienIndex.setId(grade: number, variant: string): string
	return if variant == "Normal" then tostring(grade) else `{grade}.{variant}`
end

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

function AlienIndex.isSetClaimed(state: State, set: Set): boolean
	return table.find(state.sets, set.id) ~= nil
end

-- Takes the reward of `set` once it is complete.
function AlienIndex.claimSet(state: State, set: Set): ClaimRefusal?
	if AlienIndex.isSetClaimed(state, set) then
		return "IndexClaimed"
	elseif AlienIndex.foundOf(state, set.aliens) < #set.aliens then
		return "IndexNothing"
	end
	table.insert(state.sets, set.id)
	return nil
end

-- The rewards waiting in `sets`, to take them all at once: found aliens not yet claimed (in
-- the order of `sets`), and sets complete and not yet claimed.
function AlienIndex.pending(state: State, sets: { Set }): ({ string }, { Set })
	local aliens: { string } = {}
	local ready: { Set } = {}
	for _, set in sets do
		for _, alienId in set.aliens do
			if state.found[alienId] == false then
				table.insert(aliens, alienId)
			end
		end
		if not AlienIndex.isSetClaimed(state, set) and AlienIndex.foundOf(state, set.aliens) == #set.aliens then
			table.insert(ready, set)
		end
	end
	return aliens, ready
end

-- Rewards waiting to be taken in `sets` (all of them, or one section's): their found aliens not
-- yet claimed, plus those of them complete and not yet claimed.
function AlienIndex.waiting(state: State, sets: { Set }): number
	local count = 0
	for _, set in sets do
		for _, alienId in set.aliens do
			if state.found[alienId] == false then
				count += 1
			end
		end
		if not AlienIndex.isSetClaimed(state, set) and AlienIndex.foundOf(state, set.aliens) == #set.aliens then
			count += 1
		end
	end
	return count
end

-- Where the index window opens: the first of `sets` with a reward waiting, else the last of
-- `fallback` with any alien found (the farthest guardian the player has aliens of), else nil.
function AlienIndex.openingSet(state: State, sets: { Set }, fallback: { Set }): Set?
	for _, set in sets do
		if AlienIndex.waiting(state, { set }) > 0 then
			return set
		end
	end
	for position = #fallback, 1, -1 do
		local set = fallback[position]
		if AlienIndex.foundOf(state, set.aliens) > 0 then
			return set
		end
	end
	return nil
end

return table.freeze(AlienIndex)
