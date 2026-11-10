--!strict
-- The island incubator's kit of meshes (docs/design/screens/incubator.md): the dais `DaisBody` and
-- its light `DaisGlow`, an open capsule `PodBody` and its light `PodGlow`, a closed bud `BudBody`.
-- Bodies carry their colours baked in; lights are Neon the game colours. From Blender
-- (assets/blender/bay/incubator_kit.py, the numbers of Config/IncubatorShape), in
-- ServerStorage.IncubatorKit of the place (World/MeshKit). The dais is modelled about the
-- incubator's centre on the floor, a capsule and a bud about their slot on the dais's top (-Z out
-- of the ring), all marked by the kit's one `Origin` speck: the kit itself holds where each piece
-- goes in its frame. Without the kit in the place the incubator stands in greybox.
--
-- Into the place (as the shelf's kit, decision 092): incubator-kit.glb uploaded through Open Cloud
-- and inserted into ServerStorage, its MeshParts moved into a Folder `IncubatorKit` without moving
-- them; CollisionFidelity Box (the pieces touch nothing: the solid dais and sockets are plain
-- parts). Save the place. In the place now: asset 137643210070526 (2026-11-10).

local MeshKit = require(script.Parent.MeshKit)

local FOLDER = "IncubatorKit"

export type PieceId = "DaisBody" | "DaisGlow" | "PodBody" | "PodGlow" | "BudBody"

export type Piece = {
	-- A fresh copy, anchored, touching nothing.
	part: MeshPart,
	-- Where it sits from its frame (the incubator's centre on the floor for the dais, its slot on
	-- the dais's top for a capsule or a bud).
	offset: CFrame,
}

local IncubatorKit = {}

-- A copy of the piece `id` and where it goes in its frame; nil (with one warning) without the kit.
function IncubatorKit.piece(id: PieceId): Piece?
	local origin = MeshKit.source(FOLDER, "Origin")
	local source = MeshKit.source(FOLDER, id)
	local part = MeshKit.piece(FOLDER, id)
	if not origin or not source or not part then
		return nil
	end
	return { part = part, offset = origin.CFrame:ToObjectSpace(source.CFrame) }
end

return table.freeze(IncubatorKit)
