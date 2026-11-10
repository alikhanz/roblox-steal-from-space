--!strict
-- The pet bench for measuring the island on a phone (decision 082, docs/plans/ALIEN_MODELS.md
-- step 4): fills the player's island to the full 30 places with a heavy, varied set of aliens (all
-- six families, many legendaries with wings, comets and the medal, meteor ones, giants from the far
-- guardians), and takes them away again. Only in Studio and, in a live server, only in the Dev game
-- (DevConfig.BENCH_GAME_IDS) and only for the game's creator: the player attribute
-- DevConfig.BENCH_ATTRIBUTE shows the client its two buttons. What the bench changed is saved in
-- the profile (Domain/Bench): clearing works after a rejoin too (it kept to the server once, and a
-- rejoin left the island full with nothing to clear; user, 2026-11-10).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local Bench = require(ReplicatedStorage.Shared.Domain.Bench)
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
	local function run(player: Player, wanted: boolean)
		if not allowed(player) or not dependencies.getData(player) then
			return
		end
		local changed = false
		dependencies.update(player, function(data)
			changed = if wanted
				then Bench.fill(data, benchAliens(BayConfig.MAX_PODS), BayConfig.MAX_PODS)
				else Bench.clear(data)
		end)
		if changed then
			dependencies.refresh(player)
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
	end

	return {
		name = "BenchService",
		start = start,
		run = run,
	}
end

return table.freeze(BenchService)
