--!strict
-- What kind of egg an egg is, for the icon it wears wherever an egg is marked or shown (markers,
-- the grab button, the egg in hand, the incubator): every special egg has its own icon (the user,
-- 2026-11-13; docs/design/screens/markers.md). A new special egg adds its kind here and its icon in
-- UI/EggIcon. Pure Luau.

local EggKind = {}

export type Kind = "Normal" | "Meteor" | "Star"

-- `variant`: the alien variant it hatches into (AlienConfig.VariantId; nil for the usual one);
-- `isLucky`: it carries extra luck, which only the star serpent's egg does (Domain/StarEgg).
function EggKind.of(variant: string?, isLucky: boolean): Kind
	if isLucky then
		return "Star"
	end
	if variant == "Meteor" then
		return "Meteor"
	end
	return "Normal"
end

-- The same for a kind sent as a string (an attribute); anything unknown is the usual egg.
function EggKind.parse(value: unknown): Kind
	if value == "Meteor" or value == "Star" then
		return value :: Kind
	end
	return "Normal"
end

return table.freeze(EggKind)
