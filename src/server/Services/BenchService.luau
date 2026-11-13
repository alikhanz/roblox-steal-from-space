--!strict
-- The pet bench for measuring the island on a phone (decision 082, docs/plans/ALIEN_MODELS.md
-- step 4): fills the player's island to the full 30 places with a heavy, varied set of aliens (all
-- six families, many legendaries with wings, comets and the medal, meteor ones, giants from the far
-- guardians), and takes them away again. Only in Studio and, in a live server, only in the Dev game
-- (DevConfig.BENCH_GAME_IDS) and only for the game's creator: the player attribute
-- DevConfig.BENCH_ATTRIBUTE shows the client its two buttons. What the bench changed is saved in
-- the profile (Domain/Bench): clearing works after a rejoin too (it kept to the server once, and a
-- rejoin left the island full with nothing to clear; user, 2026-11-10).

--
-- The guardian bench (docs/plans/GUARDIANS.md, phone load): the Event Horizon's guardians, as many
-- as the zone has (7 nests a post, 42, the biggest models), set in a ring round the player, a
-- third each asleep, chasing and going home, so a phone shows the load of flying through that
-- zone without the flight. The guardian gallery: one guardian of every post, zone after zone round
-- the player, all chasing, to look the models over. Both are display guardians: still bodies with
-- no brain, which every client dresses as it does real ones; one display a player at a time. They
-- live on the server only, until taken away or the player leaves.
--
-- The pet gallery (decision 118): the bench filled with one family's aliens, a page at a time
-- (Domain/PetGallery), so the creator can look every low-poly model and outfit over on a phone in
-- the Dev game; each press the next page, "/bench clear" takes it away like the bench.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local Bench = require(ReplicatedStorage.Shared.Domain.Bench)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)
local GuardianBrain = require(ReplicatedStorage.Shared.Domain.GuardianBrain)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local GuardianLooks = require(ReplicatedStorage.Shared.Config.GuardianLooks)
local GuardianModel = require(script.Parent.Parent.World.GuardianModel)
local PetGallery = require(ReplicatedStorage.Shared.Domain.PetGallery)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

-- The guardian bench's zone, its ring round the player (studs: past the biggest models' length,
-- inside the guardians' motion distance, so all of them move) and how high above the player.
local BENCH_GUARDIAN_ZONE: ZoneConfig.ZoneId = "EventHorizon"
local BENCH_GUARDIAN_RING = 200
local BENCH_GUARDIAN_RISE = 20
local BENCH_GUARDIAN_STATES: { GuardianBrain.State } = { "Sleep", "Chase", "Return" }
-- The gallery's ring: 24 guardians about 34 studs apart (the longest model is 24), all near
-- enough to move.
local GALLERY_RING = 130
local GALLERY_STATES: { GuardianBrain.State } = { "Chase" }

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
	-- Sets the guardian bench or the gallery round the player, or takes it away (Off); nothing for
	-- a player not allowed.
	showGuardians: (player: Player, display: GuardianDisplay) -> (),
	-- Fills the island with the pet gallery's next page (Domain/PetGallery), in place of any
	-- bench; "/bench clear" (`run(player, false)`) takes it away. Nothing for a player not allowed.
	gallery: (player: Player) -> (),
}

export type GuardianDisplay = "Off" | "Bench" | "Gallery"

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
	-- The gallery page each player has on the bench (an index into `galleryPages`).
	local galleryPages = PetGallery.pages(BayConfig.MAX_PODS)
	local galleryPage: { [Player]: number } = {}

	local function setGalleryPage(player: Player, page: number?)
		galleryPage[player] = page
		player:SetAttribute(DevConfig.GALLERY_ATTRIBUTE, if page then PetGallery.label(galleryPages[page]) else nil)
	end

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
		if not wanted then
			setGalleryPage(player, nil)
		end
		if changed then
			dependencies.refresh(player)
		end
	end

	-- Puts the gallery's next page on the bench, in place of whatever bench stood.
	local function gallery(player: Player)
		if not allowed(player) or not dependencies.getData(player) then
			return
		end
		local page = PetGallery.next(galleryPage[player] or 0, #galleryPages)
		local filled = false
		dependencies.update(player, function(data)
			Bench.clear(data)
			filled = Bench.fill(data, galleryPages[page].aliens, BayConfig.MAX_PODS)
		end)
		setGalleryPage(player, if filled then page else nil)
		dependencies.refresh(player)
	end

	-- The guardian bench of each player who set it.
	local guardianBenches: { [Player]: Folder } = {}

	local function clearGuardians(player: Player)
		local folder = guardianBenches[player]
		if folder then
			guardianBenches[player] = nil
			folder:Destroy()
		end
	end

	-- The bench: every post of its zone, as many times as the zone has nests a post.
	local function benchPosts(): { GuardianConfig.Post }
		local posts: { GuardianConfig.Post } = {}
		for _, post in GuardianConfig.POSTS do
			if post.zone == BENCH_GUARDIAN_ZONE then
				for _ = 1, ZoneConfig.ZONES[BENCH_GUARDIAN_ZONE].nestsPerPost do
					table.insert(posts, post)
				end
			end
		end
		return posts
	end

	local function showGuardians(player: Player, display: GuardianDisplay)
		if not allowed(player) then
			return
		end
		clearGuardians(player)
		if display == "Off" then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			return
		end
		local isGallery = display == "Gallery"
		local posts = if isGallery then GuardianConfig.POSTS else benchPosts()
		local ring = if isGallery then GALLERY_RING else BENCH_GUARDIAN_RING
		local states = if isGallery then GALLERY_STATES else BENCH_GUARDIAN_STATES
		local folder = Instance.new("Folder")
		folder.Name = `BenchGuardians{player.UserId}`
		local centre = root.Position + Vector3.yAxis * BENCH_GUARDIAN_RISE
		for index, post in posts do
			local angle = (index - 1) / #posts * 2 * math.pi
			local at = centre + Vector3.new(math.cos(angle), 0, math.sin(angle)) * ring
			local model = GuardianModel.build(GuardianLooks.KINDS[post.kind], GuardianLooks.POSTS[post.id])
			local body = model.PrimaryPart :: BasePart
			-- Still: no brain moves a display guardian.
			body.Anchored = true
			-- Facing the player, as a guardian faces its way (-Z).
			model:PivotTo(CFrame.lookAt(at, Vector3.new(centre.X, at.Y, centre.Z)))
			model:SetAttribute(GuardianConfig.POST_ATTRIBUTE, post.id)
			model:SetAttribute(GuardianConfig.STATE_ATTRIBUTE, states[(index - 1) % #states + 1])
			model:SetAttribute(GuardianConfig.RECOMMENDED_MANTISSA_ATTRIBUTE, post.recommended.mantissa)
			model:SetAttribute(GuardianConfig.RECOMMENDED_EXPONENT_ATTRIBUTE, post.recommended.exponent)
			CollectionService:AddTag(model, GuardianConfig.TAG)
			model.Parent = folder
		end
		folder.Parent = workspace:FindFirstChild("World") or workspace
		guardianBenches[player] = folder
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
			clearGuardians(player)
			galleryPage[player] = nil
		end)
	end

	return {
		name = "BenchService",
		start = start,
		run = run,
		showGuardians = showGuardians,
		gallery = gallery,
	}
end

return table.freeze(BenchService)
