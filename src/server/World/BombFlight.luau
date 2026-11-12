--!strict
-- The gravity bomb's flight on the server: a point, no part. Every client draws the bomb from the
-- throw it is told about (World/BombVisual), steering for the same target, so nothing of it
-- crosses the network while it flies; where it went off comes from here.

local RunService = game:GetService("RunService")

local BombFlight = {}

export type Flight = {
	start: Vector3,
	velocity: Vector3,
	fuseSeconds: number,
	-- The velocity after a step of `deltaTime` from `position` (homing, Domain/Homing); nil: it
	-- flies straight. Space has no drag and no gravity for it.
	steer: ((position: Vector3, velocity: Vector3, deltaTime: number) -> Vector3)?,
	-- Where on its step from `from` to `to` it met someone, or nil (checked along the whole step:
	-- a fast bomb moves several studs a frame).
	meets: (from: Vector3, to: Vector3) -> Vector3?,
	onExplode: (center: Vector3) -> (),
}

-- Flies the bomb until it meets someone or its fuse runs out, then calls `onExplode` with where it
-- ended up. Moved by hand every frame.
function BombFlight.launch(flight: Flight)
	local position = flight.start
	local velocity = flight.velocity
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		local steer = flight.steer
		if steer then
			velocity = steer(position, velocity, deltaTime)
		end
		local nextPosition = position + velocity * deltaTime
		local met = flight.meets(position, nextPosition)
		position = met or nextPosition
		if met or elapsed >= flight.fuseSeconds then
			connection:Disconnect()
			flight.onExplode(position)
		end
	end)
end

return table.freeze(BombFlight)
