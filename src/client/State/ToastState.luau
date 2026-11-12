--!strict
-- The queue of short on-screen messages, shared by every controller that has something to
-- say (a hatch, a refused command, a grabbed egg). One component renders it (UI/Toasts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Toasts = require(script.Parent.Parent.UI.Toasts)
local Vide = require(ReplicatedStorage.Packages.Vide)

local source = Vide.source

local TOAST_SECONDS = 3.5
-- Older toasts give way: a burst of events never covers the screen. Three: on a phone a fourth
-- already reaches the middle of the screen (playtest, 2026-11-12).
local MAX_TOASTS = 3

export type ToastState = {
	toasts: Vide.Source<{ Toasts.Toast }>,
	-- Shows `text` for a few seconds, outlined and badged by its `kind` of news; about one alien
	-- (`alienId`), the badge is that alien's picture.
	push: Toasts.Push,
	-- A toast of `group` is on screen now (not reactive).
	isShown: (group: string) -> boolean,
}

local ToastState = {}

function ToastState.new(): ToastState
	local toasts = source({} :: { Toasts.Toast })
	local counter = 0

	local function push(text: string, kind: Toasts.Kind, alienId: string?, options: Toasts.Options?)
		counter += 1
		-- A new id even for a replaced toast: its own timer starts, and it sounds as news.
		local id = counter
		local group = options and options.group
		local entry: Toasts.Toast = {
			id = id,
			text = text,
			kind = kind,
			alienId = alienId,
			detail = options and options.detail,
			group = group,
		}
		local list = table.clone(Vide.untrack(toasts))
		local replaced = false
		if group then
			for index, existing in list do
				if existing.group == group then
					list[index] = entry
					replaced = true
					break
				end
			end
		end
		if not replaced then
			table.insert(list, entry)
		end
		while #list > MAX_TOASTS do
			table.remove(list, 1)
		end
		toasts(list)
		task.delay(TOAST_SECONDS, function()
			local remaining = {}
			for _, existing in Vide.untrack(toasts) do
				if existing.id ~= id then
					table.insert(remaining, existing)
				end
			end
			toasts(remaining)
		end)
	end

	local function isShown(group: string): boolean
		for _, existing in Vide.untrack(toasts) do
			if existing.group == group then
				return true
			end
		end
		return false
	end

	return {
		toasts = toasts,
		push = push,
		isShown = isShown,
	}
end

return table.freeze(ToastState)
