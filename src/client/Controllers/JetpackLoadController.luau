--!strict
-- Loads the jetpacks' meshes and flame textures before anything else (LoadConfig, Loading/AssetQueue).
-- The jetpack on the player's back is the first thing a newcomer sees; asked for no sooner than it
-- was drawn, its meshes waited behind every other preload of the join, and on a cold phone the
-- body came 30–40 s after its trail (2026-11-11). So the player's own jetpack is asked for the
-- moment it appears (again after every swap: a new jetpack is a new model), and the client's other
-- preloads wait until the jetpack of the player's level is in (Domain/LoadOrder.jetpackReady).
-- Other players' jetpacks are queued first among the rest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetQueue = require(script.Parent.Parent.Loading.AssetQueue)
local JetpackConfig = require(ReplicatedStorage.Shared.Config.JetpackConfig)
local JetpackLooks = require(ReplicatedStorage.Shared.Config.JetpackLooks)
local LoadConfig = require(ReplicatedStorage.Shared.Config.LoadConfig)
local LoadOrder = require(ReplicatedStorage.Shared.Domain.LoadOrder)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)

export type JetpackLoadController = {
	name: string,
	init: () -> (),
	start: () -> (),
}

local JetpackLoadController = {}

local function jetpackOfModel(model: Model): number?
	local jetpack = model:GetAttribute(JetpackConfig.JETPACK_ATTRIBUTE)
	return if type(jetpack) == "number" then jetpack else nil
end

-- What a jetpack model shows: its meshes and the textures of its flame and trail
-- (JetpackEffectsController adds those as soon as the nozzles are in).
local function assetsOf(model: Model): { AssetQueue.Asset }
	local assets: { AssetQueue.Asset } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("MeshPart") then
			table.insert(assets, descendant)
		end
	end
	local jetpack = jetpackOfModel(model) or 0
	local step = JetpackLooks.stepOf(JetpackLooks.LEVELS[math.clamp(jetpack + 1, 1, #JetpackLooks.LEVELS)])
	local textures: { string } = { step.jet, step.core }
	if step.trail then
		table.insert(textures, step.trail)
	end
	for _, texture in textures do
		if not table.find(assets, texture) then
			table.insert(assets, texture)
		end
	end
	return assets
end

function JetpackLoadController.new(): JetpackLoadController
	local player = Players.LocalPlayer
	local startedAt = os.clock()
	-- The player's own jetpack whose assets have resolved.
	local loadedModel: Model? = nil

	-- Opens the queue once the jetpack of the player's level is on and loaded, or the wait is over.
	local function evaluate()
		if AssetQueue.isOpen() then
			return
		end
		local character = player.Character
		local found = character and character:FindFirstChild(JetpackConfig.MODEL_NAME)
		local model = if found and found:IsA("Model") then found else nil
		local level = player:GetAttribute(UpgradeConfig.JETPACK_LEVEL_ATTRIBUTE)
		local ready = LoadOrder.jetpackReady({
			expected = if type(level) == "number" then JetpackLooks.jetpackOf(level) else nil,
			worn = if model then jetpackOfModel(model) else nil,
			loaded = model ~= nil and model == loadedModel,
			elapsed = os.clock() - startedAt,
		}, LoadConfig.JETPACK_WAIT_SECONDS)
		if ready then
			AssetQueue.open()
		end
	end

	local function loadOwn(model: Model)
		task.spawn(function()
			AssetQueue.now(`own jetpack {jetpackOfModel(model)}`, assetsOf(model))
			if model.Parent then
				loadedModel = model
				evaluate()
			end
		end)
	end

	-- Every jetpack `character` wears, each as it arrives; a mesh that streams in after its model is
	-- asked for on its own.
	local function watchCharacter(character: Model, isOwn: boolean)
		local function load(label: string, assets: { AssetQueue.Asset })
			if isOwn then
				task.spawn(AssetQueue.now, label, assets)
			else
				AssetQueue.later(label, LoadConfig.PRIORITY.JETPACK, assets)
			end
		end
		local function onChild(child: Instance)
			if child.Name ~= JetpackConfig.MODEL_NAME or not child:IsA("Model") then
				return
			end
			if isOwn then
				loadOwn(child)
			else
				load(`jetpack of {character.Name}`, assetsOf(child))
			end
			child.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("MeshPart") then
					load(`jetpack part of {character.Name}`, { descendant })
				end
			end)
		end
		character.ChildAdded:Connect(onChild)
		for _, child in character:GetChildren() do
			onChild(child)
		end
	end

	local function watchPlayer(other: Player)
		local isOwn = other == player
		other.CharacterAdded:Connect(function(character)
			watchCharacter(character, isOwn)
		end)
		if other.Character then
			watchCharacter(other.Character, isOwn)
		end
	end

	local function init() end

	local function start()
		player:GetAttributeChangedSignal(UpgradeConfig.JETPACK_LEVEL_ATTRIBUTE):Connect(evaluate)
		for _, other in Players:GetPlayers() do
			watchPlayer(other)
		end
		Players.PlayerAdded:Connect(watchPlayer)
		task.delay(LoadConfig.JETPACK_WAIT_SECONDS, evaluate)
	end

	return {
		name = "JetpackLoadController",
		init = init,
		start = start,
	}
end

return table.freeze(JetpackLoadController)
