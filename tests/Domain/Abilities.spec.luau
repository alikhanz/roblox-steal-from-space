--!strict

local Abilities = require("../../src/shared/Domain/Abilities")
local PvpConfig = require("../../src/shared/Config/PvpConfig")
local PvpFx = require("../../src/shared/Domain/PvpFx")
local Test = require("../../lune/lib/Test")
local describe, it, expect = Test.describe, Test.it, Test.expect

local ORIGIN = { x = 0, y = 0, z = 0 }
local FORWARD = { x = 0, y = 0, z = -1 }

describe("Abilities.isReady", function()
	it("is ready when never used or once the cooldown passed", function()
		expect(Abilities.isReady(0, 5, 3)).toBe(true)
		expect(Abilities.isReady(10, 12, 3)).toBe(false)
		expect(Abilities.isReady(10, 13, 3)).toBe(true)
	end)
end)

describe("Abilities.isInCone", function()
	it("hits ahead within reach and angle, misses behind, beside and far", function()
		expect(Abilities.isInCone(ORIGIN, FORWARD, { x = 0, y = 0, z = -5 }, 9, math.rad(35))).toBe(true)
		expect(Abilities.isInCone(ORIGIN, FORWARD, { x = 3, y = 0, z = -5 }, 9, math.rad(35))).toBe(true)
		expect(Abilities.isInCone(ORIGIN, FORWARD, { x = 5, y = 0, z = -5 }, 9, math.rad(35))).toBe(false)
		expect(Abilities.isInCone(ORIGIN, FORWARD, { x = 0, y = 0, z = 5 }, 9, math.rad(35))).toBe(false)
		expect(Abilities.isInCone(ORIGIN, FORWARD, { x = 0, y = 0, z = -10 }, 9, math.rad(35))).toBe(false)
		expect(Abilities.isInCone(ORIGIN, FORWARD, ORIGIN, 9, math.rad(35))).toBe(true)
	end)

	it("does not care about the facing vector's length", function()
		local longFacing = { x = 0, y = 0, z = -40 }
		expect(Abilities.isInCone(ORIGIN, longFacing, { x = 2, y = 0, z = -6 }, 9, math.rad(35))).toBe(true)
	end)
end)

describe("Abilities.nearestInCone", function()
	it("picks the nearest target in the cone", function()
		local targets = {
			{ id = "far", position = { x = 0, y = 0, z = -8 } },
			{ id = "near", position = { x = 1, y = 0, z = -3 } },
			{ id = "beside", position = { x = 8, y = 0, z = -1 } },
		}
		expect(Abilities.nearestInCone(ORIGIN, FORWARD, targets, 9, math.rad(35))).toBe("near")
		expect(Abilities.nearestInCone(ORIGIN, FORWARD, {}, 9, math.rad(35))).toBeNil()
	end)
end)

describe("Abilities.bestInCone", function()
	local REACH = 70
	local HALF_ANGLE = math.rad(18)

	it("picks the target nearest the crosshair over a nearer one off to the side", function()
		local targets = {
			-- 5 studs off the aim at 60: about 5 degrees.
			{ id = "onAim", position = { x = 5, y = 0, z = -60 } },
			-- 8 studs off the aim at 30: about 15 degrees.
			{ id = "aside", position = { x = 8, y = 0, z = -30 } },
		}
		expect(Abilities.bestInCone(ORIGIN, FORWARD, targets, REACH, HALF_ANGLE)).toBe("onAim")
	end)

	it("prefers the much nearer one when both are about as near the crosshair", function()
		local targets = {
			{ id = "far", position = { x = 0, y = 0, z = -65 } },
			{ id = "near", position = { x = 1, y = 0, z = -15 } },
		}
		expect(Abilities.bestInCone(ORIGIN, FORWARD, targets, REACH, HALF_ANGLE)).toBe("near")
	end)

	it("ignores targets outside the cone or the reach", function()
		local targets = {
			{ id = "wide", position = { x = 30, y = 0, z = -30 } },
			{ id = "behind", position = { x = 0, y = 0, z = 10 } },
			{ id = "beyond", position = { x = 0, y = 0, z = -80 } },
		}
		expect(Abilities.bestInCone(ORIGIN, FORWARD, targets, REACH, HALF_ANGLE)).toBeNil()
		expect(Abilities.bestInCone(ORIGIN, FORWARD, {}, REACH, HALF_ANGLE)).toBeNil()
	end)

	it("finds a target the old narrow harpoon cone missed", function()
		-- 12 degrees off the aim: outside 8, inside 18.
		local angle = math.rad(12)
		local targets =
			{ { id = "carrier", position = { x = 40 * math.sin(angle), y = 0, z = -40 * math.cos(angle) } } }
		expect(Abilities.nearestInCone(ORIGIN, FORWARD, targets, 50, math.rad(8))).toBeNil()
		expect(Abilities.bestInCone(ORIGIN, FORWARD, targets, REACH, HALF_ANGLE)).toBe("carrier")
	end)
end)

