--!strict
-- Jetpack look, flame effects, body lean and the flight animation.

local FlightLean = require("../Domain/FlightLean")

local LEAN: FlightLean.Tuning = {
	maxPitch = math.rad(30),
	maxRoll = math.rad(18),
}

return table.freeze({
	-- Uploaded flight animation (rbxassetid://...). Empty: Studio builds it from FlightPose on the
	-- fly; live servers need the uploaded asset (see CLAUDE.md, "Анимации").
	FLIGHT_ANIMATION_ID = "rbxassetid://138651289824053",
	-- Name of the Animation instance the server puts in each character.
	ANIMATION_INSTANCE_NAME = "JetpackFlightAnimation",
	ANIMATION_FADE_SECONDS = 0.25,

	LEAN = table.freeze(LEAN),

	-- Model
	MODEL_NAME = "Jetpack",
	BODY_COLOR = Color3.fromRGB(196, 202, 214),
	FRAME_COLOR = Color3.fromRGB(52, 56, 70),
	ACCENT_COLOR = Color3.fromRGB(90, 200, 255),
	GRIP_COLOR = Color3.fromRGB(40, 42, 52),
	BUTTON_COLOR = Color3.fromRGB(255, 70, 70),
	HOSE_COLOR = Color3.fromRGB(34, 36, 44),

	-- Flames (client-side visuals)
	FLAME_TEXTURE = "rbxasset://textures/particles/fire_main.dds",
	FLAME_COLOR_START = Color3.fromRGB(255, 236, 160),
	FLAME_COLOR_END = Color3.fromRGB(255, 96, 30),
	-- Particles per second per nozzle: idle hover and full thrust.
	FLAME_RATE_IDLE = 35,
	FLAME_RATE_FULL = 110,
	-- The engine stalls while a guardian's hit stuns the flyer, then restarts with a burst.
	FLAME_BURST_RATE = 400,
	FLAME_BURST_SECONDS = 0.3,
	FLAME_LIGHT_COLOR = Color3.fromRGB(255, 150, 70),
	FLAME_LIGHT_BRIGHTNESS = 2,
	FLAME_LIGHT_RANGE = 10,

	-- Names shared by the model builder and the effects controller.
	NOZZLE_ATTACHMENT_NAME = "NozzleExit",
	FLAME_NAME = "Flame",
	FLAME_LIGHT_NAME = "FlameLight",
})
