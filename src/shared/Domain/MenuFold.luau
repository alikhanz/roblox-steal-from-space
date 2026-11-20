--!strict
-- The menu row folded on a touch screen (docs/design/screens/hud-menu-fold.md): the main tiles
-- stay in the row, the rest hide behind a "more" tile that opens them in the same row. The more
-- tile carries the hidden tiles' badges (summed) and their call (the hint's pulse). Folding one
-- tile alone gains nothing: then it stands in the row and there is no more tile.
--
-- Pure Luau: tiles are names, the HUD asks this what to show.

export type Tile = {
	slot: string,
	-- The tile is shown at all (its window added it and it is not hidden by its own rule).
	shown: boolean,
	badge: number,
	pulse: boolean,
}

export type Fold = {
	-- Shown in the row now, by slot.
	inRow: { [string]: boolean },
	-- The more tile is in the row.
	more: boolean,
	-- What waits behind it: the hidden tiles' badges together, and whether one calls.
	moreBadge: number,
	morePulse: boolean,
}

local MenuFold = {}

-- What the row shows for `tiles` (left to right), keeping `main` slots always in the row;
-- `open`: the more tile was pressed and the rest stand beside it.
function MenuFold.of(tiles: { Tile }, main: { [string]: boolean }, open: boolean): Fold
	local inRow: { [string]: boolean } = {}
	local folded: { Tile } = {}
	for _, tile in tiles do
		if not tile.shown then
			inRow[tile.slot] = false
		elseif main[tile.slot] then
			inRow[tile.slot] = true
		else
			table.insert(folded, tile)
		end
	end
	local more = #folded > 1
	local badge = 0
	local pulse = false
	for _, tile in folded do
		local hidden = more and not open
		inRow[tile.slot] = not hidden
		if hidden then
			badge += tile.badge
			pulse = pulse or tile.pulse
		end
	end
	return {
		inRow = inRow,
		more = more,
		moreBadge = badge,
		morePulse = pulse,
	}
end

return table.freeze(MenuFold)
