--!strict
-- The egg's kit of meshes (decision 087): the capsule's base and cap, its seam, window, antenna
-- and tip, lava cracks and a ring, from Blender (assets/blender/eggs/egg_kit.py), in
-- ServerStorage.EggKit of the place (World/MeshKit). The pieces sit where a medium egg wears them;
-- the kit's `Centre` speck marks the egg's centre, so the kit itself holds where each piece goes.
-- Without the kit in the place eggs stand in greybox: `piece` returns nil.
--
-- Into the place: Open Cloud asset 101037392998831 (egg-kit.glb) inserted into ServerStorage, its
-- MeshParts moved into a Folder `EggKit` without moving them (CollisionFidelity stays Default:
-- an egg's pieces touch nothing). Save the place. Studio downloads fresh meshes slowly: right
-- after an insert, eggs may show only their small pieces for half a minute.

local MeshKit = require(script.Parent.MeshKit)

local FOLDER = "EggKit"

export type PieceId = "Base" | "Cap" | "Seam" | "Window" | "Antenna" | "Tip" | "Cracks" | "Ring"

export type Piece = {
	-- A fresh copy, welded to nothing, touching nothing, at the size of a medium egg.
	part: MeshPart,
	-- Where it sits from a medium egg's centre (the ring: at the centre, lying flat).
	offset: CFrame,
}

local EggKit = {}

-- A copy of `id` and where it goes on the egg; nil without the kit.
function EggKit.piece(id: PieceId): Piece?
	local centre = MeshKit.source(FOLDER, "Centre")
	local source = MeshKit.source(FOLDER, id)
	local part = MeshKit.piece(FOLDER, id)
	if not centre or not source or not part then
		return nil
	end
	-- What the egg wears is welded to it and moves with it.
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	return { part = part, offset = centre.CFrame:ToObjectSpace(source.CFrame) }
end

-- Whether the place has the kit (its centre mark): with it, an egg is built from the kit.
function EggKit.present(): boolean
	return MeshKit.source(FOLDER, "Centre") ~= nil
end

return table.freeze(EggKit)
