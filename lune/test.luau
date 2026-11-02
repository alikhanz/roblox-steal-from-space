--!strict
-- `lune run test [filter]`: runs every tests/**/*.spec.luau whose path contains `filter`.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Paths = require("./lib/Paths")
local Shell = require("./lib/Shell")
local Test = require("./lib/Test")

local function findSpecs(dir: string, found: { string })
	for _, entry in fs.readDir(dir) do
		local path = `{dir}/{entry}`
		if fs.isDir(path) then
			findSpecs(path, found)
		elseif string.sub(path, -#Paths.TEST_SUFFIX) == Paths.TEST_SUFFIX then
			table.insert(found, path)
		end
	end
end

local filter = process.args[1]
local specs: { string } = {}
findSpecs(Paths.TESTS_DIR, specs)
table.sort(specs)

local passed, failed = 0, 0

for _, spec in specs do
	if filter and not string.find(spec, filter, 1, true) then
		continue
	end

	-- Requires resolve relative to this script, which lives one level below the project root.
	local modulePath = "../" .. string.sub(spec, 1, -#".luau" - 1)
	local loaded, loadError = pcall((require :: any) :: (string) -> any, modulePath)
	if not loaded then
		failed += 1
		Shell.fail(`✗ {spec}: failed to load\n    {loadError}`)
		continue
	end

	for _, case in Test.takeCases() do
		local ok, caseError = pcall(case.run)
		if ok then
			passed += 1
		else
			failed += 1
			Shell.fail(`✗ {spec} :: {case.name}\n    {caseError}`)
		end
	end
end

if failed > 0 then
	Shell.fail(`{failed} failed, {passed} passed`)
	process.exit(1)
end
Shell.success(`{passed} passed`)
