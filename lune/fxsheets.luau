--!strict
-- `lune run fxsheets`: writes the two flipbook sheets of the pets' dust (assets/fx/dustsheet.svg,
-- starsheet.svg; AlienLooks.FX.CLUSTERS): 4x4 frames of a cluster of specks or stars, each on its
-- own beat, looping. Seeded, so the output is stable. Then `lune run icons` renders them to PNG.

local fs = require("@lune/fs")

local FRAMES = 16
local GRID = 4
local CELL = 128 -- in the SVG's units; the sheet is rendered at 1024 px
local COUNT = 6

math.randomseed(20261110)
local random = {}
function random:NextNumber(a: number?, b: number?): number
	local lo, hi = a or 0, b or 1
	return lo + math.random() * (hi - lo)
end

local function cluster()
	local specks = {}
	for i = 1, COUNT do
		local angle = (i - 1) / COUNT * 2 * math.pi + random:NextNumber(-0.4, 0.4)
		local distance = random:NextNumber(10, 44)
		table.insert(specks, {
			x = math.cos(angle) * distance,
			y = math.sin(angle) * distance,
			r = random:NextNumber(7, 12),
			phase = random:NextNumber(0, 1),
			-- some twinkle twice a loop
			speed = if random:NextNumber() < 0.35 then 2 else 1,
		})
	end
	return specks
end

local STAR =
	"M0 -1 C0.17 -0.23 0.23 -0.17 1 0 C0.23 0.17 0.17 0.23 0 1 C-0.17 0.23 -0.23 0.17 -1 0 C-0.23 -0.17 -0.17 -0.23 0 -1 Z"

local function sheet(kind: string, comment: string): string
	local specks = cluster()
	local parts = {
		`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CELL * GRID} {CELL * GRID}">`,
		`  <!-- {comment} Generated (seeded), 4x4 frames that loop: {COUNT} specks, each twinkling on its own beat. White on transparency, tinted in game. -->`,
		`  <defs>`,
		`    <radialGradient id="speck"><stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="0.45" stop-color="#fff" stop-opacity="0.95"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>`,
		`  </defs>`,
	}
	for frame = 0, FRAMES - 1 do
		local cx = (frame % GRID) * CELL + CELL / 2
		local cy = math.floor(frame / GRID) * CELL + CELL / 2
		for _, s in specks do
			local wave = math.sin(2 * math.pi * (frame / FRAMES * s.speed + s.phase))
			local light = 0.5 + 0.5 * (0.5 + 0.5 * wave)
			local scale = 0.75 + 0.25 * light
			local x, y = cx + s.x, cy + s.y
			if kind == "dust" then
				table.insert(
					parts,
					string.format(
						'  <circle cx="%.1f" cy="%.1f" r="%.2f" fill="url(#speck)" opacity="%.2f"/>',
						x,
						y,
						s.r * 1.6 * scale,
						light
					)
				)
			else
				local r = s.r * 1.9 * scale
				table.insert(
					parts,
					string.format(
						'  <path d="%s" transform="translate(%.1f %.1f) scale(%.2f)" fill="#fff" opacity="%.2f"/>',
						STAR,
						x,
						y,
						r,
						light
					)
				)
				table.insert(
					parts,
					string.format(
						'  <circle cx="%.1f" cy="%.1f" r="%.2f" fill="url(#speck)" opacity="%.2f"/>',
						x,
						y,
						r * 0.55,
						light
					)
				)
			end
		end
	end
	table.insert(parts, "</svg>")
	return table.concat(parts, "\n") .. "\n"
end

fs.writeFile(
	"assets/fx/dustsheet.svg",
	sheet(
		"dust",
		"Twinkling dust round a pet (AlienDress, AlienLooks.FX.CLUSTERS): one particle carries a cluster, several times fewer particles for the same dust (2026-11-10)."
	)
)
fs.writeFile(
	"assets/fx/starsheet.svg",
	sheet(
		"stars",
		"Twinkling stars round a pet (AlienDress, AlienLooks.FX.CLUSTERS): one particle carries a cluster (2026-11-10)."
	)
)
print("ok")
