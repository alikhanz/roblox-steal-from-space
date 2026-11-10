--!strict
-- How the harpoon and the gravity bomb look (brief docs/design/screens/pvp-abilities.md). Every
-- client draws them (World/HarpoonVisual, World/BombVisual) from the kit of meshes
-- ReplicatedStorage.PvpKit (assets/blender/pvp/pvp_kit.py); without the kit, greybox of the same
-- shapes. Pure data: the motion's shapes are Domain/PvpFx.

local PvpFx = require("../Domain/PvpFx")

export type Harpoon = {
	-- The Neon pieces (magnet, muzzle ring), the cable's glow, the grab flash.
	read color: Color3,
	-- The cable's bright strand.
	read coreColor: Color3,
	-- Studs a second, out and back.
	read hookSpeed: number,
	read retractSpeed: number,
	-- The claws hold this long before the hook rides the egg or lets go.
	read grabSeconds: number,
	-- The hook rides a loose egg at most this long, and lets go once it is slower than this.
	read rideSeconds: number,
	read rideRestSpeed: number,
	-- A miss: the hook hangs at the end of its reach this long while the cable sags this much.
	read missHoldSeconds: number,
	read missSagStuds: number,
	-- The loose egg is looked for this close to where the hook lands.
	read eggSearchStuds: number,
	-- The cable: a bright strand in a glow (Beams), studs wide.
	read cableWidth: number,
	read cableGlowWidth: number,
	read cableGlowTransparency: number,
	read trail: { read lifetime: number, read width: number },
	-- The grab flash, a ring round the egg: radius from, to, seconds.
	read flash: { read from: number, read to: number, read seconds: number },
	-- The launcher on the wrist pops in this fast.
	read launcherPopSeconds: number,
}

export type Bomb = {
	-- The belt, the light, the orbits, the wave.
	read color: Color3,
	-- The orbits' radius, studs, and their spin and the light's blinking from the throw to the
	-- end of the fuse (PvpFx.bombCharge).
	read orbitRadius: number,
	read orbitThickness: number,
	read charge: PvpFx.Charge,
	read trail: { read lifetime: number, read width: number },
	-- The flash at the centre: a ball's radius from, to, seconds.
	read flash: { read from: number, read to: number, read seconds: number },
	-- The ring wave out to the blast's radius (PvpFx.wave), and its thickness, studs.
	read wave: PvpFx.Wave,
	read waveThickness: number,
}

local HARPOON: Harpoon = {
	color = Color3.fromRGB(63, 217, 255),
	coreColor = Color3.fromRGB(225, 250, 255),
	hookSpeed = 220,
	retractSpeed = 170,
	grabSeconds = 0.1,
	rideSeconds = 0.8,
	rideRestSpeed = 4,
	missHoldSeconds = 0.12,
	missSagStuds = 4,
	eggSearchStuds = 10,
	cableWidth = 0.15,
	cableGlowWidth = 0.7,
	cableGlowTransparency = 0.5,
	trail = table.freeze({ lifetime = 0.15, width = 0.6 }),
	flash = table.freeze({ from = 1.5, to = 4.5, seconds = 0.3 }),
	launcherPopSeconds = 0.08,
}

local BOMB: Bomb = {
	-- Deeper than the button's #B57BFF: a light violet burns white in Neon under Bloom
	-- (BLENDER_ROBLOX.md, section 2).
	color = Color3.fromRGB(140, 95, 255),
	orbitRadius = 2,
	orbitThickness = 0.16,
	charge = table.freeze({
		spinFrom = 1.5,
		spinTo = 5,
		blinkFrom = 2,
		blinkTo = 10,
		collapseSeconds = 0.2,
		collapseScale = 0.45,
	}),
	trail = table.freeze({ lifetime = 0.25, width = 1.4 }),
	flash = table.freeze({ from = 1.5, to = 5, seconds = 0.25 }),
	wave = table.freeze({ startRadius = 2, growSeconds = 0.3, holdSeconds = 0.12, fadeSeconds = 0.3 }),
	waveThickness = 0.5,
}

return table.freeze({
	HARPOON = table.freeze(HARPOON),
	BOMB = table.freeze(BOMB),
	-- The kit's folder in ReplicatedStorage and the client's folder for the effects in workspace.
	KIT_FOLDER_NAME = "PvpKit",
	EFFECTS_FOLDER_NAME = "PvpEffects",
	-- Someone else's harpoon or bomb farther than this from the camera is not drawn.
	DRAW_DISTANCE = 400,
})
