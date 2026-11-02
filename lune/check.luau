--!strict
-- `lune run check`: the single quality gate. Run it before every commit.
-- Order: format -> lint -> types (game) -> types (tooling) -> tests -> build.

local fs = require("@lune/fs")

local Paths = require("./lib/Paths")
local Shell = require("./lib/Shell")

local function concat(...: { string }): { string }
	local result = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #result + 1, result)
	end
	return result
end

local ALL_SOURCES = concat(Paths.GAME_SOURCES, Paths.TOOLING_SOURCES)

-- Generated and third-party code is not ours to type-check.
local ANALYZE_IGNORES = {
	"--ignore=Packages/**",
	"--ignore=ServerPackages/**",
	"--ignore=**/Net/Remotes.luau",
}

Shell.requireInstalled(concat(Paths.PACKAGE_DIRS, { Paths.ROBLOX_DEFINITIONS }))

Shell.runSteps("Check", {
	{
		name = "Format (StyLua)",
		run = function()
			return Shell.exec("stylua", concat({ "--check" }, ALL_SOURCES))
		end,
	},
	{
		name = "Lint (Selene)",
		run = function()
			return Shell.exec("selene", concat({ "--quiet" }, ALL_SOURCES))
		end,
	},
	{
		name = "Sourcemap",
		run = function()
			return Shell.exec("rojo", { "sourcemap", Paths.PROJECT_FILE, "--output", Paths.SOURCEMAP })
		end,
	},
	{
		name = "Types: game (luau-lsp, Roblox)",
		run = function()
			return Shell.exec(
				"luau-lsp",
				concat({
					"analyze",
					"--platform=roblox",
					`--sourcemap={Paths.SOURCEMAP}`,
					`--definitions=@roblox={Paths.ROBLOX_DEFINITIONS}`,
					"--flag:LuauSolverV2=true",
				}, ANALYZE_IGNORES, Paths.GAME_SOURCES)
			)
		end,
	},
	{
		name = "Types: tooling and tests (luau-lsp, Lune)",
		run = function()
			return Shell.exec(
				"luau-lsp",
				concat({ "analyze", "--platform=standard", "--flag:LuauSolverV2=true" }, Paths.TOOLING_SOURCES)
			)
		end,
	},
	{
		name = "Tests (Lune)",
		run = function()
			return Shell.exec("lune", { "run", "test" })
		end,
	},
	{
		name = "Build (Rojo)",
		run = function()
			if not fs.isDir(Paths.BUILD_DIR) then
				fs.writeDir(Paths.BUILD_DIR)
			end
			return Shell.exec("rojo", { "build", Paths.PROJECT_FILE, "--output", Paths.BUILD_FILE })
		end,
	},
})
