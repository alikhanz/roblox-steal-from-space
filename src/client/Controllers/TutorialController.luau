--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The tutorial on screen (decision 065, docs/design/screens/tutorial-arrows.md): the line of
-- what to do now with the step's dots and icon (`line`, `step`, `icon`, which the HUD shows in
-- its bottom stack with UI/TutorialPanel), a pin (UI/ScreenPin) on the thing to fly to, and in
-- the world a path of chevrons to it with the thing lit (UI/GuidePath): a nest of the guardian
-- to steal from, the player's own bay while carrying an egg home, their egg in the incubator,
-- their trainer. The server decides the hint (TutorialService); the client only finds the place
-- to point at. After the tutorial the same panel, pin and path carry the hints of the coach
-- (decision 106, CoachState): to the places' terminal, to the station's kiosks, or a button that
-- opens the bay window; the farewell line points at the station.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local CoachState = require(script.Parent.Parent.State.CoachState)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local GrabState = require(script.Parent.Parent.State.GrabState)
local GuardianConfig = require(ReplicatedStorage.Shared.Config.GuardianConfig)
local GuidePath = require(script.Parent.Parent.UI.GuidePath)
local Icons = require(script.Parent.Parent.UI.Icons)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local ScreenPin = require(script.Parent.Parent.UI.ScreenPin)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local StationLooks = require(ReplicatedStorage.Shared.Config.StationLooks)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Tutorial = require(ReplicatedStorage.Shared.Domain.Tutorial)
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

-- Each hint's icon in the panel.
local HINT_ICONS: { [Hint]: Icons.Name } = {
	Steal = "Egg",
	CarryHome = "Home",
	Hatch = "Bay",
	Train = "Bolt",
	StealStronger = "Egg",
	CarryHomeStronger = "Home",
}

type Tip = CoachState.Tip

-- Each coach hint's line and icon.
local TIP_LINES: { [Tip]: Text.Key } = {
	Shelf = "coach.shelf.hint",
	Jetpack = "coach.jetpack.hint",
	Quest = "coach.quest.hint",
	Crossbreed = "coach.crossbreed.hint",
	Sell = "coach.sell.hint",
}
local TIP_ICONS: { [Tip]: Icons.Name } = {
	Shelf = "Bay",
	Jetpack = "Jetpack",
	Quest = "Quests",
	Crossbreed = "Bay",
	Sell = "Bay",
}
-- The station kiosk a hint leads to.
local TIP_KIOSKS: { [Tip]: StationLooks.KioskId } = {
	Jetpack = "Jetpacks",
	Quest = "Quests",
}

export type Dependencies = {
	-- The player's speed stat: a dropped egg leads back only if its guardian is outrun.
	speed: () -> BigNum.BigNum,
	-- The grab button: next to an egg the stealing line says to press it.
	grab: GrabState.GrabState,
	-- The hint after the tutorial, and the bay window it may open.
	coach: CoachState.CoachState,
	openBay: () -> (),
	openBayWithTrio: () -> (),
}

