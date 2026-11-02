--!strict

local Tables = require("../../src/shared/Runtime/Tables")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Tables.deepCopy", function()
	it("copies nested tables independently", function()
		local original = { a = 1, nested = { b = 2 } }
		local copy = Tables.deepCopy(original)
		copy.nested.b = 3

		expect(original.nested.b).toBe(2)
		expect(copy).toEqual({ a = 1, nested = { b = 3 } })
	end)

	it("produces editable copies of frozen tables", function()
		local copy = Tables.deepCopy(table.freeze({ value = 1 })) :: any
		copy.value = 2
		expect(copy.value).toBe(2)
	end)
end)

describe("Tables.reconcile", function()
	it("fills missing keys, including nested ones", function()
		local target: { [any]: any } = { coins = 5, stats = { thrust = 2 } }
		Tables.reconcile(target, { coins = 0, stats = { thrust = 1, oxygen = 1 }, pods = {} })

		expect(target).toEqual({ coins = 5, stats = { thrust = 2, oxygen = 1 }, pods = {} })
	end)

	it("copies template values instead of sharing them", function()
		local template = { pods = {} }
		local target: { [any]: any } = {}
		Tables.reconcile(target, template)
		target.pods.extra = true

		expect(template.pods).toEqual({})
	end)
end)

describe("Tables.replaceContents", function()
	it("keeps the target table but swaps its contents", function()
		local target: { [any]: any } = { old = 1 }
		local reference = target
		Tables.replaceContents(target, { new = 2 })

		expect(reference).toBe(target)
		expect(target).toEqual({ new = 2 })
	end)
end)
