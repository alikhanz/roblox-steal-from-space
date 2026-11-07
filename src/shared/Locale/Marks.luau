--!strict
-- Resource marks in player texts: `●` stands for coins and `⚡` for speed. Strings put the mark
-- right before the amount ("Reward: ●+12K and ⚡+3.4K"); the UI draws each mark as its icon
-- (UI/IconText), so an amount of coins looks the same in a toast, on a sign and in a window.
-- `split` cuts a text into words and marks for that.

export type Icon = "Coin" | "Bolt"

export type Piece = {
	-- Words, trimmed of the spaces around a mark (the UI puts its own gap there).
	text: string?,
	-- Or a mark.
	icon: Icon?,
}

local MARKS: { [string]: Icon } = {
	["●"] = "Coin",
	["⚡"] = "Bolt",
}

local Marks = {}

Marks.COINS = "●"
Marks.SPEED = "⚡"

local function trim(text: string): string
	return (string.gsub(text, "^%s+", ""):gsub("%s+$", ""))
end

local function addText(pieces: { Piece }, text: string)
	local trimmed = trim(text)
	if trimmed ~= "" then
		table.insert(pieces, { text = trimmed })
	end
end

-- The text as words and marks, in order. A text without marks is one piece, untouched.
function Marks.split(text: string): { Piece }
	local pieces: { Piece } = {}
	local position = 1
	while true do
		local nearest: number? = nil
		local nearestEnd = 0
		local nearestIcon: Icon? = nil
		for mark, icon in MARKS do
			local first, last = string.find(text, mark, position, true)
			if first and (nearest == nil or first < nearest) then
				nearest, nearestEnd, nearestIcon = first, last :: number, icon
			end
		end
		if nearest == nil or nearestIcon == nil then
			break
		end
		addText(pieces, string.sub(text, position, nearest - 1))
		table.insert(pieces, { icon = nearestIcon })
		position = nearestEnd + 1
	end
	if position == 1 then
		return { { text = text } }
	end
	addText(pieces, string.sub(text, position))
	return pieces
end

-- The text has a mark to draw as an icon.
function Marks.has(text: string): boolean
	for mark in MARKS do
		if string.find(text, mark, 1, true) then
			return true
		end
	end
	return false
end

return table.freeze(Marks)