describe("Abilities.isInLaggedCone", function()
	local REACH = 90
	local HALF_ANGLE = math.rad(18)

	it("is the plain cone without slack", function()
		expect(Abilities.isInLaggedCone(ORIGIN, FORWARD, { x = 5, y = 0, z = -40 }, REACH, HALF_ANGLE, 0)).toBe(true)
		expect(Abilities.isInLaggedCone(ORIGIN, FORWARD, { x = 20, y = 0, z = -40 }, REACH, HALF_ANGLE, 0)).toBe(false)
		expect(Abilities.isInLaggedCone(ORIGIN, FORWARD, { x = 0, y = 0, z = -95 }, REACH, HALF_ANGLE, 0)).toBe(false)
	end)

	it("lets a lock stand when the server sees the target a lag's flight aside", function()
		-- Crossing at 150 studs/s, seen 0.2 s late: 30 studs aside at 40 studs, well out of 18°.
		local seenByServer = { x = 30, y = 0, z = -40 }
		local slack = Abilities.lockSlack(0, 150, 0.3, 6, 40)
		expect(Abilities.isInLaggedCone(ORIGIN, FORWARD, seenByServer, REACH, HALF_ANGLE, 0)).toBe(false)
		expect(Abilities.isInLaggedCone(ORIGIN, FORWARD, seenByServer, REACH, HALF_ANGLE, slack)).toBe(true)
	end)

	it("lets a lock stand a little past the reach and just behind", function()
		expect(Abilities.isInLaggedCone(ORIGIN, FORWARD, { x = 0, y = 0, z = -100 }, REACH, HALF_ANGLE, 20)).toBe(true)
		expect(Abilities.isInLaggedCone(ORIGIN, FORWARD, { x = 0, y = 0, z = 10 }, REACH, HALF_ANGLE, 20)).toBe(true)
	end)

	it("refuses a lock on someone far off the aim or behind", function()
		local slack = 40
		expect(Abilities.isInLaggedCone(ORIGIN, FORWARD, { x = 80, y = 0, z = -20 }, REACH, HALF_ANGLE, slack)).toBe(
			false
		)
		expect(Abilities.isInLaggedCone(ORIGIN, FORWARD, { x = 0, y = 0, z = 60 }, REACH, HALF_ANGLE, slack)).toBe(
			false
		)
		expect(Abilities.isInLaggedCone(ORIGIN, FORWARD, { x = 0, y = 0, z = -140 }, REACH, HALF_ANGLE, slack)).toBe(
			false
		)
	end)
end)

describe("Abilities.lockSlack", function()
	it("grows with both speeds and stops at the cap", function()
		expect(Abilities.lockSlack(0, 0, 0.3, 6, 40)).toBe(6)
		expect(Abilities.lockSlack(50, 30, 0.25, 6, 40)).toBe(26)
		expect(Abilities.lockSlack(250, 250, 0.3, 6, 40)).toBe(40)
	end)
end)

