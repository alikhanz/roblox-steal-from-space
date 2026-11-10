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

	-- Model (decision 089): ServerStorage.<MODELS_FOLDER>.<TEMPLATE_PREFIX><jetpack> in the place,
	-- one per jetpack (JetpackLooks.jetpackOf), built for a torso TEMPLATE_TORSO_WIDTH wide whose
	-- back is TEMPLATE_BACK in front of its pivot; scaled to the character's. Without them the
	-- greybox stands in (colours per level in JetpackLooks).
	MODEL_NAME = "Jetpack",
	MODELS_FOLDER = "Jetpacks",
	TEMPLATE_PREFIX = "Jetpack",
	TEMPLATE_TORSO_WIDTH = 2,
	TEMPLATE_BACK = 0.5,
	-- Where the hoses meet the pack, on a template of scale 1 (torso frame: X right, Y up, Z back).
	TEMPLATE_HOSE_ANCHOR = Vector3.new(0.6, -0.35, 0.85),
	FRAME_COLOR = Color3.fromRGB(52, 56, 70),
	GRIP_COLOR = Color3.fromRGB(40, 42, 52),
	BUTTON_COLOR = Color3.fromRGB(255, 70, 70),
	HOSE_COLOR = Color3.fromRGB(34, 36, 44),

	-- Flames: beams each client adds itself (JetpackEffectsController; their look per jetpack in
	-- JetpackLooks). A flame leaves a nozzle's attachment along its −Y.
	FLAME = table.freeze({
		-- Share of the full flame hovering and in a burst; it changes in steps of `step`
		-- (Domain/JetFlame).
		idle = 0.4,
		burst = 1.4,
		step = 0.1,
	}),
	-- The engine stalls while a guardian's hit stuns the flyer, then restarts with a burst.
	FLAME_BURST_SECONDS = 0.3,
	-- The flame's detail by distance from the camera, studs: the core and the light near, the jet
	-- alone far (JetFlame.detail).
	FLAME_NEAR = 120,
	FLAME_FAR = 350,
	-- One light per jetpack, no shadows.
	FLAME_LIGHT_BRIGHTNESS = 1.5,
	FLAME_LIGHT_RANGE = 10,

	-- Names shared by the model builder and the effects controller.
	NOZZLE_ATTACHMENT_NAME = "NozzleExit",
	HOSE_ANCHOR_NAME = "HoseAnchor",
	-- On the jetpack model: which jetpack it is (JetpackLooks.jetpackOf). The server keeps the
	-- model for a new level of the same jetpack; the clients pick the flame by it.
	JETPACK_ATTRIBUTE = "Jetpack",
})
