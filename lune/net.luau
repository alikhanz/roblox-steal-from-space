--!strict
-- `lune run net`: regenerates the Zap networking modules after editing net/remotes.zap.

local Paths = require("./lib/Paths")
local Shell = require("./lib/Shell")

Shell.runSteps("Net", {
	{
		name = "Network code (Zap)",
		run = function()
			return Shell.exec("zap", { Paths.NET_CONTRACT })
		end,
	},
})
