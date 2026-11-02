--!strict
-- Minimal test framework for pure-logic specs that run under Lune.
-- Specs register cases with `describe`/`it`; `lune/test.luau` collects and runs them.

export type Matchers = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeCloseTo: (expected: number, epsilon: number?) -> (),
	toBeNil: () -> (),
	toBeTruthy: () -> (),
	toThrow: (substring: string?) -> (),
}

export type Expectation = Matchers & { never: Matchers }

export type Case = {
	name: string,
	run: () -> (),
}

local DEFAULT_EPSILON = 1e-9
-- Error level that points at the spec line calling the matcher: check -> matcher -> spec.
local SPEC_ERROR_LEVEL = 3

local Test = {}

local pendingCases: { Case } = {}
local scopeNames: { string } = {}

local function describeValue(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	if type(value) ~= "table" then
		return tostring(value)
	end
	local parts = {}
	for key, item in value do
		table.insert(parts, `{tostring(key)} = {describeValue(item)}`)
	end
	table.sort(parts)
	return `\{ {table.concat(parts, ", ")} \}`
end

local function deepEqual(left: any, right: any): boolean
	if left == right then
		return true
	end
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	for key, value in left do
		if not deepEqual(value, right[key]) then
			return false
		end
	end
	for key in right do
		if left[key] == nil then
			return false
		end
	end
	return true
end

local function makeMatchers(actual: any, negated: boolean): Matchers
	local function check(passed: boolean, expectation: string)
		if passed == negated then
			local prefix = if negated then "Expected not" else "Expected"
			error(`{prefix}: {expectation}`, SPEC_ERROR_LEVEL)
		end
	end

	return {
		toBe = function(expected: any)
			check(actual == expected, `{describeValue(actual)} to be {describeValue(expected)}`)
		end,
		toEqual = function(expected: any)
			check(deepEqual(actual, expected), `{describeValue(actual)} to equal {describeValue(expected)}`)
		end,
		toBeCloseTo = function(expected: number, epsilon: number?)
			local tolerance = epsilon or DEFAULT_EPSILON
			local close = type(actual) == "number" and math.abs(actual - expected) <= tolerance
			check(close, `{describeValue(actual)} to be within {tolerance} of {expected}`)
		end,
		toBeNil = function()
			check(actual == nil, `{describeValue(actual)} to be nil`)
		end,
		toBeTruthy = function()
			check(not not actual, `{describeValue(actual)} to be truthy`)
		end,
		toThrow = function(substring: string?)
			local ok, err = pcall(actual)
			local matches = substring == nil or string.find(tostring(err), substring, 1, true) ~= nil
			local suffix = if substring then ` containing {describeValue(substring)}` else ""
			check(not ok and matches, `function to throw{suffix}, got {if ok then "no error" else tostring(err)}`)
		end,
	}
end

function Test.describe(name: string, body: () -> ())
	table.insert(scopeNames, name)
	body()
	table.remove(scopeNames)
end

function Test.it(name: string, run: () -> ())
	local prefix = if #scopeNames > 0 then table.concat(scopeNames, " > ") .. " > " else ""
	table.insert(pendingCases, { name = prefix .. name, run = run })
end

function Test.expect(actual: any): Expectation
	local expectation = makeMatchers(actual, false) :: any
	expectation.never = makeMatchers(actual, true)
	return expectation
end

-- Hands registered cases to the runner and resets the registry for the next spec file.
function Test.takeCases(): { Case }
	local cases = pendingCases
	pendingCases = {}
	return cases
end

return Test
