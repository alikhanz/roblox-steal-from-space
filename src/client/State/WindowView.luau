--!strict
-- What a window shows is worked out only while it is open (decision 141). `WindowView.of` gives a
-- window's view of a value: while `open()` it follows `read`; while closed it keeps the last value
-- and reacts to nothing but `open`, so a closed window does no work when the profile changes. As
-- the window opens, the value is read again: one recount, then live. Toasts, sounds and HUD
-- badges keep reading the live sources.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local WindowView = {}

-- Whether the window is open: its slot (State/WindowState), read without an argument, or any
-- other reactive flag.
export type Open = (boolean?) -> boolean

-- `read` once now (so the window has something to build with), then as above. Its own root: it
-- can be made outside a Vide scope and lives as long as the client.
function WindowView.of<T>(open: Open, read: () -> T): () -> T
	local _, view = Vide.root(function()
		local last: T = Vide.untrack(read)
		return Vide.derive(function(): T
			if open() then
				last = read()
			end
			return last
		end)
	end)
	return view
end

return table.freeze(WindowView)
