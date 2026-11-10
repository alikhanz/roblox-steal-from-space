--!strict
-- One feel for every button of the game (docs/design/screens/buttons.md). A finger on the button
-- presses it in at once (smaller, lighter); a press that goes through clicks: a short pop of size,
-- a flash of light and a soft click sound; a press on a disabled button wobbles it, so the player
-- sees the finger landed. The button reads the numbers here into its own look (a UIScale, its
-- glass, its Rotation): a button that sizes itself to its word does not shrink, it only lights.
--
-- The feel is about the finger, not the result: what a press bought or hatched is shown when the
-- server says so.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Sounds = require(script.Parent.Sounds)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

-- A pressed button's size and how far its glass goes towards white.
local PRESSED_SCALE = 0.94
local PRESSED_LIGHT = 0.3
-- The click: the size swells this much and back, and the light fades, in these times.
local POP_GROWTH = 0.06
local POP_SECONDS = 0.15
local FLASH_SECONDS = 0.2
-- A refused press: it turns this far each way, three times, fading out.
local WOBBLE_DEGREES = 4
local WOBBLE_SECONDS = 0.25
local WOBBLE_TURNS = 3

export type Options = {
	-- A disabled button wobbles instead of clicking; always enabled by default.
	enabled: (() -> boolean)?,
	-- Shrinks under the finger and pops on a click (a button whose size its row does not read).
	shrinks: boolean?,
	-- No click sound (a flight button: the ability has its own).
	silent: boolean?,
	-- False while a press would do nothing at all, not even be refused (an index cell with no
	-- reward): no feel then. Always by default.
	responds: (() -> boolean)?,
}

export type Press = {
	-- Put on the button (a Vide action): follows the finger, clicks, wobbles a refused press.
	action: any,
	pressed: () -> boolean,
	-- The size of what is seen: the press and the click's pop (1 at rest).
	scale: () -> number,
	-- How far towards white to light the glass, 0..1 (the press, then the click's flash).
	light: () -> number,
	-- Degrees to turn what is seen (a refused press).
	tilt: () -> number,
}

type Motion = {
	clock: Vide.Source<number>,
	ends: number,
}

-- Presses with a motion under way, stepped every frame while any is.
local moving: { [Motion]: boolean } = {}
local stepper: RBXScriptConnection? = nil

local function step()
	local now = os.clock()
	local any = false
	for motion in moving do
		motion.clock(now)
		if now >= motion.ends then
			moving[motion] = nil
		else
			any = true
		end
	end
	if not any and stepper then
		stepper:Disconnect()
		stepper = nil
	end
end

local function run(motion: Motion, seconds: number)
	motion.ends = math.max(motion.ends, os.clock() + seconds)
	moving[motion] = true
	if not stepper then
		stepper = RunService.RenderStepped:Connect(step)
	end
end

local Press = {}

function Press.new(options: Options?): Press
	local enabled = options and options.enabled
	local shrinks = options ~= nil and options.shrinks == true
	local silent = options ~= nil and options.silent == true
	local responds = options and options.responds
	local pressed = source(false)
	local motion: Motion = { clock = source(0), ends = 0 }
	local clickedAt = -math.huge
	local refusedAt = -math.huge

	local function since(at: number): number
		return motion.clock() - at
	end

	local function scale(): number
		local base = if shrinks and pressed() then PRESSED_SCALE else 1
		local u = since(clickedAt) / POP_SECONDS
		if not shrinks or u < 0 or u >= 1 or GuiService.ReducedMotionEnabled then
			return base
		end
		return base * (1 + POP_GROWTH * math.sin(math.pi * u))
	end

	local function light(): number
		local flash = 1 - since(clickedAt) / FLASH_SECONDS
		local lit = if flash > 0 and flash <= 1 then PRESSED_LIGHT * flash else 0
		return math.max(if pressed() then PRESSED_LIGHT else 0, lit)
	end

	local function tilt(): number
		local u = since(refusedAt) / WOBBLE_SECONDS
		if u < 0 or u >= 1 or GuiService.ReducedMotionEnabled then
			return 0
		end
		return WOBBLE_DEGREES * math.sin(u * WOBBLE_TURNS * 2 * math.pi) * (1 - u)
	end

	local action = Vide.action(function(instance)
		local button = instance :: GuiButton
		button:GetPropertyChangedSignal("GuiState"):Connect(function()
			pressed(button.GuiState == Enum.GuiState.Press and (responds == nil or responds()))
		end)
		button.Activated:Connect(function()
			if responds and not responds() then
				return
			end
			local now = os.clock()
			motion.clock(now)
			if enabled and not enabled() then
				refusedAt = now
				run(motion, WOBBLE_SECONDS)
				return
			end
			clickedAt = now
			run(motion, math.max(POP_SECONDS, FLASH_SECONDS))
			if not silent then
				Sounds.play("Click")
			end
		end)
	end)

	return {
		action = action,
		pressed = pressed,
		scale = scale,
		light = light,
		tilt = tilt,
	}
end

return table.freeze(Press)