export type TutorialController = {
	name: string,
	start: () -> (),
	-- The line of what to do now; empty: none (reactive).
	line: () -> string,
	-- The step of the hint, 1..Tutorial.STEP_COUNT; nil for none, and for the farewell line.
	step: () -> number?,
	icon: () -> Icons.Name?,
	-- A button after the line (a coach hint's); nil: none (reactive).
	action: () -> TutorialPanel.Action?,
	-- True while its pin leads to the player's island (carrying an egg home).
	pointsHome: () -> boolean,
	-- True once the tutorial is over (not reactive).
	isDone: () -> boolean,
	-- The same, reactive.
	done: () -> boolean,
	-- The player has just finished the tutorial (its farewell line is gone), not on joining.
	finished: Signal.Signal<>,
}

local TutorialController = {}

function TutorialController.new(dependencies: Dependencies): TutorialController
	local locale: Text.Locale = "en"
	local hint = source(nil :: Hint?)
	local readHint = hint :: () -> Hint?
	-- The last line after finishing, shown for a while (empty: none).
	local farewell = source("")
	local finished = Signal.new() :: Signal.Signal<>
	local pin = ScreenPin.new()
	local pinTitle = source("")
	local path: GuidePath.GuidePath? = nil

	local function lineFor(current: Hint?): string
		-- At an egg, the next thing to do is the grab button (docs/design/screens/grab-button.md).
		if (current == "Steal" or current == "StealStronger") and dependencies.grab.target() ~= nil then
			return Text.get(locale, "tutorial.grabButton.hint")
		end
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

	-- The coach's hint while the tutorial says nothing (it is over and its farewell is gone).
	local function readTip(): Tip?
		local current = readHint()
		if (current ~= nil and current ~= "Done") or farewell() ~= "" then
			return nil
		end
		return dependencies.coach.tip()
	end

	local function ownBay(): Instance?
		for _, bay in CollectionService:GetTagged(BayConfig.TAG) do
			if bay:GetAttribute(BayConfig.OWNER_ID_ATTRIBUTE) == Players.LocalPlayer.UserId then
				return bay
			end
		end
		return nil
	end

	-- The nearest nest of guardian `grade` with an egg in it: where its egg lies, and the nest.
	local function nestOf(grade: number, from: Vector3): (Vector3?, Instance?)
		local best: Vector3? = nil
		local bestNest: Instance? = nil
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
					best, bestNest, bestDistance = position, nest, distance
				end
			end
		end
		return best, bestNest
	end

	-- The egg this player dropped (knocked out, out of oxygen), if the stealing step of
	-- `stepGrade` should lead back to it: its guardian counts for the step and is one the player
	-- outruns (Tutorial.backToDropped). The nearest of such eggs, and its guardian's grade.
	local function droppedEgg(stepGrade: number, from: Vector3): (BasePart?, number?)
		local best: BasePart? = nil
		local bestGrade: number? = nil
		local bestDistance = math.huge
		local speed = dependencies.speed()
		for _, egg in CollectionService:GetTagged(EggConfig.LOOSE_EGG_TAG) do
			local grade = egg:GetAttribute(EggConfig.LOOSE_EGG_GRADE_ATTRIBUTE)
			local post = if type(grade) == "number" then GuardianConfig.POSTS[grade] else nil
			if
				egg:IsA("BasePart")
				and egg:GetAttribute(EggConfig.LOOSE_EGG_DROPPED_BY_ATTRIBUTE) == Players.LocalPlayer.UserId
				and post
				and Tutorial.backToDropped(grade :: number, stepGrade, speed, post.recommended)
			then
				local distance = (egg.Position - from).Magnitude
				if distance < bestDistance then
					best, bestGrade, bestDistance = egg, grade :: number, distance
				end
			end
		end
		return best, bestGrade
	end

	-- The player's egg that is soonest ready in their incubator.
	local function ownEgg(bay: Instance): BasePart?
		local best: BasePart? = nil
		local soonest = math.huge
		for _, egg in CollectionService:GetTagged(BayConfig.INCUBATOR_EGG_TAG) do
			local hatchAt = egg:GetAttribute(BayConfig.EGG_HATCH_AT_ATTRIBUTE)
			if egg:IsA("BasePart") and egg:IsDescendantOf(bay) and type(hatchAt) == "number" and hatchAt < soonest then
				best, soonest = egg, hatchAt
			end
		end
		return best
	end

	-- A part of the player's bay by name, as a place to point at.
	local function bayPart(bay: Instance, name: string): (Vector3?, Instance?)
		local part = bay:FindFirstChild(name)
		if not part then
			return nil, nil
		elseif part:IsA("BasePart") then
			return part.Position, part
		elseif part:IsA("Model") then
			return part:GetPivot().Position, part
		end
		return nil, nil
	end

	-- The station kiosk `id`: where it stands, and its model.
	local function kiosk(id: StationLooks.KioskId): (Vector3?, Instance?)
		for _, model in CollectionService:GetTagged(StationLooks.KIOSK_TAG) do
			if model:GetAttribute(StationLooks.KIOSK_ATTRIBUTE) == id and model:IsA("Model") then
				return model:GetPivot().Position, model
			end
		end
		return nil, nil
	end

	-- The middle of the station: the kiosks stand round it.
	local function station(): Vector3?
		local sum = Vector3.zero
		local count = 0
		for _, model in CollectionService:GetTagged(StationLooks.KIOSK_TAG) do
			if model:IsA("Model") then
				sum += model:GetPivot().Position
				count += 1
			end
		end
		return if count > 0 then sum / count else nil
	end

	-- Where a coach hint leads: the places' terminal or a kiosk; nil for the hints done in the bay
	-- window (their button opens it).
	local function tipTarget(tip: Tip): (Vector3?, string, Instance?)
		local kioskId = TIP_KIOSKS[tip]
		if kioskId then
			local point, model = kiosk(kioskId)
			local key: Text.Key = if kioskId == "Jetpacks" then "kiosk.jetpacks.title" else "kiosk.quests.title"
			return point, Text.get(locale, key), model
		elseif tip == "Shelf" then
			local bay = ownBay()
			if bay then
				local point, terminal = bayPart(bay, BayConfig.PLACES_TERMINAL_NAME)
				return point, Text.get(locale, "terminal.places.title"), terminal
			end
		end
		return nil, "", nil
	end

	-- Where the pin and the path go for `current`, the pin's title and the thing to light; no
	-- place: none of them.
	local function target(current: Hint?, from: Vector3): (Vector3?, string, Instance?)
		local tip = readTip()
		if tip then
			return tipTarget(tip)
		end
		-- The farewell points at the station: its kiosks are what comes next.
		if current == "Done" and farewell() ~= "" then
			return station(), Text.get(locale, "tutorial.station.title"), nil
		end
		if not current then
			return nil, "", nil
		end
		local grade = STEAL_GRADE[current]
		if grade then
			-- The key union is too big for the solver here (as in GuardianViewController).
			local dropped, droppedGrade = droppedEgg(grade, from)
			if dropped and droppedGrade then
				local droppedKey: any = GuardianConfig.POSTS[droppedGrade].nameKey
				return dropped.Position, Text.get(locale, droppedKey), dropped
			end
			local nameKey: any = GuardianConfig.POSTS[grade].nameKey
			local point, nest = nestOf(grade, from)
			return point, Text.get(locale, nameKey), nest
		end
		local bay = ownBay()
		if not bay then
			return nil, "", nil
		end
		if current == "CarryHome" or current == "CarryHomeStronger" then
			local point, incubator = bayPart(bay, BayConfig.INCUBATOR_NAME)
			return point, Text.get(locale, "tutorial.bay.title"), incubator
		elseif current == "Hatch" then
			local egg = ownEgg(bay)
			if egg then
				return egg.Position, Text.get(locale, "tutorial.egg.title"), egg
			end
		elseif current == "Train" then
			local point, trainer = bayPart(bay, BayConfig.STAND_NAME)
			return point, Text.get(locale, "tutorial.trainer.title"), trainer
		end
		return nil, "", nil
	end

	local function update()
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local guide = path
		if not camera or not root or not root:IsA("BasePart") then
			pin.hide()
			if guide then
				guide.hide()
			end
			return
		end
		local point, title, thing = target(readHint(), root.Position)
		if not point then
			pin.hide()
			if guide then
				guide.hide()
			end
			return
		end
		-- Over a guardian's egg in view, its own sign already names it: the pin keeps only the
		-- distance. Off screen, at the edge, the name says where the arrow leads.
		local location = ScreenPin.locate(camera, point)
		local current = readHint()
		local named = location.arrow ~= nil or not (current and STEAL_GRADE[current]) or readTip() ~= nil
		local shownTitle = if named then title else ""
		if shownTitle ~= Vide.untrack(pinTitle) then
			pinTitle(shownTitle)
		end
		pin.show(location, ScreenPin.distanceText(locale, (point - root.Position).Magnitude))
		if guide then
			guide.show(root.Position, point, thing)
		end
	end

	local function onHint(next: Hint)
		local previous = Vide.untrack(readHint)
		hint(next)
		-- Done right after another hint: the player has just finished. Done on joining: long ago.
		if next == "Done" and previous ~= nil and previous ~= "Done" then
			farewell(Text.get(locale, "tutorial.done.hint"))
			task.delay(TutorialConfig.DONE_HINT_SECONDS, function()
				farewell("")
				finished.fire()
			end)
		end
	end

	local function start()
		locale = Text.localeOf(Players.LocalPlayer)
		Remotes.TutorialChanged.SetCallback(onHint)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		if not playerGui then
			warn("[TutorialController] PlayerGui did not appear; no tutorial")
			return
		end
		Vide.mount(function()
			return pin.view({ name = "TutorialPin", title = pinTitle, color = Theme.NEON.FLIGHT.Vertical })
		end, playerGui)
		path = GuidePath.new()
		RunService.RenderStepped:Connect(update)
	end

	return {
		name = "TutorialController",
		start = start,
		-- The line the HUD shows in its bottom stack (UI/TutorialPanel); empty: none.
		line = function(): string
			local line = lineFor(readHint())
			if line ~= "" then
				return line
			end
			local tip = readTip()
			if tip then
				return Text.get(locale, TIP_LINES[tip])
			end
			return farewell()
		end,
		step = function(): number?
			local current = readHint()
			return if current then Tutorial.stepOf(current) else nil
		end,
		icon = function(): Icons.Name?
			local current = readHint()
			local icon = if current then HINT_ICONS[current] else nil
			if icon then
				return icon
			end
			local tip = readTip()
			return if tip then TIP_ICONS[tip] else nil
		end,
		action = function(): TutorialPanel.Action?
			local tip = readTip()
			if tip == "Crossbreed" then
				return { text = Text.get(locale, "coach.crossbreed.button"), onPress = dependencies.openBayWithTrio }
			elseif tip == "Sell" then
				return { text = Text.get(locale, "coach.bay.button"), onPress = dependencies.openBay }
			end
			return nil
		end,
		pointsHome = function(): boolean
			local current = Vide.untrack(readHint)
			return current == "CarryHome" or current == "CarryHomeStronger"
		end,
		isDone = function(): boolean
			return Vide.untrack(readHint) == "Done"
		end,
		done = function(): boolean
			return readHint() == "Done"
		end,
		finished = finished,
	}
end

return table.freeze(TutorialController)
