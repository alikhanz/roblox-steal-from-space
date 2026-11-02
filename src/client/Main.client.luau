--!strict
-- Client entry point: creates every controller, wires dependencies explicitly and starts them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lifecycle = require(ReplicatedStorage.Shared.Runtime.Lifecycle)

Lifecycle.run({}, function(callback)
	task.spawn(callback)
end)
