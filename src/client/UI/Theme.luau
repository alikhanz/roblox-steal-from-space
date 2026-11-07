--!strict
-- Shared look of the UI. `NEON` holds the approved style (docs/design/DESIGN.md); the flat
-- tokens above it are the greybox palette the windows keep until each gets its own brief.

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

-- The neon glass style, token for token as in DESIGN.md ("Цвета", "Размеры и отступы").
local NEON = table.freeze({
	-- Glass of plaques, tiles and hints, and how see-through it is.
	GLASS = hex("#0A0E28"),
	GLASS_TRANSPARENCY = 0.5,
	TEXT = hex("#EAF2FF"),
	MUTED = hex("#9DB6D2"),
	LINE = hex("#82ECFF"),
	LINE_TRANSPARENCY = 0.5,
	SELECTED = hex("#E070C6"),
	DANGER = hex("#FF5A64"),
	-- Resources.
	SPEED = hex("#FFD34A"),
	COINS = hex("#FFC83D"),
	OXYGEN = hex("#5FD4FF"),
	-- Newbie protection and the egg in hand.
	SHIELD = hex("#8FF0A0"),
	EGG = hex("#FFE0A8"),
	-- Menu tiles.
	TILE = table.freeze({
		Bay = hex("#3EA6FF"),
		Store = hex("#41C95A"),
		Quests = hex("#FF9A2E"),
		Index = hex("#A06BFF"),
		Gift = hex("#FF5A9E"),
	}),
	-- Flight buttons.
	FLIGHT = table.freeze({
		Strike = hex("#FF7A3D"),
		Harpoon = hex("#3FD9FF"),
		Bomb = hex("#B57BFF"),
		Vertical = hex("#8FF4FF"),
		SlowMode = hex("#5BDB6E"),
	}),
	-- Action buttons, by what the press does.
	ACTION = table.freeze({
		Main = hex("#43CC5F"),
		Coins = hex("#FFBB2E"),
		Robux = hex("#2BD69A"),
		Move = hex("#3EA6FF"),
		Sell = hex("#FF5A64"),
		Crossbreed = hex("#A46BFF"),
	}),
	-- A coloured element: its fill fades from `FILL_TOP` to `FILL_BOTTOM` transparency (denser
	-- for action buttons), its outline is its colour mixed towards the glass by `LINE_DARKEN`.
	FILL_TOP = 0.8,
	FILL_BOTTOM = 0.94,
	DENSE_FILL_TOP = 0.64,
	DENSE_FILL_BOTTOM = 0.84,
	LINE_DARKEN = 0.22,
	LINE_THICKNESS = 2,
	-- Icons are the element's colour lifted towards white by this much.
	ICON_LIGHTEN = 0.3,
	-- The dark outline under text on glass.
	TEXT_STROKE_TRANSPARENCY = 0.5,
	FONT = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy),
	-- Type scale, points of the reference screen.
	TEXT_WINDOW_TITLE = 22,
	TEXT_RESOURCE = 20,
	TEXT_HINT = 16,
	TEXT_SECTION = 15,
	TEXT_BODY = 13,
	TEXT_SMALL = 11,
	-- Spacing, corners and touch sizes, points of the reference screen.
	EDGE = 16,
	GAP = 8,
	CORNER = UDim.new(0, 11),
	WINDOW_CORNER = UDim.new(0, 15),
	TILE_SIZE = 46,
	-- The reference screen is a phone held sideways, 390 points tall; larger screens scale the
	-- UI up by their height, up to `MAX_SCALE`.
	REFERENCE_HEIGHT = 390,
	MAX_SCALE = 1.6,
})

return table.freeze({
	NEON = NEON,

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
	-- The whole game speaks in the style's font already; the greybox windows use it too.
	FONT = NEON.FONT,
	TEXT_SIZE = 18,
	CORNER = UDim.new(0, 12),
	-- Distance between HUD elements and the screen edge, pixels.
	MARGIN = 24,
})
