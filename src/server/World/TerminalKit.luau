--!strict
-- The island terminals' kit of meshes (docs/design/screens/terminals.md, version 2; decision 086),
-- from Blender (assets/blender/terminals/terminal_kit.py), one mesh a material:
--
--   Console - the foot, body and cap, steel; their shades baked in the vertex colours, BayModel
--             gives the cap's colour (BayLooks.TERMINAL_HULL_COLOR) and Metal;
--   Glow    - the stripe, emitter, lens, screen frame and corner lights, white; BayModel gives the
--             zone's colour and Neon.
--
-- Each is modelled where it stands on a terminal, and its pivot is the terminal's spot (the floor
-- under its middle, -Z toward the player): BayModel puts a copy on a terminal with one PivotTo.
-- Without the kit in the place a terminal stands in greybox parts of the same shapes.
--
-- Into the place (as the zones' kit, decision 085): terminal-kit.glb uploaded through Open Cloud
-- and inserted into ServerStorage (both meshes lie on one origin there). The Console's bottom
-- middle is the terminal's spot: every piece gets PivotOffset = its CFrame:Inverse() * that spot
-- (unturned); then the MeshParts go into a Folder `TerminalKit`. Save the place.

local MeshKit = require(script.Parent.MeshKit)

local FOLDER_NAME = "TerminalKit"

export type PieceId = "Console" | "Glow"

local TerminalKit = {}

-- A fresh copy of `id`, anchored and touching nothing; nil (with one warning) without the kit.
function TerminalKit.piece(id: PieceId): MeshPart?
	return MeshKit.piece(FOLDER_NAME, id)
end

return table.freeze(TerminalKit)