describe("Abilities.waveStep", function()
	local WAVE = PvpConfig.BOMB_WAVE
	local RADIUS = PvpConfig.BOMB.radiusStuds
	local STEP = 1 / 60

	-- Sweeps a blast at the origin as PvpService does: the whole radius at once, then the ring
	-- every frame while it strikes. `positionAt(seconds)` places each target. Returns when each
	-- was struck, in seconds after the blast.
	local function sweep(positionAt: { [string]: (number) -> Abilities.Vector }): { [string]: number }
		local struck: { [string]: boolean } = {}
		local at: { [string]: number } = {}
		local function step(elapsed: number, radius: number)
			local targets = {}
			for id, place in positionAt do
				table.insert(targets, { id = id, position = place(elapsed) })
			end
			for _, id in Abilities.waveStep(ORIGIN, targets, radius, struck) do
				at[id] = elapsed
			end
		end
		step(0, RADIUS)
		local elapsed = 0
		while true do
			elapsed += STEP
			local reach = PvpFx.waveReach(elapsed, RADIUS, WAVE)
			if not reach then
				break
			end
			step(elapsed, reach)
		end
		return at
	end

	local function still(x: number): (number) -> Abilities.Vector
		return function()
			return { x = x, y = 0, z = 0 }
		end
	end

	local function flying(fromX: number, speed: number): (number) -> Abilities.Vector
		return function(seconds)
			return { x = fromX - speed * seconds, y = 0, z = 0 }
		end
	end

	it("strikes everyone in the radius at the blast, each once", function()
		local at = sweep({ inside = still(RADIUS - 1), outside = still(RADIUS + 5) })
		expect(at.inside).toBe(0)
		expect(at.outside).toBeNil()
	end)

	it("strikes whoever flies into the ring while it lives", function()
		-- 40 studs out, flying in at 100: inside the radius after 0.15 s, before the wave fades.
		local at = sweep({ late = flying(RADIUS + 15, 100) })
		expect(at.late ~= nil and at.late > 0).toBe(true)
	end)

	it("misses whoever reaches the spot after the wave", function()
		local at = sweep({ tooLate = flying(RADIUS + 60, 100) })
		expect(at.tooLate).toBeNil()
	end)

	it("never strikes the same target twice", function()
		local struck: { [string]: boolean } = {}
		local targets = { { id = "a", position = { x = 1, y = 0, z = 0 } } }
		expect(Abilities.waveStep(ORIGIN, targets, 5, struck)).toEqual({ "a" })
		expect(Abilities.waveStep(ORIGIN, targets, 5, struck)).toEqual({})
	end)
end)

describe("Abilities.withinRadius", function()
	it("lists everyone inside the radius", function()
		local targets = {
			{ id = "a", position = { x = 10, y = 0, z = 0 } },
			{ id = "b", position = { x = 0, y = 30, z = 0 } },
			{ id = "c", position = { x = 0, y = 0, z = 25 } },
		}
		expect(Abilities.withinRadius(ORIGIN, targets, 25)).toEqual({ "a", "c" })
	end)
end)

describe("Abilities.stepStrike", function()
	local STRIKE: Abilities.Strike = {
		lungeSeconds = 0.25,
		lungeExtraSpeed = 40,
		contactStuds = 6,
		contactHalfAngleRadians = math.rad(70),
		cooldownSeconds = 1.5,
	}
	local IDLE: Abilities.StrikeTimers = { lungeLeft = 0, cooldownLeft = 0 }

	it("starts a lunge when wanted and ready", function()
		local timers, started = Abilities.stepStrike(IDLE, true, 1 / 60, STRIKE)
		expect(started).toBe(true)
		expect(timers.lungeLeft).toBe(0.25)
		expect(timers.cooldownLeft).toBe(1.5)
	end)

	it("does nothing when not wanted", function()
		local timers, started = Abilities.stepStrike(IDLE, false, 1 / 60, STRIKE)
		expect(started).toBe(false)
		expect(timers.lungeLeft).toBe(0)
	end)

	it("counts the lunge down to zero and does not restart it during the cooldown", function()
		local timers = { lungeLeft = 0.1, cooldownLeft = 1.3 }
		local next1, started = Abilities.stepStrike(timers, true, 0.2, STRIKE)
		expect(started).toBe(false)
		expect(next1.lungeLeft).toBe(0)
		expect(next1.cooldownLeft).toBeCloseTo(1.1, 1e-9)
	end)

	it("strikes again once the cooldown is over while held", function()
		local _, started = Abilities.stepStrike({ lungeLeft = 0, cooldownLeft = 0.01 }, true, 0.02, STRIKE)
		expect(started).toBe(true)
	end)
end)

describe("Abilities.nearestPoint", function()
	it("meets a round body at its surface toward the attacker", function()
		local point = Abilities.nearestPoint({ x = 0, y = 0, z = -20 }, 5, ORIGIN)
		expect(point.x).toBeCloseTo(0)
		expect(point.z).toBeCloseTo(-15)
	end)

	it("is the attacker itself inside the body, and the middle of a point body", function()
		local inside = { x = 1, y = 0, z = -18 }
		expect(Abilities.nearestPoint({ x = 0, y = 0, z = -20 }, 5, inside)).toEqual(inside)
		local point = Abilities.nearestPoint({ x = 0, y = 0, z = -20 }, 0, ORIGIN)
		expect(point.z).toBeCloseTo(-20)
	end)
end)
