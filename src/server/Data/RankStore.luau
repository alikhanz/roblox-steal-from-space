--!strict
-- A ranked store of integer scores by user id: the shared one all servers write to
-- (OrderedDataStore), or an in-memory one for Studio, where an unpublished place has no data
-- stores. Calls yield and may fail: a failure is returned with its message, never thrown, and
-- the caller decides what to say. The player's profile never depends on it.

local DataStoreService = game:GetService("DataStoreService")

-- One item of a page, as OrderedDataStore returns it.
export type Item = { key: string, value: number }

export type RankStore = {
	-- Writes a player's score; false and why when the store refused.
	set: (userId: number, score: number) -> (boolean, string?),
	-- The best `limit` items, highest first; nil and why when the store refused.
	top: (limit: number) -> ({ Item }?, string?),
}

local RankStore = {}

function RankStore.ordered(name: string): RankStore
	-- Getting the store already fails in an unpublished place, so it is got on first use.
	local store: OrderedDataStore? = nil
	local function get(): OrderedDataStore
		if not store then
			store = DataStoreService:GetOrderedDataStore(name)
		end
		return store :: OrderedDataStore
	end
	return {
		set = function(userId, score)
			local ok, problem = pcall(function()
				get():SetAsync(tostring(userId), score)
			end)
			return ok, if ok then nil else tostring(problem)
		end,
		top = function(limit)
			local ok, result = pcall(function(): { Item }
				local pages = get():GetSortedAsync(false, limit)
				return pages:GetCurrentPage() :: any
			end)
			if not ok then
				return nil, tostring(result)
			end
			return result, nil
		end,
	}
end

-- Lives as long as the server: enough to see the board work in Studio.
function RankStore.memory(): RankStore
	local scores: { [string]: number } = {}
	return {
		set = function(userId, score)
			scores[tostring(userId)] = score
			return true, nil
		end,
		top = function(limit)
			local items: { Item } = {}
			for key, value in scores do
				table.insert(items, { key = key, value = value })
			end
			table.sort(items, function(left: Item, right: Item): boolean
				return left.value > right.value
			end)
			while #items > limit do
				table.remove(items)
			end
			return items, nil
		end,
	}
end

return table.freeze(RankStore)
