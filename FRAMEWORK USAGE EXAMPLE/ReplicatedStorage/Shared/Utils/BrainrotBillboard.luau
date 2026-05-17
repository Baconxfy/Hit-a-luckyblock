local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotBillboard = {}
local Numbers = require(ReplicatedStorage:WaitForChild("Shared").Utils:WaitForChild("Numbers"))

local BRAINROTS_FOLDER = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Brainrots")
local BILLBOARD_TEMPLATES = BRAINROTS_FOLDER:WaitForChild("BillboardGuis")

local DEFAULT_MUTATION = "Normal"
local DEFAULT_RARITY = "Common"
local DEFAULT_SIZE = UDim2.fromOffset(260, 130)
local DEFAULT_MAX_DISTANCE = 120
local DEFAULT_TOP_PADDING = 0.65
local DEFAULT_MUTATION_TOP_PADDING = 0.75

local BILLBOARD_NAME = "BrainrotBillboardGui"
local BILLBOARD_ANCHOR_NAME = "BrainrotBillboardAnchor"
local ROLLING_HIGHLIGHT_NAME = "Rolling Anim Highlight"
local MUTATION_VISUAL_PREFIX = "__MutationVisual_"
local MUTATION_ALIASES = {
	Glitch = { "Glitch", "Glitched" },
	Glitched = { "Glitched", "Glitch" },
	DarkMatter = { "DarkMatter", "Dark Matter" },
	["Dark Matter"] = { "Dark Matter", "DarkMatter" },
}

local function isRollingVisual(instance: Instance): boolean
	local current: Instance? = instance

	while current do
		if current.Name == ROLLING_HIGHLIGHT_NAME then
			return true
		end

		local lowerName = current.Name:lower()
		if lowerName:find("rolling", 1, true) or lowerName:find("roll animation", 1, true) then
			return true
		end

		current = current.Parent
	end

	return false
end

local function normalizeName(value: any): string
	return tostring(value or ""):lower():gsub("%W", "")
end

local function findDirectChildByLooseName(root: Instance, childName: string): Instance?
	local wanted = normalizeName(childName)
	for _, child in ipairs(root:GetChildren()) do
		if normalizeName(child.Name) == wanted then
			return child
		end
	end
	return nil
end

local function getNameCandidates(name: string): { string }
	local candidates = {}
	local seen = {}

	local function add(candidate: string?)
		local text = tostring(candidate or "")
		if text ~= "" and not seen[text] then
			seen[text] = true
			table.insert(candidates, text)
		end
	end

	add(name)
	for _, alias in ipairs(MUTATION_ALIASES[name] or {}) do
		add(alias)
	end
	local normalized = normalizeName(name)
	if normalized == "glitch" or normalized == "glitched" then
		add("Glitch")
		add("Glitched")
	elseif normalized == "darkmatter" then
		add("DarkMatter")
		add("Dark Matter")
	end

	return candidates
end

local function findMutationFolder(mutationName: string?): Instance?
	local mutation = tostring(mutationName or "")
	if mutation == "" or mutation == DEFAULT_MUTATION then
		return nil
	end

	for _, candidate in ipairs(getNameCandidates(mutation)) do
		local folder = BRAINROTS_FOLDER:FindFirstChild(candidate) or findDirectChildByLooseName(BRAINROTS_FOLDER, candidate)
		if folder then
			return folder
		end
	end

	return nil
end

local function isVisualEffect(instance: Instance): boolean
	return instance:IsA("Highlight")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Beam")
		or instance:IsA("Trail")
		or instance:IsA("Fire")
		or instance:IsA("Smoke")
		or instance:IsA("Sparkles")
end

local function markMutationVisual(instance: Instance)
	if not instance.Name:find(MUTATION_VISUAL_PREFIX, 1, true) then
		instance.Name = MUTATION_VISUAL_PREFIX .. instance.Name
	end
end

local function removeAppliedMutationVisuals(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name:find(MUTATION_VISUAL_PREFIX, 1, true) == 1 then
			descendant:Destroy()
		end
	end
end

local function getMutationVisualParent(model: Model, visual: Instance): Instance
	if visual:IsA("Highlight") or visual:IsA("Folder") then
		return model
	end

	local centerCube = model:FindFirstChild("CenterCube", true)
	if centerCube and centerCube:IsA("BasePart") then
		return centerCube
	end

	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true) or model
end

local function isInsideModel(instance: Instance, root: Instance): boolean
	local current = instance.Parent
	while current and current ~= root do
		if current:IsA("Model") then
			return true
		end
		current = current.Parent
	end

	return false
end

local function hasVisualEffectOutsideModel(root: Instance, mutationFolder: Instance): boolean
	for _, descendant in ipairs(root:GetDescendants()) do
		if isVisualEffect(descendant) and not isInsideModel(descendant, mutationFolder) then
			return true
		end
	end

	return false
end

local function isInsideCollectedContainer(instance: Instance, containers: { Instance }): boolean
	for _, container in ipairs(containers) do
		if instance:IsDescendantOf(container) then
			return true
		end
	end

	return false
end

