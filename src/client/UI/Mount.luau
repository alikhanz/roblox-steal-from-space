--!strict
-- Mounts a Vide component under a parent and hands back one function that takes it down again.
-- Vide's own unmount only stops the reactive scope: the instance the component built stays
-- where it was parented, so a label hidden that way would linger on the wall. This destroys it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local Mount = {}

-- `build` runs inside a Vide root scope and returns the instance to parent under `parent`.
function Mount.instance(build: () -> Instance, parent: Instance): () -> ()
	local instance: Instance
	local unmount = Vide.mount(function()
		instance = build()
		return instance
	end, parent)
	return function()
		unmount()
		instance:Destroy()
	end
end

return table.freeze(Mount)
