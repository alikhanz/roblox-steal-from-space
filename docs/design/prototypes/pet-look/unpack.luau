-- Unpacks an imported pack of robot pets (assets/blender/aliens/export_robo_roblox.py --pack: one
-- kind, ten variants) into one Model per pet, ready for PetDress (preview prototype, a ModuleScript
-- run from Edit via MCP). Everything comes from the node names, nothing is copied by hand:
--   <variant>|<role>_<n>|<paint code>             a part: renamed <role>_<n>, the code kept in
--                                                 its Paint attribute;
--   <variant>|meta1|zone|family|tier|meteor|sig    the pet: Zone, Family, Tier, Meteor, Signature;
--   <variant>|meta2|glow|core|tierColor|shell      Glow, Core, TierColor, Shell (marker parts,
--                                                 dropped).
-- A pet is named <kind>-<variant> and goes into <dest>/<kind>; its pivot is the centre of its box,
-- turned like the pack (the parts keep their place and turn).

-- Unpacks `pack` (the inserted Model) of kind `kind` into `dest`, replacing what was there; returns
-- the pets' names and part counts.
return function(pack: Model, kind: string, dest: Folder): string
	local folder = dest:FindFirstChild(kind) or Instance.new("Folder")
	folder.Name = kind
	folder:ClearAllChildren()
	folder.Parent = dest
	-- The insert is a package: unlink it first, or Studio warns about changing a package.
	for _, link in pack:GetDescendants() do
		if link:IsA("PackageLink") then
			link:Destroy()
		end
	end
	local link = pack:FindFirstChildOfClass("PackageLink")
	if link then
		link:Destroy()
	end
	local turn = pack:GetPivot().Rotation
	local pets, counts = {}, {}
	local function pet(variant: string): Model
		local model = pets[variant]
		if not model then
			model = Instance.new("Model")
			model.Name = `{kind}-{variant}`
			pets[variant] = model
			counts[variant] = 0
		end
		return model
	end
	for _, part in pack:GetDescendants() do
		if not part:IsA("MeshPart") then
			continue
		end
		local variant, rest = part.Name:match("^([m%d]+)|(.+)$")
		if not variant then
			continue
		end
		local model = pet(variant)
		local zone, family, tier, meteor, signature = rest:match("^meta1|(%a+)|(%a+)|(%d)|(%a+)|([%w_%+]*)$")
		local glow, core, tierColor, shell = rest:match("^meta2|([%d,]+)|([%d,]+)|([%d,]+)|([%d,]+)$")
		if zone then
			model:SetAttribute("Zone", zone)
			model:SetAttribute("Family", family)
			model:SetAttribute("Tier", tonumber(tier))
			model:SetAttribute("Meteor", meteor == "true")
			model:SetAttribute("Signature", signature)
		elseif glow then
			model:SetAttribute("Glow", glow)
			model:SetAttribute("Core", core)
			model:SetAttribute("TierColor", tierColor)
			model:SetAttribute("Shell", shell)
		else
			local name, code = rest:match("^([%w_]+)|(.+)$")
			part.Name = name
			part:SetAttribute("Paint", code)
			part.Parent = model
			counts[variant] += 1
		end
	end
	local report = {}
	for variant, model in pets do
		local cf = model:GetBoundingBox()
		model.WorldPivot = CFrame.new(cf.Position) * turn
		model.Parent = folder
		table.insert(report, `{model.Name}:{counts[variant]}`)
	end
	pack:Destroy()
	table.sort(report)
	return table.concat(report, " ")
end
