--!strict
-- The order the client asks for its assets in (LoadConfig): the player's own jetpack first, the
-- rest after it. Every ContentProvider:PreloadAsync puts its assets at the front of the client's
-- download queue, so many preloads at the join (pets on every island, sounds, icon sheets) kept
-- pushing the jetpack's meshes back: on a cold phone its body showed 30–40 s late. Here: a queue
-- of preloads by priority (first come first within one), which waits until the jetpack is in.

local LoadOrder = {}

export type Queue<T> = {
	entries: { Entry<T> },
	-- The order of arrival, to keep it within one priority.
	nextSeq: number,
}

type Entry<T> = {
	priority: number,
	seq: number,
	item: T,
}

function LoadOrder.new<T>(): Queue<T>
	return { entries = {}, nextSeq = 1 }
end

-- Higher priority goes first; within one, whatever came first.
function LoadOrder.push<T>(queue: Queue<T>, priority: number, item: T)
	table.insert(queue.entries, { priority = priority, seq = queue.nextSeq, item = item })
	queue.nextSeq += 1
end

-- Takes the next item out, nil when the queue is empty.
function LoadOrder.pop<T>(queue: Queue<T>): T?
	local entries = queue.entries
	if #entries == 0 then
		return nil
	end
	local best = 1
	for index = 2, #entries do
		local entry, chosen = entries[index], entries[best]
		if entry.priority > chosen.priority or (entry.priority == chosen.priority and entry.seq < chosen.seq) then
			best = index
		end
	end
	local item = entries[best].item
	table.remove(entries, best)
	return item
end

function LoadOrder.size<T>(queue: Queue<T>): number
	return #queue.entries
end

-- What the client knows about its own jetpack.
export type Jetpack = {
	-- The jetpack of the player's level (JetpackLooks.jetpackOf), nil until the profile is in.
	expected: number?,
	-- The jetpack on the character, nil while it has none.
	worn: number?,
	-- The worn jetpack's assets have all resolved (loaded, or failed for good).
	loaded: boolean,
	-- Seconds since the client started.
	elapsed: number,
}

-- Whether the rest may load: the jetpack of the player's level is on and loaded — not the Starter
-- the character wears until the profile is in, which is swapped for it a moment later — or the
-- wait is over anyway (a rig with no jetpack, a profile that is slow to come).
function LoadOrder.jetpackReady(jetpack: Jetpack, timeout: number): boolean
	if jetpack.elapsed >= timeout then
		return true
	end
	return jetpack.expected ~= nil and jetpack.worn == jetpack.expected and jetpack.loaded
end

return table.freeze(LoadOrder)
