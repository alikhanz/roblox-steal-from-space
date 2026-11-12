--!strict
-- The target mark (brief docs/design/screens/pvp-abilities.md, "Прицел и доводка"; decision 106):
-- four corners round whom the aim assist would send the local player's harpoon (its colour) or,
-- while the harpoon cools down or has nobody, their gravity bomb (its colour). On a phone the
-- assist pulls towards a target the player may not pick out among guardians and rocks; the mark
-- shows which. One mark at a time, a BillboardGui on the target's root part, drawn over all.
-- It also tells the server whom the harpoon lock is on (HarpoonLock, as it changes): the shot goes
-- for that one, as the player saw it (PvpService).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AbilityState = require(script.Parent.Parent.State.AbilityState)
local AimTargets = require(script.Parent.Parent.World.AimTargets)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)

local SIZE = 56
local ARM = 14
local THICKNESS = 3
local OUTLINE = Color3.new(0, 0, 0)
local OUTLINE_TRANSPARENCY = 0.4
-- A new target: the corners close in from this much larger.
local POP_SCALE = 1.3
local POP_SECONDS = 0.15

export type Dependencies = {
	abilities: AbilityState.AbilityState,
}

export type AimMarkController = {
	name: string,
	start: () -> (),
}

local AimMarkController = {}

local function bar(parent: Instance, anchor: Vector2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = anchor
	frame.Position = UDim2.fromScale(anchor.X, anchor.Y)
	frame.Size = size
	frame.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Transparency = OUTLINE_TRANSPARENCY
	stroke.Thickness = 1
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

local function build(): (BillboardGui, Frame, { Frame })
	local gui = Instance.new("BillboardGui")
	gui.Name = "AimMark"
	gui.AlwaysOnTop = true
	gui.ResetOnSpawn = false
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(SIZE, SIZE)
	gui.Enabled = false
	local box = Instance.new("Frame")
	box.Name = "Corners"
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundTransparency = 1
	box.Parent = gui
	local bars: { Frame } = {}
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		table.insert(bars, bar(box, corner, UDim2.fromOffset(ARM, THICKNESS)))
		table.insert(bars, bar(box, corner, UDim2.fromOffset(THICKNESS, ARM)))
	end
	return gui, box, bars
end

function AimMarkController.new(dependencies: Dependencies): AimMarkController
	local function start()
		local player = Players.LocalPlayer
		local gui, box, bars = build()
		gui.Parent = player:WaitForChild("PlayerGui")
		local shown: BasePart? = nil
		local shownColor: Color3? = nil

		local function show(target: BasePart?, color: Color3)
			if target == shown and (not target or color == shownColor) then
				return
			end
			shown, shownColor = target, color
			gui.Enabled = target ~= nil
			if not target then
				return
			end
			gui.Adornee = target
			for _, frame in bars do
				frame.BackgroundColor3 = color
			end
			if GuiService.ReducedMotionEnabled then
				box.Size = UDim2.fromScale(1, 1)
				return
			end
			box.Size = UDim2.fromScale(POP_SCALE, POP_SCALE)
			TweenService:Create(box, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(1, 1),
			}):Play()
		end

		local sentLock: BasePart? = nil
		local function sendLock(target: BasePart?)
			if target ~= sentLock then
				sentLock = target
				Remotes.HarpoonLock.Fire({ target = target })
			end
		end

		RunService.RenderStepped:Connect(function()
			local character = player.Character
			-- PvP is out in space only (not under a dome, flying or not).
			if not character or character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) ~= true then
				sendLock(nil)
				show(nil, Theme.NEON.FLIGHT.Harpoon)
				return
			end
			local abilities = dependencies.abilities
			local locked = AimTargets.harpoon(player)
			sendLock(locked)
			local harpoon = if abilities.isCooling("Harpoon") then nil else locked
			if harpoon then
				show(harpoon, Theme.NEON.FLIGHT.Harpoon)
				return
			end
			local bomb = if abilities.isCooling("Bomb") then nil else AimTargets.bomb(player)
			show(bomb, Theme.NEON.FLIGHT.Bomb)
		end)
	end

	return {
		name = "AimMarkController",
		start = start,
	}
end

return table.freeze(AimMarkController)
