--!strict
-- What the local player's harpoon and gravity bomb would go for right now: the same pick the
-- server makes (PvpService, decision 106: Abilities.bestInCone along the camera's aim, among the
-- targets the rules let them attack), on what this client sees. For the crosshair's lock.
-- Targets: other players' characters, test dummies (PvpConfig.DUMMY_TAG) and the star serpent's
-- head. The rules are checked as far as a client knows them: the spawn grace is left out.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Domain.Abilities)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local Pvp = require(ReplicatedStorage.Shared.Domain.Pvp)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local SerpentConfig = require(ReplicatedStorage.Shared.Config.SerpentConfig)
local SerpentHunt = require(ReplicatedStorage.Shared.Domain.SerpentHunt)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)

local AimTargets = {}

type Candidate = {
	root: BasePart,
	-- Its body's radius around `root` (the server's Creature.radius).
	radius: number,
	isCarrying: boolean,
	-- Nil for a creature: only the station keeps it safe, and that is the attacker's side.
	side: Pvp.Side?,
}

local function toVector(v: Vector3): Abilities.Vector
	return { x = v.X, y = v.Y, z = v.Z }
end

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- A player's side as the rules see it, from what the server publishes on them.
local function sideOf(player: Player, character: Model): Pvp.Side
	local speed = BigNum.fromSaved({
		mantissa = player:GetAttribute(SpeedConfig.MANTISSA_ATTRIBUTE),
		exponent = player:GetAttribute(SpeedConfig.EXPONENT_ATTRIBUTE),
	})
	local newbieLeft = player:GetAttribute(PvpConfig.NEWBIE_ATTRIBUTE)
	return {
		speed = speed or SpeedConfig.STARTING_SPEED,
		playSeconds = PvpConfig.RULES.newbieSeconds - (if type(newbieLeft) == "number" then newbieLeft else 0),
		isInStation = character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) ~= true,
		-- Unknown here: the spawn grace is not checked.
		spawnedAt = -math.huge,
	}
end

local function serpentCandidate(): Candidate?
	local world = workspace:FindFirstChild("World")
	local model = world and world:FindFirstChild(SerpentConfig.MODEL_NAME)
	if not model or not model:IsA("Model") then
		return nil
	end
	local head = model.PrimaryPart or model:FindFirstChild(SerpentConfig.HEAD_NAME)
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local events = ReplicatedStorage:FindFirstChild(EventConfig.FOLDER_NAME)
	local folder = events and events:FindFirstChild("Serpent")
	local egg = folder and folder:GetAttribute(SerpentConfig.EGG_ATTRIBUTE)
	local inside: SerpentHunt.EggPlace = "Inside"
	return { root = head, radius = SerpentConfig.HIT_RADIUS, isCarrying = egg == inside, side = nil }
end

local function candidatesFor(player: Player): { Candidate }
	local candidates: { Candidate } = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = rootOf(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if other == player or not character or not root or (humanoid and humanoid.Health <= 0) then
			continue
		end
		table.insert(candidates, {
			root = root,
			radius = 0,
			isCarrying = character:GetAttribute(EggConfig.CARRIED_RARITY_ATTRIBUTE) ~= nil,
			side = sideOf(other, character),
		})
	end
	for _, dummy in CollectionService:GetTagged(PvpConfig.DUMMY_TAG) do
		local root = if dummy:IsA("Model") then rootOf(dummy) else nil
		if root then
			-- A dummy always holds an egg while it lives.
			table.insert(candidates, { root = root, radius = 0, isCarrying = true, side = nil })
		end
	end
	local serpent = serpentCandidate()
	if serpent then
		table.insert(candidates, serpent)
	end
	return candidates
end

-- The root part of whom `player`'s ability would go for along the camera's aim: within
-- `reach` and `halfAngle`, egg carriers only when `carriersOnly`. Nil when nobody, or when the
-- player cannot attack at all (in the station, a newbie).
local function pick(player: Player, reach: number, halfAngle: number, carriersOnly: boolean): BasePart?
	local character = player.Character
	local root = rootOf(character)
	local camera = workspace.CurrentCamera
	if not character or not root or not camera then
		return nil
	end
	local attacker = sideOf(player, character)
	if attacker.isInStation or Pvp.isNewbie(attacker.playSeconds, PvpConfig.RULES) then
		return nil
	end
	local origin = toVector(root.Position)
	local listed: { { id: BasePart, position: Abilities.Vector } } = {}
	for _, candidate in candidatesFor(player) do
		if carriersOnly and not candidate.isCarrying then
			continue
		end
		local side = candidate.side
		if side and Pvp.refusal(attacker, side, 0, PvpConfig.RULES) then
			continue
		end
		local position = Abilities.nearestPoint(toVector(candidate.root.Position), candidate.radius, origin)
		table.insert(listed, { id = candidate.root, position = position })
	end
	return Abilities.bestInCone(origin, toVector(camera.CFrame.LookVector), listed, reach, halfAngle)
end

-- The egg carrier the harpoon would hit.
function AimTargets.harpoon(player: Player): BasePart?
	return pick(player, PvpConfig.HARPOON.rangeStuds, PvpConfig.HARPOON.halfAngleRadians, true)
end

-- The target the bomb would home on.
function AimTargets.bomb(player: Player): BasePart?
	return pick(player, PvpConfig.BOMB.homingRangeStuds, PvpConfig.BOMB.homingHalfAngleRadians, false)
end

return table.freeze(AimTargets)
