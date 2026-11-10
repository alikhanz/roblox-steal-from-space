--!strict
-- The queue of short on-screen messages, shared by every controller that has something to
-- say (a hatch, a refused command, a grabbed egg). One component renders it (UI/Toasts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Toasts = require(script.Parent.Parent.UI.Toasts)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

local TOAST_SECONDS = 3.5
-- Older toasts give way: a burst of events never covers the screen.
local MAX_TOASTS = 4

export type ToastState = {
	toasts: Vide.Source<{ Toasts.Toast }>,
	-- Shows `text` for a few seconds, outlined and badged by its `kind` of news; about one alien
	-- (`alienId`), the badge is that alien's picture.
	push: (text: string, kind: Toasts.Kind, alienId: string?) -> (),
}

local ToastState = {}

function ToastState.new(): ToastState
	local toasts = source({} :: { Toasts.Toast })
	local counter = 0

	local function push(text: string, kind: Toasts.Kind, alienId: string?)
		counter += 1
		local id = counter
		local list = table.clone(toasts())
		table.insert(list, { id = id, text = text, kind = kind, alienId = alienId })
		while #list > MAX_TOASTS do
			table.remove(list, 1)
		end
		toasts(list)
		task.delay(TOAST_SECONDS, function()
			local remaining = {}
			for _, entry in toasts() do
				if entry.id ~= id then
					table.insert(remaining, entry)
				end
			end
			toasts(remaining)
		end)
	end

	return {
		toasts = toasts,
		push = push,
	}
end

return table.freeze(ToastState)
