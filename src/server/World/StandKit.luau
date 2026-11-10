--!strict
-- The jetpack stand's kit of meshes (decision 091): for each tier `n` of BayLooks.STAND_TIERS its
-- plastic body `Body<n>` with the colours baked in, its yellow light `Glow<n>`, the hot grate
-- where the flame lands `Grate<n>`, the pilot lights `Pilot<n>`, and the top tier's gold `Gold6`.
-- From Blender (assets/blender/trainer/stand_kit.py, the shapes in stand.py), in
-- ServerStorage.StandKit of the place (World/MeshKit). Every tier is modelled about the same
-- origin, the platform's centre on the floor, marked by the kit's `Origin` speck: the kit itself
-- holds where each piece goes. Without the kit in the place the stand stands in greybox.
--
-- Into the place: stand-kit.glb uploaded through Open Cloud and inserted into ServerStorage, its
-- MeshParts moved into a Folder `StandKit` without moving them; CollisionFidelity Box by hand in
-- Properties (MCP can't set it; the pieces touch nothing, hull data would only weigh). Save the
-- place. In the place now: asset 138487246978119 (2026-11-10; insertion turned it 46.2° about Y,
-- which the offsets from `Origin` don't mind).

local ServerStorage = game:GetService("ServerStorage")

local MeshKit = require(script.Parent.MeshKit)

local FOLDER = "StandKit"

export type Piece = {
	-- A fresh copy, anchored, touching nothing.
	part: MeshPart,
	-- Where it sits from the stand's origin (the platform's centre on the floor, -Z where the
	-- rider faces).
	offset: CFrame,
}

local StandKit = {}

-- A copy of the piece `id` and where it goes on the stand; nil without it in the kit.
function StandKit.piece(id: string): Piece?
	local origin = MeshKit.source(FOLDER, "Origin")
	local source = MeshKit.source(FOLDER, id)
	local part = MeshKit.piece(FOLDER, id)
	if not origin or not source or not part then
		return nil
	end
	return { part = part, offset = origin.CFrame:ToObjectSpace(source.CFrame) }
end

-- Whether the kit has a piece `id` (not every tier wears every piece: gold is the top's), without
-- warning about it.
function StandKit.has(id: string): boolean
	local kit = ServerStorage:FindFirstChild(FOLDER)
	local source = kit and kit:FindFirstChild(id)
	return source ~= nil and source:IsA("MeshPart")
end

-- Whether the place has the kit (its origin mark): with it, the stand is built from the kit.
function StandKit.present(): boolean
	return MeshKit.source(FOLDER, "Origin") ~= nil
end

return table.freeze(StandKit)
