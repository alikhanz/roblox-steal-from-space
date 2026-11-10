--!strict

local Test = require("../../lune/lib/Test")
local ZoneBlend = require("../../src/shared/Domain/ZoneBlend")
local ZoneConfig = require("../../src/shared/Config/ZoneConfig")
local describe, it, expect = Test.describe, Test.it, Test.expect

local DEBRIS = ZoneConfig.ZONES.DebrisBelt
local ICE = ZoneConfig.ZONES.IceRings
local HORIZON = ZoneConfig.ZONES.EventHorizon

describe("ZoneBlend", function()
	it("is the zone itself inside its ring", function()
		local blend = ZoneBlend.at((ICE.ringMin + ICE.ringMax) / 2)
		expect(blend.inner).toBe("IceRings")
		expect(blend.outer).toBe("IceRings")
		expect(blend.t).toBe(0)
	end)

	it("is the first zone before its ring and the last past the edge", function()
		expect(ZoneBlend.at(0).inner).toBe("DebrisBelt")
		expect(ZoneBlend.at(DEBRIS.ringMin - 50).t).toBe(0)
		local past = ZoneBlend.at(HORIZON.ringMax + 500)
		expect(past.inner).toBe("EventHorizon")
		expect(past.t).toBe(0)
	end)

	it("gives way evenly across the gap between two rings", function()
		local middle = ZoneBlend.at((DEBRIS.ringMax + ICE.ringMin) / 2)
		expect(middle.inner).toBe("DebrisBelt")
		expect(middle.outer).toBe("IceRings")
		expect(math.abs(middle.t - 0.5) < 1e-9).toBe(true)
		expect(ZoneBlend.at(DEBRIS.ringMax).t).toBe(0)
		expect(ZoneBlend.at(ICE.ringMin).inner).toBe("IceRings")
	end)

	it("picks the outer zone as often as it is far into the gap", function()
		local quarter = DEBRIS.ringMax + (ICE.ringMin - DEBRIS.ringMax) / 4
		expect(ZoneBlend.pick(quarter, 0.2)).toBe("IceRings")
		expect(ZoneBlend.pick(quarter, 0.3)).toBe("DebrisBelt")
	end)
end)
