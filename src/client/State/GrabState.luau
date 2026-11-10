--!strict
-- What the grab button shows (docs/design/screens/grab-button.md), read every frame from the
-- local character: the egg the button offers or the grab is locked on, and the grab's progress.
-- The simulation owns the grab (Grab.nextEngaged, character attributes); this only mirrors it
-- with the same egg search, so the button, the prompt over the egg and the tutorial agree. While
-- no egg is anywhere near, the search runs only a few times a second (EggConfig.GRAB_SEARCH_*).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggTargets = require(ReplicatedStorage.Shared.Simulation.EggTargets)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local Grab = require(ReplicatedStorage.Shared.Domain.Grab)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local TopSpeed = require(ReplicatedStorage.Shared.Simulation.TopSpeed)
local Vide = require(ReplicatedStorage.Packages.Vide)

export type GrabState = {
	name: string,
	start: () -> (),
	-- The egg the button is for: the locked-on one, else the nearest offered one; nil: no button
	-- (reactive).
	target: () -> EggTargets.Target?,
	-- The grab is locked on (pressed once).
	engaged: () -> boolean,
	-- Grab progress, 0..1.
	progress: () -> number,
}

local GrabState = {}

function GrabState.new(): GrabState
	local target = Vide.source(nil :: EggTargets.Target?)
	-- An optional source is read through a getter (see CLAUDE.md, Vide).
	local readTarget = target :: () -> EggTargets.Target?
	local engaged = Vide.source(false)
	local progress = Vide.source(0)

	local function setEngaged(value: boolean)
		if Vide.untrack(engaged) ~= value then
			engaged(value)
		end
	end
	local function setProgress(value: number)
		if Vide.untrack(progress) ~= value then
			progress(value)
		end
	end
	-- When to look for an egg to offer next (os.clock()): every frame while one is near, else a
	-- few times a second, far enough out that no egg slips in between (Grab.watchRange).
	local searchAt = 0

	local function nearest(position: Vector3, range: number, topSpeed: number): EggTargets.Target?
		local now = os.clock()
		if now < searchAt then
			return nil
		end
		local watch = Grab.watchRange(
			range,
			topSpeed * EggConfig.GRAB_SEARCH_SPEED_SLACK,
			EggConfig.DROP_SPEED,
			EggConfig.GRAB_SEARCH_SECONDS
		)
		local near = EggTargets.nearest(position, watch)
		searchAt = if near then now else now + EggConfig.GRAB_SEARCH_SECONDS
		return if near and (near.position - position).Magnitude <= range then near else nil
	end

	local function update()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local canGrab = character ~= nil
			and character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true
			and character:GetAttribute(EggConfig.CARRIED_RARITY_ATTRIBUTE) == nil
			and typeof(character:GetAttribute(GuardianConfig.HIT_VELOCITY_ATTRIBUTE)) ~= "Vector3"
		if not character or not canGrab or not root or not root:IsA("BasePart") then
			if Vide.untrack(readTarget) ~= nil then
				target(nil)
			end
			setEngaged(false)
			setProgress(0)
			-- Able to grab again (out in space, hands free): look at once.
			searchAt = 0
			return
		end
		local topSpeed = TopSpeed.of(character)
		local lockRange = Grab.lockRange(topSpeed, EggConfig.GRAB_REACH, EggConfig.LOCK_LEAD_SECONDS)
		local range = Grab.buttonRange(lockRange, EggConfig.GRAB_BUTTON_RANGE)
		local engagedId = character:GetAttribute(EggConfig.GRAB_ENGAGED_ATTRIBUTE)
		local locked = if type(engagedId) == "string"
			then EggTargets.find(engagedId, root.Position, range * EggConfig.GRAB_RELEASE_FACTOR)
			else nil
		if locked then
			-- No search while locked on; once it lets go, the next egg is looked for at once.
			searchAt = 0
		end
		local found = locked or nearest(root.Position, range, topSpeed)
		local previous = Vide.untrack(readTarget)
		-- A new table every frame: the button only needs a change of egg.
		if (previous and previous.id) ~= (found and found.id) then
			target(found)
		end
		setEngaged(locked ~= nil)
		local value = character:GetAttribute(EggConfig.GRAB_PROGRESS_ATTRIBUTE)
		setProgress(if locked and type(value) == "number" then value else 0)
	end

	local function start()
		RunService.RenderStepped:Connect(update)
	end

	return {
		name = "GrabState",
		start = start,
		target = function(): EggTargets.Target?
			return readTarget()
		end,
		engaged = function(): boolean
			return engaged()
		end,
		progress = function(): number
			return progress()
		end,
	}
end

return table.freeze(GrabState)
