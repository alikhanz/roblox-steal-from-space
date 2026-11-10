--!strict
-- The gravity bomb's flight on the server: a point, no part. Every client draws the bomb along
-- the same straight line from the throw it is told about (World/BombVisual), so nothing of it
-- crosses the network while it flies.

local RunService = game:GetService("RunService")

local BombFlight = {}

-- A bomb that flies straight from `start` at `velocity` until `fuseSeconds` pass or `touches`
-- says it reached someone, then calls `onExplode` with where it ended up. Moved by hand: space
-- has no drag and no gravity for it.
function BombFlight.launch(
	start: Vector3,
	velocity: Vector3,
	fuseSeconds: number,
	touches: (Vector3) -> boolean,
	onExplode: (Vector3) -> ()
)
	local position = start
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		position += velocity * deltaTime
		if elapsed >= fuseSeconds or touches(position) then
			connection:Disconnect()
			onExplode(position)
		end
	end)
end

return table.freeze(BombFlight)
