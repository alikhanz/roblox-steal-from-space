--!strict
-- The egg's kit of meshes (decision 087): the starry shell, its stars, its cracks and a ring, from
-- Blender (assets/blender/eggs/egg_kit.py), in ServerStorage.EggKit of the place (World/MeshKit).
-- The pieces sit where the egg wears them, about the shell's centre, so the kit itself holds where
-- each goes. Without the kit in the place eggs stand in greybox: `piece` returns nil.
--
-- Into the place: the Open Cloud asset of egg-kit.glb inserted into ServerStorage, its MeshParts
-- moved into a Folder `EggKit` without moving them, CollisionFidelity Box. Save the place.

local MeshKit = require(script.Parent.MeshKit)

local FOLDER = "EggKit"

export type PieceId = "Shell" | "Stars" | "Cracks" | "Ring"

export type Piece = {
	-- A fresh copy, welded to nothing, touching nothing, at the size it was modelled.
	part: MeshPart,
	-- Where it sits in the shell's frame, at the size it was modelled (the ring: at the centre).
	offset: CFrame,
}

local EggKit = {}

-- A copy of `id` and where it goes on the shell; nil without the kit.
function EggKit.piece(id: PieceId): Piece?
	local shell = MeshKit.source(FOLDER, "Shell")
	local source = MeshKit.source(FOLDER, id)
	local part = MeshKit.piece(FOLDER, id)
	if not shell or not source or not part then
		return nil
	end
	-- What the egg wears is welded to the shell and moves with it.
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	return { part = part, offset = shell.CFrame:ToObjectSpace(source.CFrame) }
end

-- The shell's size as modelled: a piece's size and offset scale by the egg's size over this.
function EggKit.shellSize(): Vector3?
	local shell = MeshKit.source(FOLDER, "Shell")
	return if shell then shell.Size else nil
end

return table.freeze(EggKit)
