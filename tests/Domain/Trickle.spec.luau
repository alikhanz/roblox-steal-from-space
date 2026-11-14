--!strict

local BigNum = require("../../src/shared/Domain/BigNum")
local Test = require("../../lune/lib/Test")
local Trickle = require("../../src/shared/Domain/Trickle")
local describe, it, expect = Test.describe, Test.it, Test.expect

local function n(value: number): BigNum.BigNum
	return BigNum.fromNumber(value)
end

local function takeAll(trickle: Trickle.Trickle): { number }
	local pieces = {}
	while true do
		local piece = Trickle.take(trickle)
		if not piece then
			return pieces
		end
		table.insert(pieces, BigNum.toNumber(piece))
	end
end

describe("Trickle", function()
	it("shows nothing until a gain is told", function()
		expect(Trickle.take(Trickle.new())).toBe(nil)
	end)

	it("splits a gain into even pieces", function()
		local trickle = Trickle.new()
		Trickle.add(trickle, n(2000), 4)
		local pieces = takeAll(trickle)
		expect(#pieces).toBe(4)
		for _, piece in pieces do
			expect(piece).toBeCloseTo(500, 1e-9)
		end
	end)

	it("adds what is still unshown to the next gain", function()
		local trickle = Trickle.new()
		Trickle.add(trickle, n(2000), 4)
		Trickle.take(trickle)
		Trickle.take(trickle)
		-- 1000 left unshown joins the next 2000.
		Trickle.add(trickle, n(2000), 4)
		local pieces = takeAll(trickle)
		expect(#pieces).toBe(4)
		expect(pieces[1]).toBeCloseTo(750, 1e-9)
		local total = 0
		for _, piece in pieces do
			total += piece
		end
		expect(total).toBeCloseTo(3000, 1e-9)
	end)

	it("works on numbers far past a double's digits", function()
		local trickle = Trickle.new()
		Trickle.add(trickle, BigNum.new(4, 40), 4)
		local piece = Trickle.take(trickle) :: BigNum.BigNum
		expect(BigNum.log10(piece)).toBeCloseTo(40, 1e-9)
	end)

	it("shows a gain whole for a single piece", function()
		local trickle = Trickle.new()
		Trickle.add(trickle, n(7), 0)
		expect(takeAll(trickle)).toEqual({ 7 })
	end)
end)