local function collectMutationVisualTemplates(mutationFolder: Instance): { Instance }
	local templates = {}
	local containers = {}
	local seen = {}

	for _, descendant in ipairs(mutationFolder:GetDescendants()) do
		if
			descendant:IsA("Attachment")
			and not isInsideModel(descendant, mutationFolder)
			and hasVisualEffectOutsideModel(descendant, mutationFolder)
		then
			table.insert(containers, descendant)
			seen[descendant] = true
			table.insert(templates, descendant)
		end
	end

	for _, descendant in ipairs(mutationFolder:GetDescendants()) do
		if
			isVisualEffect(descendant)
			and not isInsideModel(descendant, mutationFolder)
			and not isInsideCollectedContainer(descendant, containers)
			and not seen[descendant]
		then
			seen[descendant] = true
			table.insert(templates, descendant)
		end
	end

	return templates
end

local function applyMutationVisualTemplate(model: Model, template: Instance)
	local clone = template:Clone()
	markMutationVisual(clone)

	if clone:IsA("Highlight") then
		clone.Adornee = model
		clone.Enabled = true
	elseif isVisualEffect(clone) then
		pcall(function()
			(clone :: any).Enabled = true
		end)
	end

	clone.Parent = getMutationVisualParent(model, clone)
end

local function applyMutationFolderVisuals(model: Model, mutationName: string?)
	local mutationFolder = findMutationFolder(mutationName)
	if not mutationFolder then
		return
	end

	for _, template in ipairs(collectMutationVisualTemplates(mutationFolder)) do
		applyMutationVisualTemplate(model, template)
	end
end

local function setRollingHighlights(model: Model, enabled: boolean)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Highlight") and descendant.Name == ROLLING_HIGHLIGHT_NAME then
			descendant.Adornee = if enabled then model else nil
			descendant.Enabled = enabled
		end
	end
end

