--!strict
-- The zones' kit of meshes (docs/plans/ZONES.md): rock shapes, crystals and rings from Blender
-- (assets/blender/zones/zone_kit.py), one MeshPart a piece in ServerStorage.ZoneKit of the place
-- (inserted by hand, like the aliens: live sync through Rojo drops meshes, decision 081). A piece
-- is grey in its vertex colours; whoever takes a copy gives it its size, turn, material and colour.
-- Without the kit in the place the world stands in greybox: `piece` returns nil.
--
-- Into the place (decision 085): Open Cloud asset 137199388945832 (zone-kit.glb) inserted into
-- ServerStorage, its MeshParts moved into a Folder `ZoneKit`; the rocks get CollisionFidelity Hull
-- (Studio only: a game server can't set it), the crystals and the ring Box. Save the place.

local ServerStorage = game:GetService("ServerStorage")

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

local warned = false

-- A fresh copy of `id`, anchored and touching nothing; nil (with one warning) without the kit.
function ZoneKit.piece(id: PieceId): MeshPart?
	local folder = ServerStorage:FindFirstChild(FOLDER_NAME)
	local source = folder and folder:FindFirstChild(id)
	if not source or not source:IsA("MeshPart") then
		if not warned then
			warned = true
			warn(`[ZoneKit] No {id} in ServerStorage.{FOLDER_NAME}; the world stands in greybox`)
		end
		return nil
	end
	local part = source:Clone()
	part.Anchored = true
	part.CanTouch = false
	return part
end

return ZoneKit
