--!strict
-- The zones' kit of meshes (docs/plans/ZONES.md): rock shapes, crystals and rings from Blender
-- (assets/blender/zones/zone_kit.py), one MeshPart a piece in ServerStorage.ZoneKit of the place
-- (inserted by hand, like the aliens: live sync through Rojo drops meshes, decision 081). A piece
-- is grey in its vertex colours; whoever takes a copy gives it its size, turn, material and colour.
-- Without the kit in the place the world stands in greybox: `piece` returns nil.
--
-- Into the place (decision 085): Open Cloud asset 103312508143569 (zone-kit.glb, faceted, decision 119) into
-- ServerStorage, its MeshParts moved into a Folder `ZoneKit`; the rocks get CollisionFidelity Hull
-- (Studio only: a game server can't set it), the crystals and the ring Box. Save the place.

local MeshKit = require(script.Parent.MeshKit)

local FOLDER_NAME = "ZoneKit"

export type PieceId =
	"Rock1"
	| "Rock2"
	| "Rock3"
	| "Smooth1"
	| "Smooth2"
	| "Holey"
	| "NestRock1"
	| "NestRock2"
	| "Pebbles1"
	| "Pebbles2"
	| "IceChunk1"
	| "IceChunk2"
	| "Crystals1"
	| "Crystals2"
	| "Ring"

local ZoneKit = {}

-- About how wide each piece is modelled, studs (zone_kit.py: RADIUS 5): a copy `w` wide is the
-- piece's size times w / SIZE, keeping its proportions.
ZoneKit.SIZE = 10

-- A fresh copy of `id`, anchored and touching nothing; nil (with one warning) without the kit.
function ZoneKit.piece(id: PieceId): MeshPart?
	return MeshKit.piece(FOLDER_NAME, id)
end

return ZoneKit
