--!strict
-- Glides the bays' places to where the layout moved them. A new alien on a place reshapes the
-- layout (Domain/PlaceLayout): the server moves the places (BayConfig.PLACE_PIVOT_ATTRIBUTE)
-- and their aliens at once, and here they slide there together, with the aliens'
-- AlienMotionController, in BayLooks.LAYOUT_GLIDE_SECONDS rather than jump (2026-11-10).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)
local PetMotion = require(ReplicatedStorage.Shared.Domain.PetMotion)

export type PlaceGlideController = {
	name: string,
	start: () -> (),
}

type Place = {
	-- Where it stands now, its floor frame.
	at: CFrame,
	-- Its parts, and where each sits against that frame.
	parts: { BasePart },
	offsets: { CFrame },
	-- On the way: from where, to where, since when.
	from: CFrame?,
	to: CFrame?,
	start: number,
}

local PlaceGlideController = {}

function PlaceGlideController.new(): PlaceGlideController
	local places: { [Instance]: Place } = {}
	local connections: { [Instance]: RBXScriptConnection } = {}

	local function forget(instance: Instance)
		places[instance] = nil
		local connection = connections[instance]
		if connection then
			connection:Disconnect()
			connections[instance] = nil
		end
	end

	-- A place streams in whole (BayModel.buildPlace): read it on the next step, once its parts are in.
	local function watch(instance: Instance)
		task.defer(function()
			local found = instance:GetAttribute(BayConfig.PLACE_PIVOT_ATTRIBUTE)
			if places[instance] or typeof(found) ~= "CFrame" or not instance:IsDescendantOf(workspace) then
				return
			end
			local pivot = found :: CFrame
			local parts: { BasePart } = {}
			local offsets: { CFrame } = {}
			for _, item in instance:GetDescendants() do
				if item:IsA("BasePart") then
					local part = item :: BasePart
					table.insert(parts, part)
					table.insert(offsets, (pivot:ToObjectSpace(part.CFrame)))
				end
			end
			local place: Place = {
				at = pivot,
				parts = parts,
				offsets = offsets,
				from = nil :: CFrame?,
				to = nil :: CFrame?,
				start = 0,
			}
			places[instance] = place
			connections[instance] = instance
				:GetAttributeChangedSignal(BayConfig.PLACE_PIVOT_ATTRIBUTE)
				:Connect(function()
					local to = instance:GetAttribute(BayConfig.PLACE_PIVOT_ATTRIBUTE)
					if typeof(to) == "CFrame" then
						place.from, place.to, place.start = place.at, to :: CFrame, os.clock()
					end
				end)
		end)
	end

	local function step()
		local t = os.clock()
		local parts: { BasePart } = {}
		local frames: { CFrame } = {}
		for _, place in places do
			local from, to = place.from, place.to
			if not (from and to) then
				continue
			end
			local u = (t - place.start) / BayLooks.LAYOUT_GLIDE_SECONDS
			if u >= 1 then
				place.at, place.from, place.to = to, nil, nil
			else
				place.at = from:Lerp(to, PetMotion.smooth(u))
			end
			for index, part in place.parts do
				table.insert(parts, part)
				table.insert(frames, place.at * place.offsets[index])
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	local function start()
		for _, instance in CollectionService:GetTagged(BayConfig.PLACE_TAG) do
			watch(instance)
		end
		CollectionService:GetInstanceAddedSignal(BayConfig.PLACE_TAG):Connect(watch)
		CollectionService:GetInstanceRemovedSignal(BayConfig.PLACE_TAG):Connect(forget)
		RunService.RenderStepped:Connect(step)
	end

	return {
		name = "PlaceGlideController",
		start = start,
	}
end

return table.freeze(PlaceGlideController)
