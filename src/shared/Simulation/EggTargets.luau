--!strict
-- Finds the egg a character can grab: the nearest egg in a nest or floating loose within range
-- (the grab reach, or the wider lock range of a fast flyer: Grab.lockRange).
-- Shared by the simulation (what the grab acts on) and the HUD (when to show the grab hint).

local CollectionService = game:GetService("CollectionService")

local EggConfig = require("../Config/EggConfig")

export type Target = {
	-- Nest model name or loose egg part name: what the server looks up to confirm the grab.
	id: string,
	position: Vector3,
	rarity: EggConfig.RarityId,
	-- The egg part itself, when present on this machine (for the HUD to attach its prompt).
	part: BasePart?,
}

local EggTargets = {}

local function asRarity(value: unknown): EggConfig.RarityId?
	if type(value) == "string" and EggConfig.RARITIES[value :: EggConfig.RarityId] then
		return value :: EggConfig.RarityId
	end
	return nil
end

function EggTargets.nearest(position: Vector3, range: number?): Target?
	local best: Target? = nil
	local bestDistance = range or EggConfig.GRAB_REACH

	local function consider(id: string, eggPosition: Vector3, rarity: EggConfig.RarityId, part: Instance?)
		local distance = (eggPosition - position).Magnitude
		if distance <= bestDistance then
			bestDistance = distance
			best = {
				id = id,
				position = eggPosition,
				rarity = rarity,
				part = if part and part:IsA("BasePart") then part else nil,
			}
		end
	end

	for _, nest in CollectionService:GetTagged(EggConfig.NEST_TAG) do
		local eggPosition = nest:GetAttribute(EggConfig.NEST_EGG_POSITION_ATTRIBUTE)
		local rarity = asRarity(nest:GetAttribute(EggConfig.NEST_RARITY_ATTRIBUTE))
		if
			nest:GetAttribute(EggConfig.NEST_HAS_EGG_ATTRIBUTE) == true
			and typeof(eggPosition) == "Vector3"
			and rarity
		then
			consider(nest.Name, eggPosition, rarity, nest:FindFirstChild(EggConfig.NEST_EGG_NAME))
		end
	end

	for _, egg in CollectionService:GetTagged(EggConfig.LOOSE_EGG_TAG) do
		local rarity = asRarity(egg:GetAttribute(EggConfig.LOOSE_EGG_RARITY_ATTRIBUTE))
		if egg:IsA("BasePart") and rarity then
			consider(egg.Name, egg.Position, rarity, egg)
		end
	end

	return best
end

return table.freeze(EggTargets)
