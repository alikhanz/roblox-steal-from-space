--!strict
-- `lune run format`: rewrites all Luau sources with StyLua.

local Paths = require("./lib/Paths")
local Shell = require("./lib/Shell")

local targets = table.clone(Paths.GAME_SOURCES)
table.move(Paths.TOOLING_SOURCES, 1, #Paths.TOOLING_SOURCES, #targets + 1, targets)

Shell.runSteps("Format", {
	{
		name = "StyLua",
		run = function()
			return Shell.exec("stylua", targets)
		end,
	},
})
