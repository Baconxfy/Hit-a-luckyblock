local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotModels = {}

local BRAINROTS_FOLDER = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Brainrots")
local NORMAL_FOLDER = BRAINROTS_FOLDER:WaitForChild("Normal")
local MUTATION_ALIASES = {
	Glitch = { "Glitch", "Glitched" },
	Glitched = { "Glitched", "Glitch" },
	DarkMatter = { "DarkMatter", "Dark Matter" },
	["Dark Matter"] = { "Dark Matter", "DarkMatter" },
}

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

local function findModelByLooseName(root: Instance, modelName: string): Model?
	local wanted = normalizeName(modelName)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Model") and normalizeName(descendant.Name) == wanted then
			return descendant
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
	if not mutationName or mutationName == "" or mutationName == "Normal" then
		return nil
	end

	for _, candidate in ipairs(getNameCandidates(mutationName)) do
		local folder = BRAINROTS_FOLDER:FindFirstChild(candidate) or findDirectChildByLooseName(BRAINROTS_FOLDER, candidate)
		if folder then
			return folder
		end
	end

	return nil
end

local function findTemplateInRoot(root: Instance, modelName: string, rarity: string?): Model?
	if type(rarity) == "string" and rarity ~= "" then
		local rarityFolder = root:FindFirstChild(rarity)
		local template = rarityFolder and rarityFolder:FindFirstChild(modelName)
		if template and template:IsA("Model") then
			return template
		end
		if rarityFolder then
			template = findModelByLooseName(rarityFolder, modelName)
			if template then
				return template
			end
		end
	end

	local directTemplate = root:FindFirstChild(modelName, true)
	if directTemplate and directTemplate:IsA("Model") then
		return directTemplate
	end

	return findModelByLooseName(root, modelName)
end

local function getBrainrotConfig(framework, brainrotId: string?, modelName: string?)
	local configs = framework and framework.Config and framework.Config.Brainrots
	if type(configs) ~= "table" then
		return nil
	end

	if type(brainrotId) == "string" and configs[brainrotId] then
		return configs[brainrotId]
	end
	if type(modelName) == "string" and configs[modelName] then
		return configs[modelName]
	end

	return nil
end

function BrainrotModels.GetTemplate(framework, model: Model?, info): Model?
	if not model then
		return nil
	end

	local brainrotId = tostring((type(info) == "table" and info.BrainrotId) or model:GetAttribute("BrainrotId") or model.Name)
	local config = getBrainrotConfig(framework, brainrotId, model.Name)
	local modelName = tostring(
		(type(info) == "table" and info.ModelName)
			or model:GetAttribute("ModelName")
			or (type(config) == "table" and config.ModelName)
			or model.Name
	)
	local rarity = tostring(
		(type(info) == "table" and info.Rarity) or model:GetAttribute("Rarity") or (type(config) == "table" and config.Rarity) or ""
	)
	local mutation = tostring((type(info) == "table" and info.Mutation) or model:GetAttribute("Mutation") or "Normal")

	local mutationFolder = findMutationFolder(mutation)
	if mutationFolder then
		local template = findTemplateInRoot(mutationFolder, modelName, rarity)
		if template then
			return template
		end
	end

	return findTemplateInRoot(NORMAL_FOLDER, modelName, rarity)
end

function BrainrotModels.GetScale(model: Model?): number?
	if not model then
		return nil
	end

	local ok, scale = pcall(function()
		return model:GetScale()
	end)
	if ok and type(scale) == "number" and scale > 0 then
		return scale
	end

	return nil
end

function BrainrotModels.GetTemplateScale(framework, model: Model?, info): number?
	return BrainrotModels.GetScale(BrainrotModels.GetTemplate(framework, model, info))
end

return BrainrotModels
