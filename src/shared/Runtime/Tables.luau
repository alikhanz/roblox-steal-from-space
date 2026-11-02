--!strict
-- Table helpers for plain data (saved profiles, configs). Pure Luau.

local Tables = {}

-- Copies nested tables; the copy is never frozen, so it can be edited.
function Tables.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		-- The type refinement above does not flow back into T, hence the cast.
		return value :: any
	end
	local copy = {}
	for key, item in value :: any do
		copy[key] = Tables.deepCopy(item)
	end
	return copy :: any
end

-- Fills keys that are nil in `target` with copies from `template`, recursing into tables both share.
-- Never overwrites or removes existing values.
function Tables.reconcile(target: { [any]: any }, template: { [any]: any })
	for key, templateValue in template do
		local current = target[key]
		if current == nil then
			target[key] = Tables.deepCopy(templateValue)
		elseif type(current) == "table" and type(templateValue) == "table" and not table.isfrozen(current) then
			Tables.reconcile(current, templateValue)
		end
	end
end

-- Makes `target` hold exactly the keys of `source`, keeping the `target` table itself.
-- Used where another system holds a reference to `target` (e.g. ProfileStore's Profile.Data).
function Tables.replaceContents(target: { [any]: any }, source: { [any]: any })
	table.clear(target)
	for key, value in source do
		target[key] = value
	end
end

return table.freeze(Tables)
