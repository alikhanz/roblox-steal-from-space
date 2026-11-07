--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The Robux store (docs/design/screens/store.md) in a neon window. Left, "Forever": a card per
-- pass with its icon, what it does and its price, or "Owned". Right, "Right now": the one-off
-- purchases two by two, each with what it gives in big ("⚡+1.2K", "2 → 3") and its price.
-- Prices carry the Robux mark (Locale/Marks), drawn as the Robux icon; a price Roblox has not
-- sent yet shows "…" and cannot be pressed. Data and texts come in ready from the controller;
-- buying opens Roblox's purchase prompt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionButton = require(script.Parent.ActionButton)
local IconText = require(script.Parent.IconText)
local Icons = require(script.Parent.Icons)
local Layout = require(script.Parent.Layout)
local NeonWindow = require(script.Parent.NeonWindow)
local Theme = require(script.Parent.Theme)
local Vide = require(ReplicatedStorage.Packages.Vide)

local create = Vide.create

local NEON = Theme.NEON
local COLUMN_GAP = 12
local PASS_WIDTH = 250
local HEAD_HEIGHT = 16
local HEAD_GAP = 6
local CARD_GAP = 8
local CARD_PADDING = 9
local CARD_TRANSPARENCY = 0.965
-- How far the card's colour of its outline goes towards the glass.
local CARD_LINE_DARKEN = 0.5
local PASS_ICON_SIZE = 30
local VALUE_ICON_SIZE = 20
local VALUE_TEXT_SIZE = 20
local OWNED_TRANSPARENCY = 0.5
local CHECK_COLOR = Color3.fromHex("#5BDB6E")
local CHECK_MARK = "✓"
local PRICE_COLOR = NEON.ACTION.Robux

export type Pass = {
	title: string,
	-- What it does.
	hint: () -> string,
	icon: Icons.Name,
	color: Color3,
	-- "R$ 299", or "R$ …" while Roblox has not sent it.
	price: () -> string,
	priceReady: () -> boolean,
	owned: () -> boolean,
	onBuy: () -> (),
}

export type Product = {
	title: string,
	-- What it gives, in big: "⚡+1.2K" (marks drawn as icons), "2 → 3".
	value: () -> string,
	-- An icon before the value, for a value without a mark (the egg of an incubator slot).
	valueIcon: Icons.Name?,
	color: Color3,
	price: () -> string,
	priceReady: () -> boolean,
	-- It can be bought; otherwise `status` shows in place of the button.
	offered: () -> boolean,
	status: () -> string,
	onBuy: () -> (),
}

export type Texts = {
	title: string,
	hint: string,
	forever: string,
	now: string,
	owned: string,
}

export type Props = {
	visible: () -> boolean,
	coins: () -> string,
	texts: Texts,
	passes: { Pass },
	products: { Product },
	onClose: () -> (),
}

local function head(name: string, text: string): TextLabel
	return create("TextLabel")({
		Name = name,
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, HEAD_HEIGHT),
		BackgroundTransparency = 1,
		FontFace = NEON.FONT,
		TextSize = NEON.TEXT_SMALL,
		TextColor3 = NEON.MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		Layout.textStroke(),
	}) :: TextLabel
end

local function cardOutline(color: Color3, dim: (() -> number)?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = NEON.LINE_THICKNESS
	stroke.Color = color:Lerp(NEON.GLASS, CARD_LINE_DARKEN)
	if dim then
		Vide.effect(function()
			stroke.Transparency = dim()
		end)
	end
	return stroke
end

local function PriceButton(
	name: string,
	price: () -> string,
	enabled: () -> boolean,
	visible: () -> boolean,
	onBuy: () -> ()
): TextButton
	return ActionButton({
		name = name,
		text = price,
		color = PRICE_COLOR,
		size = "Large",
		enabled = enabled,
		visible = visible,
		onClick = onBuy,
	})
end

local function PassCard(pass: Pass, order: number, texts: Texts): Frame
	local function dim(): number
		return if pass.owned() then OWNED_TRANSPARENCY else 0
	end
	local corner = UDim.new(0.5, 0)
	local glass = Layout.glass(pass.color, corner)
	local fill = glass[1] :: Frame
	local line = glass[2] :: UIStroke
	Vide.effect(function()
		fill.BackgroundTransparency = dim()
		line.Transparency = dim()
	end)
	return create("Frame")({
		Name = `Pass{order}`,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0.5, -CARD_GAP / 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = CARD_TRANSPARENCY,
		create("UICorner")({ CornerRadius = NEON.CORNER }),
		cardOutline(pass.color, dim),
		Layout.padding(CARD_PADDING, CARD_PADDING - 1),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("Frame")({
			Name = "Top",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, PASS_ICON_SIZE),
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			create("Frame")({
				Name = "Icon",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(PASS_ICON_SIZE, PASS_ICON_SIZE),
				BackgroundTransparency = 1,
				create("UICorner")({ CornerRadius = corner }),
				glass,
				create("ImageLabel")({
					Name = "Image",
					ZIndex = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.62, 0.62),
					BackgroundTransparency = 1,
					Image = Icons.ICONS[pass.icon],
					ImageColor3 = Layout.iconColor(pass.color),
					ImageTransparency = dim,
				}),
			}),
			create("TextLabel")({
				Name = "Title",
				LayoutOrder = 2,
				Size = UDim2.new(1, -(PASS_ICON_SIZE + 8), 1, 0),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_SECTION,
				TextColor3 = NEON.TEXT,
				TextTransparency = dim,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = pass.title,
				Layout.textStroke(),
			}),
		}),
		create("TextLabel")({
			Name = "Hint",
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_SMALL,
			TextColor3 = NEON.MUTED,
			TextTransparency = dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Text = pass.hint,
			Layout.textStroke(),
		}),
		create("Frame")({
			Name = "Action",
			LayoutOrder = 3,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			PriceButton("Buy", pass.price, pass.priceReady, function()
				return not pass.owned()
			end, pass.onBuy),
			create("TextLabel")({
				Name = "Owned",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_SECTION,
				TextColor3 = CHECK_COLOR,
				Text = `{CHECK_MARK} {texts.owned}`,
				Visible = pass.owned,
				Layout.textStroke(),
			}),
		}),
	}) :: Frame
