--!strict
-- The pet bench on a player's data (decision 082): fills the island's places up to a number with
-- the given aliens, and takes them away again. What it added is saved in the profile
-- (PlayerData.bench), so clearing works after a rejoin or on another server, and the player's own
-- aliens are never touched. Pure functions that change the data in place, for one update each.

local Bay = require("./Bay")
local PlayerData = require("./PlayerData")

type Data = PlayerData.PlayerData

local Bench = {}

-- Adds places up to `maxPods` and stands `aliens` (in order) on every empty one. False when the
-- bench already stands (clear it first) or there was nothing to fill.
function Bench.fill(data: Data, aliens: { string }, maxPods: number): boolean
	if data.bench then
		return false
	end
	local record: PlayerData.BenchRecord = { pods = #data.pods, uids = {} }
	while #data.pods < maxPods do
		table.insert(data.pods, {})
	end
	local next = 1
	for _, pod in data.pods do
		if not pod.alien and aliens[next] then
			local uid = Bay.newUid(data)
			pod.alien = { uid = uid, id = aliens[next] }
			table.insert(record.uids, uid)
			next += 1
		end
	end
	while #data.pods > record.pods and not data.pods[#data.pods].alien do
		table.remove(data.pods)
	end
	if #record.uids == 0 then
		return false
	end
	data.bench = record
	return true
end

-- Takes the bench's aliens away, wherever they went (a place, the inventory, the floor), and the
-- places it added while they stand empty. False when no bench stands.
function Bench.clear(data: Data): boolean
	local record = data.bench
	if not record then
		return false
	end
	local added: { [number]: boolean } = {}
	for _, uid in record.uids do
		added[uid] = true
	end
	for _, pod in data.pods do
		if pod.alien and added[pod.alien.uid] then
			pod.alien = nil
		end
	end
	for _, list in { data.inventory, data.floor } do
		for index = #list, 1, -1 do
			if added[list[index].uid] then
				table.remove(list, index)
			end
		end
	end
	while #data.pods > record.pods and not data.pods[#data.pods].alien do
		table.remove(data.pods)
	end
	data.bench = nil
	return true
end

return table.freeze(Bench)
