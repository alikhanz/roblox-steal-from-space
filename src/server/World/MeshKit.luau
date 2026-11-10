--!strict
-- A kit of meshes from Blender in the place (decision 085): one MeshPart a piece in a Folder of
-- ServerStorage, inserted by hand like the aliens (live sync through Rojo drops meshes, decision
-- 081). Whoever takes a copy gives it its size, turn, material and colour. The kits: World/ZoneKit
-- (rocks, crystals, rings), World/TerminalKit (the island terminals' console), World/EggKit (the
-- egg's shell and what it wears), World/StationKit (the central station), World/StandKit (the
-- jetpack stand), World/StorageKit (the island's shelf), World/IncubatorKit (the island's
-- incubator).

local ServerStorage = game:GetService("ServerStorage")

local MeshKit = {}

-- Kits already warned about: one warning a kit, not one a copy.
local warned: { [string]: boolean } = {}

-- The piece `id` itself, as the kit in ServerStorage[`folder`] holds it (to read, never to
-- change); nil (with one warning a kit) when the place has no such piece.
function MeshKit.source(folder: string, id: string): MeshPart?
	local kit = ServerStorage:FindFirstChild(folder)
	local source = kit and kit:FindFirstChild(id)
	if not source or not source:IsA("MeshPart") then
		if not warned[folder] then
			warned[folder] = true
			warn(`[MeshKit] No {id} in ServerStorage.{folder}; it stands in greybox`)
		end
		return nil
	end
	return source
end

-- A fresh copy of the piece `id` of the kit in ServerStorage[`folder`], anchored and touching
-- nothing; nil (with one warning a kit) when the place has no such piece: the caller stands in
-- greybox.
function MeshKit.piece(folder: string, id: string): MeshPart?
	local source = MeshKit.source(folder, id)
	if not source then
		return nil
	end
	local part = source:Clone()
	part.Anchored = true
	part.CanTouch = false
	return part
end

return table.freeze(MeshKit)
