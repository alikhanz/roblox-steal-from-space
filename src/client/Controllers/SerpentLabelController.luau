--!strict
-- The sign over the star serpent's head while it is out (docs/design/screens/guardian-labels.md):
-- the same sign as a guardian's (UI/GuardianLabel), its name and how it stands against the
-- player's own ⚡. The serpent of a zone is that zone's SerpentConfig.POWER_POST guardian in
-- strength, chasing a thief with its stat, so it is measured by that guardian's recommended
-- speed. The zone comes from the event's folder (EventConfig.ZONE_ATTRIBUTE); without it, the
-- sign has no pill.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local GuardianLabel = require(script.Parent.Parent.UI.GuardianLabel)
local GuardianLooks = require(ReplicatedStorage.Shared.Config.GuardianLooks)
local GuardianPose = require(ReplicatedStorage.Shared.Domain.GuardianPose)
local Mount = require(script.Parent.Parent.UI.Mount)
local SerpentConfig = require(ReplicatedStorage.Shared.Config.SerpentConfig)
local Speed = require(ReplicatedStorage.Shared.Domain.Speed)
local SpeedConfig = require(ReplicatedStorage.Shared.Config.SpeedConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Vide = require(ReplicatedStorage.Packages.Vide)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local ZoneLooks = require(ReplicatedStorage.Shared.Config.ZoneLooks)

local WORLD_WAIT_TIMEOUT = 30
local LABEL = GuardianLooks.LABEL

export type Dependencies = {
	-- The player's speed stat: the sign tells how the serpent stands against it.
	speed: () -> BigNum.BigNum,
}

export type SerpentLabelController = {
	name: string,
	start: () -> (),
}

local SerpentLabelController = {}

-- The recommended speed of the serpent that came out in `zone`, if it is one of its zones.
local function recommendedIn(zone: unknown): BigNum.BigNum?
	if type(zone) ~= "string" or not table.find(SerpentConfig.ZONES, zone :: ZoneConfig.ZoneId) then
		return nil
	end
	local post = GuardianConfig.POSTS[ZoneConfig.postIndex(zone :: ZoneConfig.ZoneId, SerpentConfig.POWER_POST)]
	return post and post.recommended
end

-- The sign is seen as far as the farthest guardian's: the serpent roams the outer zones.
local function maxDistance(): number
	local farthest = 0
	for _, distance in ZoneLooks.GUARDIAN_SIGN_DISTANCE do
		farthest = math.max(farthest, distance)
	end
	return farthest
end

function SerpentLabelController.new(dependencies: Dependencies): SerpentLabelController
	local function start()
		local locale = Text.localeOf(Players.LocalPlayer)
		local words: { [Speed.Challenge]: string } = {}
		for challenge, look in GuardianLooks.CHALLENGES do
			-- Checked at the config; through `any`, as the union of every key is too much here.
			local key: any = look.textKey
			words[challenge] = Text.get(locale, key)
		end

		local recommended = Vide.source(nil :: BigNum.BigNum?)
		local readRecommended = recommended :: () -> BigNum.BigNum?
		local events = ReplicatedStorage:WaitForChild(EventConfig.FOLDER_NAME, WORLD_WAIT_TIMEOUT)
		local folder = events and events:WaitForChild("Serpent", WORLD_WAIT_TIMEOUT)
		if folder then
			local function readZone()
				recommended(recommendedIn(folder:GetAttribute(EventConfig.ZONE_ATTRIBUTE)))
			end
			folder:GetAttributeChangedSignal(EventConfig.ZONE_ATTRIBUTE):Connect(readZone)
			readZone()
		else
			warn("[SerpentLabelController] No serpent event state; its sign has no pill")
		end

		local world = workspace:WaitForChild("World", WORLD_WAIT_TIMEOUT)
		if not world then
			warn("[SerpentLabelController] No world folder; no serpent sign")
			return
		end

		local head: BasePart? = nil
		local unmount: (() -> ())? = nil
		local labelPixels = Vide.source(nil :: number?)
		local readPixels = labelPixels :: () -> number?
		local labelFade = Vide.source(0)
		local signDistance = maxDistance()

		local function clear()
			if unmount then
				unmount()
			end
			head, unmount = nil, nil
		end

		local function follow(model: Instance)
			local part = model:WaitForChild(SerpentConfig.HEAD_NAME, WORLD_WAIT_TIMEOUT)
			if not part or not part:IsA("BasePart") or model.Parent == nil then
				return
			end
			clear()
			head = part
			unmount = Mount.instance(function()
				return GuardianLabel({
					adornee = part,
					name = Text.get(locale, "event.serpent.title"),
					challenge = function(): Speed.Challenge?
						local value = readRecommended()
						if not value then
							return nil
						end
						return Speed.challenge(
							dependencies.speed(),
							value,
							SpeedConfig.CHASE,
							SpeedConfig.CHALLENGE_WEAK_DECADES
						)
					end,
					words = words,
					pixelsPerStud = readPixels,
					fade = labelFade,
					studsAbove = part.Size.Y / 2 + LABEL.STUDS_ABOVE,
					maxDistance = signDistance,
				})
			end, part)
		end

		world.ChildAdded:Connect(function(child)
			if child.Name == SerpentConfig.MODEL_NAME then
				follow(child)
			end
		end)
		world.ChildRemoved:Connect(function(child)
			if child.Name == SerpentConfig.MODEL_NAME then
				clear()
			end
		end)
		local present = world:FindFirstChild(SerpentConfig.MODEL_NAME)
		if present then
			task.spawn(follow, present)
		end

		RunService.RenderStepped:Connect(function()
			local camera = workspace.CurrentCamera
			if not head or not camera then
				return
			end
			local distance = (head.Position - camera.CFrame.Position).Magnitude
			local pixels = GuardianPose.labelPixelsPerStud(
				distance,
				LABEL.NEAR_DISTANCE,
				LABEL.FAR_DISTANCE,
				camera.ViewportSize.Y,
				camera.FieldOfView
			)
			if pixels ~= readPixels() then
				labelPixels(pixels)
			end
			local fade = GuardianPose.labelFade(distance, LABEL.FADE_START, signDistance, LABEL.FADE_MAX)
			if math.abs(fade - labelFade()) > LABEL.FADE_STEP then
				labelFade(fade)
			end
		end)
	end

	return {
		name = "SerpentLabelController",
		start = start,
	}
end

return table.freeze(SerpentLabelController)
