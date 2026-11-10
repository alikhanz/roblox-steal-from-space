--!strict
-- Draws everyone's harpoon shots and gravity bombs on this client (brief
-- docs/design/screens/pvp-abilities.md): the server sends what happened (PvpService through
-- NetService: HarpoonShot, BombThrown, BombExploded) and this draws it, nearer than
-- PvpLooks.DRAW_DISTANCE to the camera (World/HarpoonVisual, World/BombVisual). Client-only parts
-- in workspace[PvpLooks.EFFECTS_FOLDER_NAME], stepped together once a frame.
-- Also every fight's sounds (docs/design/SOUND.md), heard from where they happen: the strike's
-- swing (a character's lunge starts) and hit (the server's impact part), the harpoon's shot and
-- grab (as the hook reaches its target), the bomb's throw and blast. The local player's own shot
-- and throw sound at the press, as the strike's lunge does, not a round trip later.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityState = require(script.Parent.Parent.State.AbilityState)
local BombVisual = require(script.Parent.Parent.World.BombVisual)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local FlightInputs = require(ReplicatedStorage.Shared.Input.FlightInputs)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local HarpoonVisual = require(script.Parent.Parent.World.HarpoonVisual)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local PvpLooks = require(ReplicatedStorage.Shared.Config.PvpLooks)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local SoundPlayer = require(script.Parent.Parent.Audio.SoundPlayer)

export type Dependencies = {
	abilities: AbilityState.AbilityState,
}

export type PvpEffectsController = {
	name: string,
	start: () -> (),
}

type Effect = { step: (deltaTime: number) -> boolean }

local PvpEffectsController = {}

local function isNear(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= PvpLooks.DRAW_DISTANCE
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The harpoon: the shot from the shooter, then the grab where the hook lands, as it gets there.
local function soundHarpoon(shooter: Player, target: Vector3, hit: boolean)
	local root = rootOf(shooter)
	-- The local player's own shot sounded at the press.
	if root and shooter ~= Players.LocalPlayer then
		SoundPlayer.play("HarpoonShot", { at = root })
	end
	if not hit then
		return
	end
	local flight = if root then (target - root.Position).Magnitude / PvpLooks.HARPOON.hookSpeed else 0
	task.delay(flight, function()
		SoundPlayer.play("HarpoonGrab", { at = target })
	end)
end

-- The local player's own abilities pressed, sounded at once: the same press the server reads
-- (FlightInputs), when the ability can go (in space, not stunned, not cooling down).
local OWN_SOUNDS: { [AbilityState.Kind]: SoundPlayer.Name } = { Harpoon = "HarpoonShot", Bomb = "BombThrow" }
local OWN_ACTIONS: { [AbilityState.Kind]: string } = { Harpoon = FlightInputs.HARPOON, Bomb = FlightInputs.BOMB }

local function watchOwnPresses(abilities: AbilityState.AbilityState)
	local player = Players.LocalPlayer
	local wasPressed: { [AbilityState.Kind]: boolean } = {}
	RunService.Heartbeat:Connect(function()
		local context = player:FindFirstChild(FlightInputs.CONTEXT_NAME)
		local character = player.Character
		local root = rootOf(player)
		local canUse = character ~= nil
			and character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true
			and character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE) == nil
		for kind, action in OWN_ACTIONS do
			local isPressed = context ~= nil and FlightInputs.isPressed(context, action)
			if isPressed and not wasPressed[kind] and canUse and root and not abilities.isCooling(kind) then
				SoundPlayer.play(OWN_SOUNDS[kind], { at = root })
			end
			wasPressed[kind] = isPressed
		end
	end)
end

function PvpEffectsController.new(dependencies: Dependencies): PvpEffectsController
	local effects: { Effect } = {}
	local bombs: { [number]: BombVisual.Effect } = {}

	local function step(deltaTime: number)
		for index = #effects, 1, -1 do
			if not effects[index].step(deltaTime) then
				table.remove(effects, index)
			end
		end
	end

	local function start()
		local folder = Instance.new("Folder")
		folder.Name = PvpLooks.EFFECTS_FOLDER_NAME
		folder.Parent = workspace

		Remotes.HarpoonShot.SetCallback(function(shot)
			soundHarpoon(shot.shooter, shot.target, shot.hit)
			if not isNear(shot.target) then
				return
			end
			local effect = HarpoonVisual.new(shot, folder)
			if effect then
				table.insert(effects, effect)
			end
		end)
		Remotes.BombThrown.SetCallback(function(throw)
			if throw.thrower ~= Players.LocalPlayer then
				SoundPlayer.play("BombThrow", { at = throw.start })
			end
			-- Drawn if it starts or could end near: it flies at most `fuse` seconds.
			local ending = throw.start + throw.velocity * throw.fuse
			if not isNear(throw.start) and not isNear(ending) then
				return
			end
			local effect = BombVisual.thrown(throw, folder)
			bombs[throw.id] = effect
			table.insert(effects, effect)
		end)
		Remotes.BombExploded.SetCallback(function(blast)
			SoundPlayer.play("BombBoom", { at = blast.center })
			local bomb = bombs[blast.id]
			bombs[blast.id] = nil
			if bomb then
				bomb.explode(blast.center)
			elseif isNear(blast.center) then
				table.insert(effects, BombVisual.blast(blast.center, folder))
			end
		end)
		RunService.RenderStepped:Connect(step)
		watchOwnPresses(dependencies.abilities)

		CollectionService:GetInstanceAddedSignal(PvpConfig.STRIKE_IMPACT_TAG):Connect(function(impact)
			if impact:IsA("BasePart") then
				SoundPlayer.play("StrikeHit", { at = impact.Position })
			end
		end)
		-- A strike swings as its lunge starts (simulation state on the character: polled).
		local lunging: { [Player]: boolean } = {}
		RunService.Heartbeat:Connect(function()
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local lunge = character and character:GetAttribute(PvpConfig.STRIKE_LUNGE_ATTRIBUTE)
				local isLunging = type(lunge) == "number" and lunge > 0
				if isLunging and not lunging[player] then
					local root = rootOf(player)
					if root then
						SoundPlayer.play("StrikeSwing", { at = root })
					end
				end
				lunging[player] = isLunging or nil
			end
		end)
		Players.PlayerRemoving:Connect(function(player)
			lunging[player] = nil
		end)
	end

	return {
		name = "PvpEffectsController",
		start = start,
	}
end

return table.freeze(PvpEffectsController)
