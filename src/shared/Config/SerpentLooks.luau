--!strict
-- How the star serpent looks (decision 093). The server keeps a greybox head (World/SerpentModel:
-- a block with eyes and a light) that moves and is hit; every client dresses it in the serpent's
-- kit of meshes from Blender (World/SerpentVisual, ReplicatedStorage.SerpentKit) and draws its
-- body down the path the head flies (Domain/SerpentBody). Without the kit in the place the
-- clients draw the greybox body of balls (BODY's colours).

local rgb = Color3.fromRGB

return table.freeze({
	HEAD = table.freeze({
		size = Vector3.new(10, 8, 14),
		color = rgb(70, 50, 160),
		eyeColor = rgb(255, 240, 120),
		eyeSize = Vector3.new(1.6, 1.6, 0.6),
		glowColor = rgb(150, 120, 255),
		glowRange = 40,
		glowBrightness = 3,
	}),
	BODY = table.freeze({
		segments = 18,
		-- Distance between segment centers along the path, studs.
		spacing = 6,
		-- The first segment's size and the last one's; the ones between taper evenly.
		firstSize = 9,
		lastSize = 3,
		-- The greybox body's colours (no kit in the place).
		colors = table.freeze({ rgb(70, 50, 160), rgb(110, 80, 220) }),
		-- Glowing specks on every few segments: the stars it is named after. In the kit's look
		-- these segments wear two more stars on their flanks.
		starEvery = 3,
		starColor = rgb(255, 250, 200),
	}),
	-- The kit's look (assets/blender/serpent/serpent_kit.py; World/SerpentVisual).
	MODEL = table.freeze({
		FOLDER_NAME = "SerpentKit",
		-- The size the kit's segment was made at: a segment of `size` is its copy times size / this.
		SEGMENT_SIZE = 9,
		-- A thinner segment is barely shorter: its length is this share at the least, so
		-- that the tail's segments, still `spacing` apart, close up into one body.
		LENGTH_FLOOR = 0.9,
		-- The drawn head turns after the server's head with this time constant, seconds: a sharp
		-- turn reads as a bend, not a jerk.
		TURN_SECONDS = 0.12,
		-- The Neon pieces' colours (white in the kit): seams and rings, stars, the star egg's glow.
		SEAM_COLOR = rgb(80, 220, 255),
		STAR_COLOR = rgb(255, 214, 110),
		EGG_GLOW_COLOR = rgb(255, 214, 110),
		-- Its eyes tell the hunt's phase: gold while it carries the egg and flees, red once the
		-- egg is out and it guards it.
		EYE_CARRYING = rgb(255, 200, 60),
		EYE_GUARDING = rgb(255, 60, 50),
		-- The star egg turns in its cradle, radians a second.
		EGG_SPIN = 0.8,
		-- The constellation line from star to star down its back: Beams, as wide as this share of
		-- a segment's size.
		LINE_COLOR = rgb(170, 150, 255),
		LINE_WIDTH = 0.05,
		LINE_TRANSPARENCY = 0.15,
		-- The thruster's jet at the tail: a cyan Beam with a running texture over a white core.
		JET = table.freeze({
			texture = "rbxassetid://74020183030100", -- assets/fx/jet-plasma.svg (JetpackLooks)
			core = "rbxassetid://130565237636281", -- assets/fx/jet-core.svg (JetpackLooks)
			scroll = 2.2,
			length = 14,
			width = 2.4,
			coreLength = 7,
			coreWidth = 1,
			brightness = 3,
		}),
	}),
	-- The ring sight round its head while the egg is inside it (World/SerpentTarget,
	-- docs/design/screens/serpent-target.md): as wide as where hits land
	-- (SerpentConfig.HIT_RADIUS), in the strike button's colour, breathing; a hit flashes it white
	-- and shrinks it for a moment.
	TARGET = table.freeze({
		color = rgb(255, 122, 61),
		transparency = 0.15,
		-- The line's thickness, pixels: it breathes between these once a period.
		thickness = 3,
		breathThickness = 4,
		breathSeconds = 1.2,
		-- Four notches in from the ring, this share of its width long.
		notchLength = 0.12,
		flashColor = rgb(234, 242, 255),
		flashSeconds = 0.25,
		flashScale = 0.8,
		-- Seen within this distance, studs; farther the event's pin leads.
		maxDistance = 400,
	}),
	-- A hit on its head flashes it white for a moment.
	HIT_FLASH = table.freeze({
		color = rgb(255, 255, 255),
		seconds = 0.35,
	}),
})
