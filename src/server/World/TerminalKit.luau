--!strict
-- The island terminals' kit of meshes (docs/design/screens/terminals.md, version 2): the console's
-- rounded body, its sloped cap and the emitter's ring, from Blender
-- (assets/blender/terminals/terminal_kit.py), modelled at their size in game
-- (BayLooks.TERMINAL_CONSOLE), white: BayModel gives each copy its turn, material and colour.
-- Without the kit in the place a terminal stands in greybox parts of the same size.
--
-- Into the place (as the zones' kit, decision 085): terminal-kit.glb uploaded through Open Cloud,
-- inserted into ServerStorage, its MeshParts moved into a Folder `TerminalKit` (CollisionFidelity
-- Box). Save the place.

local MeshKit = require(script.Parent.MeshKit)

local FOLDER_NAME = "TerminalKit"

export type PieceId = "ConsoleBody" | "ConsoleCap" | "EmitterRing"

local TerminalKit = {}

-- A fresh copy of `id`, anchored and touching nothing; nil (with one warning) without the kit.
function TerminalKit.piece(id: PieceId): MeshPart?
	return MeshKit.piece(FOLDER_NAME, id)
end

return table.freeze(TerminalKit)
