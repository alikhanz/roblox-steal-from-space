--!strict

local SoundVoices = require("../../src/shared/Domain/SoundVoices")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local RULES: SoundVoices.Rules = { maxVoices = 3, maxCopies = 2, repeatSeconds = 0.1 }

local function voice(name: string, priority: number, startedAt: number): SoundVoices.Voice
	return { name = name, priority = priority, startedAt = startedAt }
end

describe("SoundVoices.admit", function()
	it("plays while there are free voices", function()
		local admission = SoundVoices.admit({ voice("Click", 1, 0) }, "Hatch", 4, 1, RULES)
		expect(admission.play).toBe(true)
		expect(admission.evict).toBe(nil)
	end)

	it("does not start the same sound again too soon", function()
		local admission = SoundVoices.admit({ voice("StrikeHit", 3, 1) }, "StrikeHit", 3, 1.05, RULES)
		expect(admission.play).toBe(false)
		expect(SoundVoices.admit({ voice("StrikeHit", 3, 1) }, "StrikeHit", 3, 1.1, RULES).play).toBe(true)
	end)

	it("replaces the oldest copy once a sound has all its copies", function()
		local voices = { voice("BombBoom", 3, 2), voice("BombBoom", 3, 1) }
		local admission = SoundVoices.admit(voices, "BombBoom", 3, 5, RULES)
		expect(admission.play).toBe(true)
		expect(admission.evict).toBe(2)
	end)

	it("when full, stops the least important voice for a more important sound", function()
		local voices = { voice("AlarmLoop", 6, 0), voice("JetLoop", 2, 1), voice("Toast", 1, 2) }
		local admission = SoundVoices.admit(voices, "HitMe", 5, 3, RULES)
		expect(admission.play).toBe(true)
		expect(admission.evict).toBe(3)
	end)

	it("when full, stops the oldest of equally unimportant voices", function()
		local voices = { voice("A", 2, 5), voice("B", 2, 1), voice("C", 4, 0) }
		expect(SoundVoices.admit(voices, "D", 3, 6, RULES).evict).toBe(2)
	end)

	it("when full of voices that matter as much or more, stays silent", function()
		local voices = { voice("A", 3, 0), voice("B", 4, 0), voice("C", 5, 0) }
		local admission = SoundVoices.admit(voices, "D", 3, 1, RULES)
		expect(admission.play).toBe(false)
		expect(admission.evict).toBe(nil)
	end)
end)

describe("SoundVoices.nearest", function()
	it("keeps the nearest within reach, nearest first", function()
		local items = { 50, 10, 80, 30, 5 }
		local chosen = SoundVoices.nearest(items, function(distance)
			return distance
		end, 2, 60)
		expect(#chosen).toBe(2)
		expect(chosen[1]).toBe(5)
		expect(chosen[2]).toBe(10)
	end)

	it("leaves out everything beyond reach", function()
		local chosen = SoundVoices.nearest({ 70, 90 }, function(distance)
			return distance
		end, 2, 60)
		expect(#chosen).toBe(0)
	end)
end)

describe("SoundVoices.oxygenBeepInterval", function()
	local BEEP: SoundVoices.OxygenBeep = { below = 0.25, slowest = 1.2, fastest = 0.3 }

	it("is silent while there is enough oxygen", function()
		expect(SoundVoices.oxygenBeepInterval(0.25, BEEP)).toBe(nil)
		expect(SoundVoices.oxygenBeepInterval(0.9, BEEP)).toBe(nil)
	end)

	it("beeps faster as the tank empties", function()
		expect(SoundVoices.oxygenBeepInterval(0.2499, BEEP) :: number).toBeCloseTo(1.2, 1e-3)
		expect(SoundVoices.oxygenBeepInterval(0.125, BEEP) :: number).toBeCloseTo(0.75, 1e-9)
		expect(SoundVoices.oxygenBeepInterval(0, BEEP) :: number).toBeCloseTo(0.3, 1e-9)
	end)
end)

describe("SoundVoices.jetMix", function()
	local JET: SoundVoices.Jet = { idleVolume = 0.2, fullVolume = 0.6, idleSpeed = 0.9, fullSpeed = 1.3 }

	it("runs from the hover's hiss to the full one", function()
		local volume, speed = SoundVoices.jetMix(0, JET)
		expect(volume).toBeCloseTo(0.2, 1e-9)
		expect(speed).toBeCloseTo(0.9, 1e-9)
		volume, speed = SoundVoices.jetMix(0.5, JET)
		expect(volume).toBeCloseTo(0.4, 1e-9)
		expect(speed).toBeCloseTo(1.1, 1e-9)
	end)

	it("keeps thrust within 0..1", function()
		local volume, speed = SoundVoices.jetMix(2, JET)
		expect(volume).toBeCloseTo(0.6, 1e-9)
		expect(speed).toBeCloseTo(1.3, 1e-9)
	end)
end)

describe("SoundVoices.approachLevel", function()
	local CHASE: SoundVoices.Chase = {
		nearSeconds = 1,
		farSeconds = 5,
		nearDistance = 10,
		farDistance = 110,
		quietShare = 0.3,
		slowSpeed = 1,
		fastSpeed = 1.3,
		easeSeconds = 0.25,
	}

	it("is nothing for a guardian far behind and falling back", function()
		expect(SoundVoices.approachLevel(300, -5, CHASE)).toBe(0)
		expect(SoundVoices.approachLevel(300, 0, CHASE)).toBe(0)
	end)

	it("grows as the time for the guardian to reach the thief shrinks", function()
		expect(SoundVoices.approachLevel(500, 100, CHASE)).toBe(0)
		expect(SoundVoices.approachLevel(300, 100, CHASE)).toBeCloseTo(0.5, 1e-9)
		expect(SoundVoices.approachLevel(150, 200, CHASE)).toBe(1)
	end)

	it("is loud right behind the thief even when level with them", function()
		expect(SoundVoices.approachLevel(5, 0, CHASE)).toBe(1)
		expect(SoundVoices.approachLevel(60, 0, CHASE)).toBeCloseTo(0.5, 1e-9)
	end)

	it("mixes the siren from quiet and slow to full and quick", function()
		local volume, speed = SoundVoices.chaseMix(0, CHASE)
		expect(volume).toBeCloseTo(0.3, 1e-9)
		expect(speed).toBeCloseTo(1, 1e-9)
		volume, speed = SoundVoices.chaseMix(1, CHASE)
		expect(volume).toBeCloseTo(1, 1e-9)
		expect(speed).toBeCloseTo(1.3, 1e-9)
	end)
end)

describe("SoundVoices.tierSpeed", function()
	it("sounds higher for a rarer tier", function()
		expect(SoundVoices.tierSpeed(1, 5, 1, 1.2)).toBeCloseTo(1, 1e-9)
		expect(SoundVoices.tierSpeed(3, 5, 1, 1.2)).toBeCloseTo(1.1, 1e-9)
		expect(SoundVoices.tierSpeed(5, 5, 1, 1.2)).toBeCloseTo(1.2, 1e-9)
	end)

	it("copes with a single tier", function()
		expect(SoundVoices.tierSpeed(1, 1, 1, 1.2)).toBe(1)
	end)
end)
