--!strict
-- `lune run install`: installs packages and generates everything the editor and checks need.
-- Safe to run repeatedly.

local fs = require("@lune/fs")
local net = require("@lune/net")

local Paths = require("./lib/Paths")
local Shell = require("./lib/Shell")

local function installedDefinitionsVersion(): string?
	if not fs.isFile(Paths.ROBLOX_DEFINITIONS_VERSION) then
		return nil
	end
	return fs.readFile(Paths.ROBLOX_DEFINITIONS_VERSION)
end

local function fetchRobloxDefinitions(): boolean
	if fs.isFile(Paths.ROBLOX_DEFINITIONS) and installedDefinitionsVersion() == Paths.LUAU_LSP_VERSION then
		print(`Roblox definitions {Paths.LUAU_LSP_VERSION} are up to date`)
		return true
	end

	local url =
		`https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/{Paths.LUAU_LSP_VERSION}/scripts/globalTypes.d.luau`
	local response = net.request(url)
	if not response.ok then
		Shell.fail(`Could not download Roblox definitions ({response.statusCode}): {url}`)
		return false
	end

	if not fs.isDir(Paths.TYPES_DIR) then
		fs.writeDir(Paths.TYPES_DIR)
	end
	fs.writeFile(Paths.ROBLOX_DEFINITIONS, response.body)
	fs.writeFile(Paths.ROBLOX_DEFINITIONS_VERSION, Paths.LUAU_LSP_VERSION)
	print(`Downloaded Roblox definitions {Paths.LUAU_LSP_VERSION}`)
	return true
end

local function fixPackageTypes(): boolean
	for _, dir in Paths.PACKAGE_DIRS do
		if fs.isDir(dir) and not Shell.exec("wally-package-types", { "--sourcemap", Paths.SOURCEMAP, `{dir}/` }) then
			return false
		end
	end
	return true
end

Shell.runSteps("Install", {
	{
		name = "Wally packages",
		run = function()
			return Shell.exec("wally", { "install" })
		end,
	},
	{ name = "Roblox type definitions", run = fetchRobloxDefinitions },
	{
		name = "Network code (Zap)",
		run = function()
			return Shell.exec("zap", { Paths.NET_CONTRACT })
		end,
	},
	{
		name = "Sourcemap",
		run = function()
			return Shell.exec("rojo", { "sourcemap", Paths.PROJECT_FILE, "--output", Paths.SOURCEMAP })
		end,
	},
	{ name = "Package type exports", run = fixPackageTypes },
})
