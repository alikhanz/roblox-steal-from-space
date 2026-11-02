--!strict
-- Upgrades saved data one schema version at a time: steps[N] turns version N into N + 1.
-- Run it on a copy: a failing step may leave the table half-migrated.

export type Step = (data: { [string]: any }) -> ()
export type Status = "Ok" | "NewerVersion" | "InvalidVersion" | "MissingStep" | "StepFailed"

local Migrations = {}

function Migrations.run(data: { [string]: any }, steps: { [number]: Step }, targetVersion: number): (Status, string?)
	local version = data.schemaVersion
	if type(version) ~= "number" or version % 1 ~= 0 or version < 1 then
		return "InvalidVersion", `schemaVersion is {tostring(version)}`
	end
	if version > targetVersion then
		return "NewerVersion", `schemaVersion {version} is newer than {targetVersion}`
	end

	while version < targetVersion do
		local step = steps[version]
		if not step then
			return "MissingStep", `no migration from v{version}`
		end
		local ok, err = pcall(step, data)
		if not ok then
			return "StepFailed", `v{version} -> v{version + 1}: {err}`
		end
		version += 1
		data.schemaVersion = version
	end
	return "Ok", nil
end

return table.freeze(Migrations)
