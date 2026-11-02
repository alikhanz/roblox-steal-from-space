--!strict
-- `lune run content`: validates game content that the type checker cannot (localization for now).

local process = require("@lune/process")

local Shell = require("./lib/Shell")
local Strings = require("../src/shared/Locale/Strings")
local StringsValidator = require("./lib/StringsValidator")

local strings = Strings :: { [string]: any }

local problems = StringsValidator.validate(strings)
if #problems > 0 then
	for _, problem in problems do
		Shell.fail(problem)
	end
	Shell.fail(`{#problems} localization problem(s)`)
	process.exit(1)
end

local count = 0
for _ in strings do
	count += 1
end
Shell.success(`Localization: {count} strings OK`)
