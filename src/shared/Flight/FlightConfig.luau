--!strict
-- Jetpack tuning. Spike values: tuned by feel during the Server Authority experiment.

return table.freeze({
	-- Top speed with full input, studs per second.
	MAX_SPEED = 48,
	-- How fast velocity approaches the input target (higher = snappier), per second.
	RESPONSE = 4,
	-- Fraction of drift velocity kept after one second without input: slow space glide.
	DRIFT_RETENTION_PER_SECOND = 0.6,
	-- Force budget for the velocity constraint; large enough to cancel gravity.
	MAX_FORCE = 1e6,
	-- Attribute names on the character (simulation state must live in attributes).
	FLYING_ATTRIBUTE = "JetpackFlying",
	TOGGLE_HELD_ATTRIBUTE = "JetpackToggleHeld",
	-- Instance names under HumanoidRootPart.
	ATTACHMENT_NAME = "JetpackAttachment",
	VELOCITY_NAME = "JetpackVelocity",
	ALIGN_NAME = "JetpackAlign",
})