local function removeExistingBillboards(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BillboardGui") then
			if descendant.Name == BILLBOARD_NAME then
				descendant:Destroy()
			end
		elseif descendant:IsA("Attachment") then
			if descendant.Name == BILLBOARD_ANCHOR_NAME then
				descendant:Destroy()
			end
		end
	end
end

local function repairMutationVisuals(model: Model, mutationName: string?)
	local mutation = tostring(mutationName or DEFAULT_MUTATION)
	local isMutation = mutation ~= "" and mutation ~= DEFAULT_MUTATION

	removeAppliedMutationVisuals(model)
	if isMutation then
		applyMutationFolderVisuals(model, mutation)
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Highlight") then
			if isRollingVisual(descendant) then
				descendant.Adornee = nil
				descendant.Enabled = false
			elseif isMutation then
				descendant.Adornee = model
				descendant.Enabled = true
			end
		elseif isVisualEffect(descendant) then
			if isMutation and not isRollingVisual(descendant) then
				pcall(function()
					(descendant :: any).Enabled = true
				end)
			end
		end
	end
end

local function getRootPart(model: Model): BasePart?
	local centerCube = model:FindFirstChild("CenterCube", true)
	if centerCube and centerCube:IsA("BasePart") then
		return centerCube
	end

	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getVisualBounds(model: Model): (CFrame, Vector3)
	local includeParts = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= BILLBOARD_ANCHOR_NAME then
			table.insert(includeParts, descendant)
		end
	end

	if #includeParts == 0 then
		return model:GetBoundingBox()
	end

	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, part in ipairs(includeParts) do
		local half = part.Size * 0.5
		for _, x in ipairs({ -half.X, half.X }) do
			for _, y in ipairs({ -half.Y, half.Y }) do
				for _, z in ipairs({ -half.Z, half.Z }) do
					local point = part.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
					minX = math.min(minX, point.X)
					minY = math.min(minY, point.Y)
					minZ = math.min(minZ, point.Z)
					maxX = math.max(maxX, point.X)
					maxY = math.max(maxY, point.Y)
					maxZ = math.max(maxZ, point.Z)
				end
			end
		end
	end

	local center = Vector3.new((minX + maxX) * 0.5, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5)
	local size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
	return CFrame.new(center), size
end

local function createCenteredAnchor(model: Model, rootPart: BasePart, isMutation: boolean): Attachment
	local boundingBoxCFrame, size = getVisualBounds(model)
	local mutationPadding = if isMutation then DEFAULT_MUTATION_TOP_PADDING else 0
	local topWorldPosition = boundingBoxCFrame.Position
		+ Vector3.new(0, size.Y * 0.5 + DEFAULT_TOP_PADDING + mutationPadding + 2, 0)

	local anchor = Instance.new("Attachment")
	anchor.Name = BILLBOARD_ANCHOR_NAME
	anchor.Position = rootPart.CFrame:PointToObjectSpace(topWorldPosition)
	anchor.Parent = rootPart
	return anchor
end

local function getTemplateName(rarity: string?): string
	local normalized = tostring(rarity or DEFAULT_RARITY)
	if normalized == DEFAULT_RARITY then
		return "BrainrotNormal"
	end

	return "Brainrot" .. normalized
end

local function hasTextLabels(instance: Instance): boolean
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			return true
		end
	end

	return false
end

local function findTemplate(rarity: string?): Instance?
	local templateName = getTemplateName(rarity)
	local fallback: Instance? = nil

	for _, child in ipairs(BILLBOARD_TEMPLATES:GetChildren()) do
		if child.Name == templateName then
			if child:IsA("BillboardGui") and hasTextLabels(child) then
				return child
			end

			if child:IsA("Folder") and hasTextLabels(child) and not fallback then
				fallback = child
			elseif child:IsA("BillboardGui") and not fallback then
				fallback = child
			end
		end
	end

	if rarity ~= DEFAULT_RARITY then
		return findTemplate(DEFAULT_RARITY)
	end

	return fallback
end

local function createBillboard(template: Instance): BillboardGui?
	if template:IsA("BillboardGui") then
		return template:Clone()
	end

	if template:IsA("Folder") then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = template.Name

		for _, child in ipairs(template:GetChildren()) do
			child:Clone().Parent = billboard
		end

		return billboard
	end

	return nil
end

local function getSections(root: Instance, sectionName: string)
	local sections = {}

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == sectionName and (descendant:IsA("GuiObject") or descendant:IsA("Folder")) then
			table.insert(sections, descendant)
		end
	end

	return sections
end

local function setSectionText(root: Instance, sectionName: string, text: string)
	for _, section in ipairs(getSections(root, sectionName)) do
		if section:IsA("TextLabel") then
			section.Text = text
		end

		for _, descendant in ipairs(section:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				descendant.Text = text
			end
		end
	end
end

local function setSectionVisible(root: Instance, sectionName: string, visible: boolean)
	for _, section in ipairs(getSections(root, sectionName)) do
		if section:IsA("GuiObject") then
			section.Visible = visible
		end
	end
end

local function formatNumber(value: number): string
	return Numbers.Format.abbreviate(value, 2)
end

local function getConfig(framework, brainrotName: string?, modelName: string?)
	local configs = framework and framework.Config and framework.Config.Brainrots
	if type(configs) ~= "table" then
		return {}
	end

	return configs[tostring(brainrotName or "")] or configs[tostring(modelName or "")] or {}
end

local function getMutationConfig(framework, mutationName: string)
	local mutations = framework
		and framework.Config
		and framework.Config.Mutations
		and framework.Config.Mutations.Mutations
	if type(mutations) ~= "table" then
		return {}
	end

	return mutations[mutationName] or {}
end

function BrainrotBillboard.RepairMutationVisuals(model: Model, mutationName: string?)
	repairMutationVisuals(model, mutationName)
end

function BrainrotBillboard.Attach(model: Model, framework, info)
	local rootPart = getRootPart(model)
	if not rootPart then
		return nil
	end

	local displayName = tostring(info and info.Name or model:GetAttribute("BrainrotId") or model.Name)
	local modelName = tostring(info and info.ModelName or model:GetAttribute("ModelName") or model.Name)
	local config = getConfig(framework, displayName, modelName)
	local rarity = tostring((info and info.Rarity) or model:GetAttribute("Rarity") or config.Rarity or DEFAULT_RARITY)
	local mutation =
		tostring((info and info.Mutation) or model:GetAttribute("Mutation") or config.Mutation or DEFAULT_MUTATION)
	local mutationConfig = getMutationConfig(framework, mutation)
	local mutationDisplayName = tostring(mutationConfig.DisplayName or mutation)
	local isMutation = if type(mutationConfig.IsMutation) == "boolean"
		then mutationConfig.IsMutation
		else mutation ~= DEFAULT_MUTATION
	local income = tonumber(info and info.BaseIncome)
		or tonumber(model:GetAttribute("MoneyPerSecond"))
		or tonumber(model:GetAttribute("BaseIncome"))
		or tonumber(config.MoneyPerSecond)
		or tonumber(config.BaseIncome)
		or 0

	setRollingHighlights(model, false)
	repairMutationVisuals(model, mutation)
	removeExistingBillboards(model)

	local template = findTemplate(rarity)
	if not template then
		return nil
	end

	local billboard = createBillboard(template)
	if not billboard then
		return nil
	end

	local anchor = createCenteredAnchor(model, rootPart, isMutation)

	billboard.Name = BILLBOARD_NAME
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.Enabled = true

	if billboard.Size == UDim2.new() then
		billboard.Size = DEFAULT_SIZE
	end

	if billboard.MaxDistance == 0 then
		billboard.MaxDistance = DEFAULT_MAX_DISTANCE
	end

	billboard.StudsOffset = Vector3.zero
	billboard.StudsOffsetWorldSpace = Vector3.zero

	setSectionText(billboard, "Name", displayName)
	setSectionText(billboard, "Rarity", rarity)
	setSectionVisible(billboard, "Mutation", isMutation)

	if isMutation then
		setSectionText(billboard, "Mutation", mutationDisplayName)
	end

	setSectionText(billboard, "Cash", "$" .. formatNumber(income) .. "/s")
	billboard.Parent = rootPart

	return billboard
end

return BrainrotBillboard
