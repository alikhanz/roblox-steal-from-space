--!strict
-- The UI's images: white icons and sprites, tinted in game with ImageColor3. Sources are the SVG
-- files in assets/ui (icons and sprites); `lune run icons` renders them to PNG and they are
-- uploaded to Roblox (see lune/icons.luau). A redrawn icon is uploaded again and its id
-- replaced here.

export type Name =
	"Bay"
	| "Store"
	| "Quests"
	| "Index"
	| "Gift"
	| "Strike"
	| "Harpoon"
	| "Bomb"
	| "Up"
	| "Down"
	| "SlowMode"
	| "Bolt"
	| "Coin"
	| "Oxygen"
	| "Egg"
	| "Robux"
	| "Shield"
	| "Meteor"
	| "Jetpack"
	| "Moon"

local ICONS: { [Name]: string } = {
	Bay = "rbxassetid://132068323643628",
	Store = "rbxassetid://124606108914450",
	Quests = "rbxassetid://106652945082541",
	Index = "rbxassetid://91459266009462",
	Gift = "rbxassetid://72977247145594",
	Strike = "rbxassetid://100400859366699",
	Harpoon = "rbxassetid://115071386432229",
	Bomb = "rbxassetid://82979735959616",
	Up = "rbxassetid://134202026326152",
	Down = "rbxassetid://107757551768553",
	SlowMode = "rbxassetid://94179189160849",
	Bolt = "rbxassetid://137331283536006",
	Coin = "rbxassetid://122240898300854",
	Oxygen = "rbxassetid://97784935625653",
	Egg = "rbxassetid://117551467296815",
	Robux = "rbxassetid://127663785262718",
	Shield = "rbxassetid://89953779523463",
	Meteor = "rbxassetid://92726378354461",
	Jetpack = "rbxassetid://90247972090746",
	Moon = "rbxassetid://129273642841872",
}

return table.freeze({
	ICONS = table.freeze(ICONS),
	-- A filled white circle: cooldown sectors and round fills.
	DISC = "rbxassetid://103633034854387",
	-- A soft white ring for the glow around round buttons; drawn larger than the button.
	GLOW = "rbxassetid://136899120987901",
	-- Two jetpack flames, drawn over the Jetpack icon at the same size; coloured by a gradient.
	FLAME = "rbxassetid://123575093225405",
})
