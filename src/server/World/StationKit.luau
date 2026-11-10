--!strict
-- The central station's kit of meshes (decision 087, docs/plans/STATION.md), from Blender
-- (assets/blender/station/station_kit.py), modelled for a 60-stud platform and joined by material
-- (one MeshPart a material, the pets' lesson): the ring's segment and its glow, the strut, the cone
-- hull and its glow, and the capsule kiosk's pearl, dark and glow, plus its name plate. A copy is
-- scaled by StationShape.SCALE and given its place, turn, material and colour by
-- World/StationModel and World/KioskModel. Without the kit in the place the station stands in
-- greybox parts.
--
-- Roblox centres an imported mesh on its bounds, so each piece's frame is its bounds' centre; the
-- script builds a piece round a reference point that is easier to place (the ring's centre, a
-- strut's foot, the hull's top, a kiosk's spot on the floor). OFFSETS is where the bounds' centre
-- sits in the reference point's frame, in Roblox's axes, at the modelled size, as station_kit.py
-- prints it.
--
-- Into the place (as the zones' and terminals' kits, decisions 085, 086): the Open Cloud asset of
-- station-kit.glb inserted into ServerStorage, its MeshParts moved into a Folder `StationKit`.
-- CollisionFidelity (Studio only: a game server can't set it, and MCP's execute_luau silently can't
-- either — set it from the Command Bar or the Properties pane): RingSegment and Pylon Box; Hull,
-- KioskPearl and KioskDark Hull (players bump into them); the glows and the plate collide with
-- nothing (the game turns their collision off). Save the place.

local MeshKit = require(script.Parent.MeshKit)

local FOLDER_NAME = "StationKit"

export type PieceId =
	"RingSegment"
	| "RingGlow"
	| "Pylon"
	| "Hull"
	| "HullGlow"
	| "KioskPearl"
	| "KioskDark"
	| "KioskGlow"
	| "LabelPlate"

-- Pieces missing here are centred on their reference point (the ring's glow, the name plate). A
-- strut is stretched to its length in place and stands by its middle.
local OFFSETS: { [PieceId]: Vector3 } = {
	-- From the ring's centre, at the band's middle height; the screen niche faces -Z.
	RingSegment = Vector3.new(0, 0, -89.04),
	-- From the centre of the hull's top (the platform's underside).
	Hull = Vector3.new(0, -21.25, 0),
	HullGlow = Vector3.new(0, -26.2, 0),
	-- From a kiosk's spot on the floor; its opening faces -Z.
	KioskPearl = Vector3.new(0, 7.32, 0),
	KioskDark = Vector3.new(0, 6, 0),
	KioskGlow = Vector3.new(0, 10.84, 0),
}

local StationKit = {}

-- A fresh copy of `id` scaled by `scale`, anchored and touching nothing; nil (with one warning)
-- without the kit.
function StationKit.piece(id: PieceId, scale: number): MeshPart?
	local part = MeshKit.piece(FOLDER_NAME, id)
	if part then
		part.Size *= scale
	end
	return part
end

-- Where the copy of `id` goes for its reference point at `frame`, at `scale`.
function StationKit.place(id: PieceId, frame: CFrame, scale: number): CFrame
	return frame * CFrame.new((OFFSETS[id] or Vector3.zero) * scale)
end

return table.freeze(StationKit)
