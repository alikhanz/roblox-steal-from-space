--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- A ring of progress round something round (a flight button, a prompt's badge): a light sector
-- that sweeps clockwise from the top as `fraction` goes from 0 to 1. Drawn as two halves of a disc,
-- each turned by a hard-edged gradient; whatever sits on top (the button, the badge) hides the
-- middle, so only the rim shows. Centred on its parent, `share` times its size.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Icons)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

export type Props = {
	fraction: () -> number,
	color: Color3 | () -> Color3,
	-- Its size against its parent's.
	share: number,
	zIndex: number?,
	transparency: number?,
}

local function half(side: "Left" | "Right", props: Props): Frame
	local zIndex = props.zIndex or 0
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	Vide.effect(function()
		local share = props.fraction()
		if side == "Right" then
			gradient.Rotation = if share <= 0.5 then 360 * share else 180
		else
			gradient.Rotation = 360 * share
		end
	end)
	return create("Frame")({
		Name = `Ring{side}`,
		ZIndex = zIndex,
		Position = if side == "Left" then UDim2.fromScale(0, 0) else UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = function()
			local share = props.fraction()
			return if side == "Right" then share > 0 else share > 0.5
		end,
		create("ImageLabel")({
			Name = "Disc",
			ZIndex = zIndex,
			Position = if side == "Left" then UDim2.fromScale(0, 0) else UDim2.fromScale(-1, 0),
			Size = UDim2.fromScale(2, 1),
			BackgroundTransparency = 1,
			Image = Icons.DISC,
			ImageColor3 = props.color,
			ImageTransparency = props.transparency or 0,
			gradient,
		}),
	}) :: Frame
end

local function ProgressRing(props: Props): Frame
	return create("Frame")({
		Name = "Ring",
		ZIndex = props.zIndex or 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(props.share, props.share),
		BackgroundTransparency = 1,
		half("Left", props),
		half("Right", props),
	}) :: Frame
end

return ProgressRing
