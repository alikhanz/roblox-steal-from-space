--!strict
-- Where a pet stands and what it turns round: the middle of its body, not of everything it carries.
-- A pet's model holds its body and what dresses it (wings, the outfit's crown, aura and back piece,
-- what orbits it). Centred on the box of all of it, a pet with its wings to one side or a star
-- behind stood off its place, and turning to a player swung its body round a point beside it (user,
-- 2026-11-14: "the turning centre must be at the centre of the alien's body"). Pure Luau, no Roblox
-- globals (Lune tests): the callers (World/AlienDress, World/PetTemplate) hand in the parts' frames
-- and sizes.

local PetBox = {}

-- A part as a box: where it stands and how big it is.
export type Piece = {
	cframe: CFrame,
	size: Vector3,
}

-- The box round `pieces` in `frame`'s space: its lowest and highest corner. Nil for no pieces.
function PetBox.bounds(pieces: { Piece }, frame: CFrame): (Vector3?, Vector3?)
	local low: Vector3? = nil
	local high: Vector3? = nil
	for _, piece in pieces do
		local relative = frame:ToObjectSpace(piece.cframe)
		local half = piece.size / 2
		local x, y, z = relative.XVector * half.X, relative.YVector * half.Y, relative.ZVector * half.Z
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = relative.Position + x * sx + y * sy + z * sz
					low = if low then low:Min(corner) else corner
					high = if high then high:Max(corner) else corner
				end
			end
		end
	end
	return low, high
end

-- The middle of `pieces` (the body's parts) across the floor, in `frame`'s space: its X and Z.
-- The frame's own axis (0, 0) for no pieces.
function PetBox.middle(pieces: { Piece }, frame: CFrame): (number, number)
	local low, high = PetBox.bounds(pieces, frame)
	if not (low and high) then
		return 0, 0
	end
	return (low.X + high.X) / 2, (low.Z + high.Z) / 2
end

-- How far `pieces` reach across the floor from `frame`'s upright axis at most, in any of the four
-- directions: half the width a place must have for the pet standing on that axis.
function PetBox.reach(pieces: { Piece }, frame: CFrame): number
	local low, high = PetBox.bounds(pieces, frame)
	if not (low and high) then
		return 0
	end
	return math.max(-low.X, high.X, -low.Z, high.Z, 0)
end

return table.freeze(PetBox)
