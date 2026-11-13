--!strict
-- Keeps the camera calm while the jetpack stand holds the local player (docs/design/screens/
-- jetpack-stand.md). Roblox's camera follows the character's root, and on the stand the root
-- trembles: the trembling pose turns physical joints (AnimationConstraint under Server Authority),
-- and their push shakes the root that the stand holds. The rider may tremble; the camera should
-- not (user, 2026-11-13). Runs after the camera has been placed and moves it by the gap between
-- the root and the point the stand holds it at (Stand.holdPoint), so its eye stays on that point.
-- Eased in and out, so boarding and stepping off glide instead of jumping. Cosmetic only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local Stand = require(ReplicatedStorage.Shared.Domain.Stand)
local StandConfig = require(ReplicatedStorage.Shared.Config.StandConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)

local RENDER_STEP_NAME = "StandCamera"
-- How long the hold eases in when the stand takes the player, and out when they leave, seconds.
local EASE_SECONDS = 0.3

export type StandCameraController = {
	name: string,
	start: () -> (),
}

local StandCameraController = {}

-- Where the stand holds the local player's root, if it holds them now.
local function holdPoint(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	if not Stand.isTraining(Stand.parse(character:GetAttribute(StandConfig.STATE_ATTRIBUTE))) then
		return nil
	end
	local island = player:GetAttribute(StandConfig.ISLAND_ATTRIBUTE)
	local frame = if type(island) == "number" then StationConfig.ISLAND_FRAMES[island] else nil
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not frame or not humanoid or not root then
		return nil
	end
	local pad = BayConfig.TRAINER_PAD
	local height =
		Stand.holdHeight(StandConfig.PLATFORM_HEIGHT, StandConfig.HOVER_HEIGHT, humanoid.HipHeight, root.Size.Y)
	return Stand.holdPoint(frame, pad.x, pad.z, height)
end

function StandCameraController.new(): StandCameraController
	local player = Players.LocalPlayer
	-- 0: the camera follows the root as usual; 1: it keeps to the hold point.
	local blend = 0
	-- The last hold point, for easing out after the stand lets go.
	local lastHold: Vector3? = nil

	local function update(deltaTime: number)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hold = holdPoint(player)
		local step = deltaTime / EASE_SECONDS
		blend = if hold then math.min(1, blend + step) else math.max(0, blend - step)
		if hold then
			lastHold = hold
		end
		local target = hold or lastHold
		if blend <= 0 or not camera or not root or not target then
			lastHold = if blend > 0 then lastHold else nil
			return
		end
		local offset = (target - root.Position) * blend
		camera.CFrame += offset
		camera.Focus += offset
	end

	local function start()
		RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, update)
	end

	return {
		name = "StandCameraController",
		start = start,
	}
end

return table.freeze(StandCameraController)
