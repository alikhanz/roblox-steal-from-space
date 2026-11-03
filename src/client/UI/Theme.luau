--!strict
-- Shared look of the HUD. Placeholder palette until the art pass.

return table.freeze({
	PANEL = Color3.fromRGB(14, 18, 32),
	PANEL_TRANSPARENCY = 0.25,
	TEXT = Color3.fromRGB(235, 240, 255),
	OXYGEN = Color3.fromRGB(90, 200, 255),
	SPEED = Color3.fromRGB(255, 214, 90),
	COINS = Color3.fromRGB(255, 190, 60),
	-- Buttons that cost or pay coins.
	COINS_DARK = Color3.fromRGB(150, 105, 20),
	DANGER = Color3.fromRGB(255, 80, 80),
	-- Buttons and selection.
	ACCENT = Color3.fromRGB(50, 120, 220),
	-- Background of a selected card.
	SELECTED = Color3.fromRGB(34, 70, 130),
	-- Secondary text.
	MUTED = Color3.fromRGB(160, 168, 190),
	-- Toast backgrounds.
	TOAST_GOOD = Color3.fromRGB(40, 130, 80),
	TOAST_BAD = Color3.fromRGB(150, 50, 50),
	FONT = Font.fromEnum(Enum.Font.GothamBold),
	TEXT_SIZE = 18,
	CORNER = UDim.new(0, 12),
	-- Distance between HUD elements and the screen edge, pixels.
	MARGIN = 24,
})
