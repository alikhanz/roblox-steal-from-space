--!strict
-- The island shelf's kit of meshes (docs/design/screens/storage-shelf.md): its plastic body `Body`
-- with the colours baked in and its light strips `Glow`. From Blender
-- (assets/blender/bay/storage_kit.py, the numbers of Config/ShelfShape), in
-- ServerStorage.StorageKit of the place (World/MeshKit). Both are modelled about the shelf's
-- origin, marked by the kit's `Origin` speck: the kit itself holds where each piece goes. Without
-- the kit in the place the shelf stands in greybox.
--
-- Into the place (as the stand's kit, decision 091): storage-kit.glb uploaded through Open Cloud and
-- inserted into ServerStorage, its MeshParts moved into a Folder `StorageKit` without moving them;
-- CollisionFidelity Box (the pieces touch nothing: the shelf's solid blocks are plain parts). Save
-- the place. In the place now: asset 123243423747227 (2026-11-10; insertion turned it 46.2° about
-- Y, which the offsets from `Origin` don't mind).

local MeshKit = require(script.Parent.MeshKit)

local FOLDER = "StorageKit"

export type PieceId = "Body" | "Glow"

export type Piece = {
	-- A fresh copy, anchored, touching nothing.
	part: MeshPart,
	-- Where it sits from the shelf's origin.
	offset: CFrame,
}

local StorageKit = {}

-- A copy of the piece `id` and where it goes on the shelf; nil (with one warning) without the kit.
function StorageKit.piece(id: PieceId): Piece?
	local origin = MeshKit.source(FOLDER, "Origin")
	local source = MeshKit.source(FOLDER, id)
	local part = MeshKit.piece(FOLDER, id)
	if not origin or not source or not part then
		return nil
	end
	return { part = part, offset = origin.CFrame:ToObjectSpace(source.CFrame) }
end

return table.freeze(StorageKit)