end

local function ProductCard(product: Product, order: number): Frame
	return create("Frame")({
		Name = `Product{order}`,
		LayoutOrder = order,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = CARD_TRANSPARENCY,
		create("UICorner")({ CornerRadius = NEON.CORNER }),
		cardOutline(product.color),
		Layout.padding(CARD_PADDING, CARD_PADDING - 1),
		create("TextLabel")({
			Name = "Title",
			Size = UDim2.new(1, 0, 0, NEON.TEXT_SECTION + 2),
			BackgroundTransparency = 1,
			FontFace = NEON.FONT,
			TextSize = NEON.TEXT_SECTION,
			TextColor3 = NEON.TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = product.title,
			Layout.textStroke(),
		}),
		create("Frame")({
			Name = "Value",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.46),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			if product.valueIcon
				then create("ImageLabel")({
					Name = "Icon",
					LayoutOrder = 1,
					Size = UDim2.fromOffset(VALUE_ICON_SIZE, VALUE_ICON_SIZE),
					BackgroundTransparency = 1,
					Image = Icons.ICONS[product.valueIcon],
					ImageColor3 = product.color,
				})
				else nil,
			IconText({
				name = "Text",
				layoutOrder = 2,
				text = product.value,
				textSize = VALUE_TEXT_SIZE,
				color = product.color,
				outline = "Neon",
			}),
		}),
		create("Frame")({
			Name = "Action",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			PriceButton("Buy", product.price, product.priceReady, product.offered, product.onBuy),
			create("TextLabel")({
				Name = "Status",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_SMALL,
				TextColor3 = CHECK_COLOR,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Text = product.status,
				Visible = function()
					return not product.offered()
				end,
				Layout.textStroke(),
			}),
		}),
	}) :: Frame
end

local function StoreWindow(props: Props): Frame
	local texts = props.texts
	local passCards = {}
	for order, pass in props.passes do
		table.insert(passCards, PassCard(pass, order, texts))
	end
	local productCards = {}
	for order, product in props.products do
		table.insert(productCards, ProductCard(product, order))
	end
	return NeonWindow({
		name = "StoreWindow",
		visible = props.visible,
		title = texts.title,
		coins = props.coins,
		onClose = props.onClose,
		body = {
			create("Frame")({
				Name = "Passes",
				Size = UDim2.new(0, PASS_WIDTH, 1, 0),
				BackgroundTransparency = 1,
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, HEAD_GAP),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				head("Head", texts.forever),
				create("Frame")({
					Name = "Cards",
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 1, -(HEAD_HEIGHT + HEAD_GAP)),
					BackgroundTransparency = 1,
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, CARD_GAP),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					passCards,
				}),
			}),
			create("Frame")({
				Name = "Products",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(1, -(PASS_WIDTH + COLUMN_GAP), 1, 0),
				BackgroundTransparency = 1,
				head("Head", texts.now),
				create("Frame")({
					Name = "Cards",
					Position = UDim2.fromOffset(0, HEAD_HEIGHT + HEAD_GAP),
					Size = UDim2.new(1, 0, 1, -(HEAD_HEIGHT + HEAD_GAP)),
					BackgroundTransparency = 1,
					create("UIGridLayout")({
						CellSize = UDim2.new(0.5, -CARD_GAP / 2, 0.5, -CARD_GAP / 2),
						CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					productCards,
				}),
			}),
		},
		footer = {
			create("TextLabel")({
				Name = "Hint",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				FontFace = NEON.FONT,
				TextSize = NEON.TEXT_BODY,
				TextColor3 = NEON.MUTED,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = texts.hint,
				Layout.textStroke(),
			}),
		},
	})
end

return StoreWindow
