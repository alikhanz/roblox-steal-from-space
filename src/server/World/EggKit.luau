--!strict
-- The egg's kit of meshes (decision 088): for each kind of egg (the five rarities, and each of them
-- as a meteor egg, `Meteor<Rarity>`) its capsule's plastic body `Body<Kind>` with the colours
-- baked in, and what glows on it `Glow<Kind>` (none for Common); the legendary's gold cap with its
-- crown `CapGold`. From Blender (assets/blender/eggs/egg_kit.py), in ServerStorage.EggKit of the
-- place (World/MeshKit). The pieces sit where a medium egg wears them; the kit's `Centre` speck
-- marks the egg's centre, so the kit itself holds where each piece goes. Without the kit in the
-- place eggs stand in greybox.
--
-- Into the place: Open Cloud asset 124416766785269 (egg-kit.glb) inserted into ServerStorage, its
-- MeshParts moved into a Folder `EggKit` without moving them; CollisionFidelity Box by hand in
-- Properties (MCP can't set it; an egg's pieces touch nothing, so hull data would only weigh).
-- Save the place. Studio downloads fresh meshes slowly: right after an insert, eggs may stand
-- half-drawn for half a minute.

local MeshKit = require(script.Parent.MeshKit)

local FOLDER = "EggKit"

export type Piece = {
	-- A fresh copy, welded to nothing, touching nothing, at the size of a medium egg.
	part: MeshPart,
	-- Where it sits from a medium egg's centre.
	offset: CFrame,
}

local EggKit = {}

-- A copy of the piece `id` and where it goes on the egg; nil without it in the kit.
function EggKit.piece(id: string): Piece?
	local centre = MeshKit.source(FOLDER, "Centre")
	local source = MeshKit.source(FOLDER, id)
	local part = MeshKit.piece(FOLDER, id)
	if not centre or not source or not part then
		return nil
	end
	-- What the egg wears is welded to it and moves with it. Never the root of its assembly: callers
	-- place an egg by its CFrame before it enters the workspace, where no joint moves the pieces
	-- along, and on entering the solver lines the assembly up on its root. With a piece as root the
	-- egg jumped back to its pieces, left where it was built, and a thief carried it welded hundreds
	-- of studs away, swinging round as they turned (2026-11-10; Studio: 2311 studs off with
	-- priority 0, 2.3 with -127).
	part.RootPriority = -127
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
