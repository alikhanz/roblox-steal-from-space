--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The tutorial on screen (decision 065): the line of what to do now (UI/TutorialPanel) and a
-- pin (UI/ScreenPin) on the thing to fly to: a nest of the guardian to steal from, the player's
-- own egg in the incubator, their trainer. The server decides the hint (TutorialService); the
-- client only finds the place to point at. Carrying an egg home needs no pin of its own: the
-- station beacon shows the way.

local CollectionService = game:GetService("CollectionService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local ScreenPin = require(script.Parent.Parent.UI.ScreenPin)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
local TutorialPanel = require(script.Parent.Parent.UI.TutorialPanel)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30

type Hint = Remotes.TutorialHint

-- The guardian each stealing hint points at.
local STEAL_GRADE: { [Hint]: number } = {
	Steal = 1,
	StealStronger = TutorialConfig.STRONGER_GRADE,
}

export type TutorialController = {
	name: string,
	start: () -> (),
}

local TutorialController = {}

function TutorialController.new(): TutorialController
	local locale: Text.Locale = "en"
	local hint = source(nil :: Hint?)
	local readHint = hint :: () -> Hint?
	-- The last line after finishing, shown for a while (empty: none).
	local farewell = source("")
	local pin = ScreenPin.new()
	local pinTitle = source("")

	local function lineFor(current: Hint?): string
		if current == "Steal" then
			return Text.get(locale, "tutorial.steal.hint")
		elseif current == "CarryHome" or current == "CarryHomeStronger" then
			return Text.get(locale, "tutorial.carryHome.hint")
		elseif current == "Hatch" then
			return Text.get(locale, "tutorial.hatch.hint")
		elseif current == "Train" then
			return Text.get(locale, "tutorial.train.hint", { speed = BigNum.format(TutorialConfig.TRAINING_TARGET) })
		elseif current == "StealStronger" then
			return Text.get(locale, "tutorial.stealStronger.hint")
		end
		return ""
	end

	local function ownBay(): Instance?
		for _, bay in CollectionService:GetTagged(BayConfig.TAG) do
			if bay:GetAttribute(BayConfig.OWNER_ID_ATTRIBUTE) == Players.LocalPlayer.UserId then
				return bay
			end
		end
		return nil
	end

	-- The nearest nest of guardian `grade` with an egg in it.
	local function nestOf(grade: number, from: Vector3): Vector3?
		local best: Vector3? = nil
		local bestDistance = math.huge
		for _, nest in CollectionService:GetTagged(EggConfig.NEST_TAG) do
			local position = nest:GetAttribute(EggConfig.NEST_EGG_POSITION_ATTRIBUTE)
			if
				nest:GetAttribute(EggConfig.NEST_GRADE_ATTRIBUTE) == grade
				and nest:GetAttribute(EggConfig.NEST_HAS_EGG_ATTRIBUTE) == true
				and typeof(position) == "Vector3"
			then
				local distance = (position - from).Magnitude
				if distance < bestDistance then
					best, bestDistance = position, distance
				end
			end
		end
		return best
	end

	-- The player's egg that is soonest ready in their incubator.
	local function ownEgg(bay: Instance): Vector3?
		local best: BasePart? = nil
		local soonest = math.huge
		for _, egg in CollectionService:GetTagged(BayConfig.INCUBATOR_EGG_TAG) do
			local hatchAt = egg:GetAttribute(BayConfig.EGG_HATCH_AT_ATTRIBUTE)
			if egg:IsA("BasePart") and egg:IsDescendantOf(bay) and type(hatchAt) == "number" and hatchAt < soonest then
				best, soonest = egg, hatchAt
			end
		end
		return if best then best.Position else nil
	end

	-- Where the pin goes for `current` and its title, or nil for no pin.
	local function target(current: Hint?, from: Vector3): (Vector3?, string)
		if not current then
			return nil, ""
		end
		local grade = STEAL_GRADE[current]
		if grade then
			-- The key union is too big for the solver here (as in GuardianViewController).
			local nameKey: any = GuardianConfig.POSTS[grade].nameKey
			return nestOf(grade, from), Text.get(locale, nameKey)
		end
		local bay = ownBay()
		if not bay then
			return nil, ""
		end
		if current == "Hatch" then
			return ownEgg(bay), Text.get(locale, "tutorial.egg.title")
		elseif current == "Train" then
			local trainer = bay:FindFirstChild(BayConfig.TRAINER_NAME)
			if trainer and trainer:IsA("BasePart") then
				return trainer.Position, Text.get(locale, "tutorial.trainer.title")
			end
		end
		return nil, ""
	end

	local function update()
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not camera or not root or not root:IsA("BasePart") then
			pin.hide()
			return
		end
		local point, title = target(readHint(), root.Position)
		if not point then
			pin.hide()
			return
		end
		if title ~= Vide.untrack(pinTitle) then
			pinTitle(title)
		end
		pin.place(camera, point, ScreenPin.distanceText(locale, (point - root.Position).Magnitude))
	end

	local function onHint(next: Hint)
		local previous = Vide.untrack(readHint)
		hint(next)
		-- Done right after another hint: the player has just finished. Done on joining: long ago.
		if next == "Done" and previous ~= nil and previous ~= "Done" then
			farewell(Text.get(locale, "tutorial.done.hint"))
			task.delay(TutorialConfig.DONE_HINT_SECONDS, function()
				farewell("")
			end)
		end
	end

	local function start()
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		Remotes.TutorialChanged.SetCallback(onHint)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		if not playerGui then
			warn("[TutorialController] PlayerGui did not appear; no tutorial")
			return
		end
		Vide.mount(function()
			return pin.view({ name = "TutorialPin", title = pinTitle, color = Theme.SPEED })
		end, playerGui)
		Vide.mount(function()
			return Vide.create("ScreenGui")({
				Name = "TutorialUi",
				ResetOnSpawn = false,
				TutorialPanel({
					text = function()
						local line = lineFor(readHint())
						return if line ~= "" then line else farewell()
					end,
				}),
			})
		end, playerGui)
		RunService.RenderStepped:Connect(update)
	end

	return {
		name = "TutorialController",
		start = start,
	}
end

return table.freeze(TutorialController)
