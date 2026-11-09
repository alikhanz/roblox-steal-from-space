--!strict
-- The pet bench for measuring the island on a phone (decision 082, docs/plans/ALIEN_MODELS.md
-- step 4): fills the player's island to the full 30 places with a heavy, varied set of aliens (all
-- six families, many legendaries with wings, comets and the medal, meteor ones, giants from the far
-- guardians), and takes them away again. Only in Studio and, in a live server, only in the Dev game
-- (DevConfig.BENCH_GAME_IDS) and only for the game's creator: the player attribute
-- DevConfig.BENCH_ATTRIBUTE shows the client its two buttons. What the bench changed is kept on
-- this server only: clearing after a rejoin finds nothing to undo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)

-- Tiers in the bench, round and round: the heavy ones (wings, comets, the medal) most often.
local BENCH_TIERS: { AlienConfig.TierId } = { "Legendary", "Epic", "Rare", "Legendary", "Uncommon", "Epic" }
-- Every this many is a meteor one (a fire tail, fireball comets, a crest).
local METEOR_EVERY = 4
-- The guardian step between two bench aliens: spreads them over all the zones and families.
local GRADE_STEP = 5

export type Dependencies = {
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	-- Rebuilds the bay.
	refresh: (player: Player) -> (),
}

export type BenchService = {
	name: string,
	start: () -> (),
	-- Fills the island (`fill`) or takes the bench away; nothing for a player not allowed.
	run: (player: Player, fill: boolean) -> (),
}

-- What the bench did to a player's places: how many there were, and the uids it put in.
type Change = {
	pods: number,
	uids: { [number]: boolean },
}

local BenchService = {}

-- The bench's aliens, the `count` of them.
local function benchAliens(count: number): { AlienConfig.AlienId }
	local aliens: { AlienConfig.AlienId } = {}
	for index = 1, count do
		local grade = AlienConfig.GRADES[((index - 1) * GRADE_STEP) % #AlienConfig.GRADES + 1]
		local kind = grade.kinds[(index - 1) % #grade.kinds + 1]
		local tier = BENCH_TIERS[(index - 1) % #BENCH_TIERS + 1]
		local variant: AlienConfig.VariantId = if index % METEOR_EVERY == 0 then "Meteor" else "Normal"
		table.insert(aliens, grade.variants[variant][kind][tier])
	end
	return aliens
end

local function isCreator(player: Player): boolean
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank == 255
end

local function allowed(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return table.find(DevConfig.BENCH_GAME_IDS, game.GameId) ~= nil and isCreator(player)
end

function BenchService.new(dependencies: Dependencies): BenchService
	local changes: { [Player]: Change } = {}

	local function fill(player: Player)
		if changes[player] then
			return
		end
		local data = dependencies.getData(player)
		if not data then
			return
		end
		local change: Change = { pods = #data.pods, uids = {} }
		local written = dependencies.update(player, function(profile)
			while #profile.pods < BayConfig.MAX_PODS do
				table.insert(profile.pods, {})
			end
			local queue = benchAliens(BayConfig.MAX_PODS)
			local next = 1
			for _, pod in profile.pods do
				if not pod.alien then
					local uid = Bay.newUid(profile)
					pod.alien = { uid = uid, id = queue[next] }
					change.uids[uid] = true
					next += 1
				end
			end
		end)
		if written then
			changes[player] = change
			dependencies.refresh(player)
		end
	end

	local function clear(player: Player)
		local change = changes[player]
		if not change then
			return
		end
		local written = dependencies.update(player, function(profile)
			for _, pod in profile.pods do
				if pod.alien and change.uids[pod.alien.uid] then
					pod.alien = nil
				end
			end
			-- The places the bench added, while they stand empty (the player's own aliens stay).
			while #profile.pods > change.pods and not profile.pods[#profile.pods].alien do
				table.remove(profile.pods)
			end
		end)
		if written then
			changes[player] = nil
			dependencies.refresh(player)
		end
	end

	local function run(player: Player, wanted: boolean)
		if not allowed(player) then
			return
		end
		if wanted then
			fill(player)
		else
			clear(player)
		end
	end

	local function start()
		local function mark(player: Player)
			player:SetAttribute(DevConfig.BENCH_ATTRIBUTE, allowed(player))
		end
		Players.PlayerAdded:Connect(mark)
		for _, player in Players:GetPlayers() do
			mark(player)
		end
		Players.PlayerRemoving:Connect(function(player)
			changes[player] = nil
		end)
	end

	return {
		name = "BenchService",
		start = start,
		run = run,
	}
end

return table.freeze(BenchService)
