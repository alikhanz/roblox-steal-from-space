--!strict
-- Markers of the other players and of loose eggs on the screen (docs/design/screens/markers.md):
-- where everyone is, who carries what, where a knocked-out egg floats — so there is someone to
-- hunt on a map this big. One pool of markers (UI/RadarMarker) under the HUD, filled every frame;
-- out of view they wait at the screen edge, clear of the HUD (UI/PinArea).
--
-- Players come from the Player's attributes (RadarService: position and egg in hand, twice a
-- second, for any player however far); a character streamed in gives its own position, smoother.
-- Nobody under a dome is marked: there is no PvP there. Loose eggs come from their parts.
--
-- Someone else grabbing an epic or legendary egg is told with a toast (Radar.announcement).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local PinArea = require(script.Parent.Parent.UI.PinArea)
local PvpConfig = require(ReplicatedStorage.Shared.Config.PvpConfig)
local Radar = require(ReplicatedStorage.Shared.Domain.Radar)
local RadarConfig = require(ReplicatedStorage.Shared.Config.RadarConfig)
local RadarMarker = require(script.Parent.Parent.UI.RadarMarker)
local ScreenMarker = require(ReplicatedStorage.Shared.Domain.ScreenMarker)
local ScreenPin = require(script.Parent.Parent.UI.ScreenPin)
local ServerConfig = require(ReplicatedStorage.Shared.Config.ServerConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Zones = require(ReplicatedStorage.Shared.Domain.Zones)

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- A player's marker floats this far over their character's root, studs: over the head.
local STUDS_OVER_ROOT = 5
-- Under the HUD (whose ScreenGui keeps the default order) and the windows' veil.
local DISPLAY_ORDER = -1

export type Dependencies = {
	toast: (text: string, kind: Toasts.Kind, alienId: string?) -> (),
}

export type RadarController = {
	name: string,
	start: () -> (),
}

local RadarController = {}

local function rarityOf(value: unknown): string?
	return if type(value) == "string" then value else nil
end

local function colorOf(rarity: string?): Color3
	local look = if rarity then (EggLooks.RARITIES :: any)[rarity] else nil
	return if look then look.color else Theme.NEON.TEXT
end

function RadarController.new(dependencies: Dependencies): RadarController
	local playerSlots: { RadarMarker.Marker } = {}
	local looseSlots: { RadarMarker.Marker } = {}
	for _ = 1, ServerConfig.MAX_PLAYERS - 1 do
		table.insert(playerSlots, RadarMarker.new())
	end
	for _ = 1, RadarConfig.LOOSE_CAP do
		table.insert(looseSlots, RadarMarker.new())
	end
	local others: { Player } = {}
	local looseEggs: { [BasePart]: true } = {}
	local locale: Text.Locale = "en"

	-- Where `player` is: their streamed-in character, else the position the server publishes.
	local function positionOf(player: Player): Vector3?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and root:IsDescendantOf(workspace) then
			return root.Position
		end
		local published = player:GetAttribute(RadarConfig.POSITION_ATTRIBUTE)
		return if typeof(published) == "Vector3" then published else nil
	end

	type Shown = {
		state: RadarMarker.State,
		slot: RadarMarker.Marker,
	}

	-- The marker for world `point` this frame, or nil when it stays hidden.
	local function locate(
		camera: Camera,
		area: ScreenMarker.Area,
		point: Vector3,
		scale: number,
		kind: RadarMarker.Kind,
		allowEdge: boolean
	): (Vector2?, Vector2?, number)
		local location = ScreenPin.locate(camera, point, area)
		local arrow = location.arrow
		if not arrow then
			-- ScreenPin lifts its sign over the point; markers sit on it.
			local viewportPoint = camera:WorldToViewportPoint(point)
			return Vector2.new(viewportPoint.X, viewportPoint.Y), nil, location.angle
		end
		if not allowEdge then
			return nil, nil, 0
		end
		return RadarMarker.edgeBody(kind, arrow, location.angle, scale), arrow, location.angle
	end

	local function update()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local here = if root and root:IsA("BasePart") then root.Position else camera.CFrame.Position
		local area = PinArea.of(camera)
		local scale = math.clamp(camera.ViewportSize.Y / Theme.NEON.REFERENCE_HEIGHT, 1, Theme.NEON.MAX_SCALE)
		local shown: { Shown } = {}

		local playerIndex = 0
		for _, player in others do
			local position = positionOf(player)
			if not position or Zones.stationAt(position, StationConfig.STATIONS) then
				continue
			end
			local rarity = rarityOf(player:GetAttribute(RadarConfig.EGG_ATTRIBUTE))
			local kind = Radar.kindOf(rarity)
			local distance = (position - here).Magnitude
			if not Radar.isFarEnough(kind, distance) then
				continue
			end
			local body, arrow, angle =
				locate(camera, area, position + Vector3.yAxis * STUDS_OVER_ROOT, scale, kind, true)
			if not body then
				continue
			end
			playerIndex += 1
			local newbie = player:GetAttribute(PvpConfig.NEWBIE_ATTRIBUTE)
			local state: RadarMarker.State = {
				kind = kind,
				title = RadarMarker.shortName(player.DisplayName),
				distance = ScreenPin.distanceText(locale, distance),
				color = colorOf(rarity),
				transparency = Radar.fade(kind, distance),
				isNewbie = type(newbie) == "number" and newbie > 0,
				timeLeft = 1,
				body = body,
				arrow = arrow,
				angle = angle,
				scale = scale,
			}
			table.insert(shown, { slot = playerSlots[playerIndex], state = state })
			if playerIndex == #playerSlots then
				break
			end
		end
		for index = playerIndex + 1, #playerSlots do
			playerSlots[index].hide()
		end

		local candidates: { Radar.Loose } = {}
		local parts: { [string]: BasePart } = {}
		for part in looseEggs do
			local rarity = rarityOf(part:GetAttribute(EggConfig.LOOSE_EGG_RARITY_ATTRIBUTE))
			if rarity and part:IsDescendantOf(workspace) then
				parts[part.Name] = part
				table.insert(candidates, {
					id = part.Name,
					rarity = rarity,
					distance = (part.Position - here).Magnitude,
					isOwn = part:GetAttribute(EggConfig.LOOSE_EGG_DROPPED_BY_ATTRIBUTE) == Players.LocalPlayer.UserId,
				})
			end
		end
		local looseIndex = 0
		local now = workspace:GetServerTimeNow()
		for _, egg in Radar.pickLoose(candidates) do
			local part = parts[egg.id]
			local body, arrow, angle = locate(camera, area, part.Position, scale, "Loose", Radar.isLooseOnEdge(egg))
			if not body then
				continue
			end
			looseIndex += 1
			local droppedAt = part:GetAttribute(EggConfig.LOOSE_EGG_DROPPED_AT_ATTRIBUTE)
			local state: RadarMarker.State = {
				kind = "Loose",
				title = "",
				distance = ScreenPin.distanceText(locale, egg.distance),
				color = colorOf(egg.rarity),
				transparency = 0,
				isNewbie = false,
				timeLeft = if type(droppedAt) == "number" then Radar.timeLeft(droppedAt, now) else 1,
				body = body,
				arrow = arrow,
				angle = angle,
				scale = scale,
			}
			table.insert(shown, { slot = looseSlots[looseIndex], state = state })
		end
		for index = looseIndex + 1, #looseSlots do
			looseSlots[index].hide()
		end

		-- Labels at the edge step apart, so two in one direction do not cover each other.
		local edgeLabels: { Shown } = {}
		local points: { ScreenMarker.Point } = {}
		for _, item in shown do
			if item.state.arrow and item.state.kind ~= "Player" then
				table.insert(edgeLabels, item)
				table.insert(points, { x = item.state.body.X, y = item.state.body.Y })
			end
		end
		if #edgeLabels > 1 then
			local size = RadarMarker.edgeSize("HotThief", scale)
			local apart = ScreenMarker.separate(points, size.X, size.Y, ScreenPin.screenOf(camera))
			for index, item in edgeLabels do
				item.state.body = Vector2.new(apart[index].x, apart[index].y)
			end
		end
		for _, item in shown do
			item.slot.show(item.state)
		end
	end

	-- Tells everyone when another player picks up an egg worth hunting; the value they joined
	-- with is no news.
	local function watch(player: Player)
		if player == Players.LocalPlayer then
			return
		end
		table.insert(others, player)
		local carried = rarityOf(player:GetAttribute(RadarConfig.EGG_ATTRIBUTE))
		player:GetAttributeChangedSignal(RadarConfig.EGG_ATTRIBUTE):Connect(function()
			local now = rarityOf(player:GetAttribute(RadarConfig.EGG_ATTRIBUTE))
			local key = Radar.announcement(carried, now)
			carried = now
			if key then
				dependencies.toast(Text.get(locale, key :: any, { name = player.DisplayName }), "Egg")
			end
		end)
	end

	local function start()
		locale = Text.localeOf(Players.LocalPlayer)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		if not playerGui then
			warn("[RadarController] PlayerGui did not appear; no markers")
			return
		end
		Vide.mount(function()
			local children: { Instance } = {}
			for index, slot in playerSlots do
				table.insert(children, slot.view(index))
			end
			for index, slot in looseSlots do
				table.insert(children, slot.view(#playerSlots + index))
			end
			local gui = Vide.create("ScreenGui")({
				Name = "Radar",
				ResetOnSpawn = false,
				-- Viewport coordinates from the camera start at the very top of the screen.
				IgnoreGuiInset = true,
				DisplayOrder = DISPLAY_ORDER,
			})
			for _, child in children do
				child.Parent = gui
			end
			return gui
		end, playerGui)

		Players.PlayerAdded:Connect(watch)
		Players.PlayerRemoving:Connect(function(player)
			local index = table.find(others, player)
			if index then
				table.remove(others, index)
			end
		end)
		for _, player in Players:GetPlayers() do
			watch(player)
		end

		CollectionService:GetInstanceAddedSignal(EggConfig.LOOSE_EGG_TAG):Connect(function(egg)
			if egg:IsA("BasePart") then
				looseEggs[egg] = true
			end
		end)
		CollectionService:GetInstanceRemovedSignal(EggConfig.LOOSE_EGG_TAG):Connect(function(egg)
			looseEggs[egg :: BasePart] = nil
		end)
		for _, egg in CollectionService:GetTagged(EggConfig.LOOSE_EGG_TAG) do
			if egg:IsA("BasePart") then
				looseEggs[egg] = true
			end
		end

		RunService.RenderStepped:Connect(update)
	end

	return {
		name = "RadarController",
		start = start,
	}
end

return table.freeze(RadarController)
