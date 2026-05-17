local BrainrotUpgrade = {}

local DEFAULT_UPGRADE = {
	CostGrowth = 1.145,
	UpgradePower = 0.09,
	UpgradeExponent = 0.72,
	MinUpgradeCost = 100,
	BaseUpgradeCostScale = 25,
	VisualScalePower = 0.018,
	VisualScaleExponent = 0.65,
	MaxVisualScale = 2,
	RarityCostMultipliers = {
		Common = 1,
		Rare = 1.35,
		Epic = 1.8,
		Legendary = 2.5,
		Mythic = 4,
		Godly = 6,
		Secret = 8,
		Divine = 12,
		Celestine = 16,
		Forbidden = 22,
	},
}

local DEFAULT_MUTATION = "Normal"
local DEFAULT_RARITY = "Common"

local function getUpgradeConfig(framework)
	local config = framework and framework.Config and framework.Config.BrainrotUpgrade
	return if type(config) == "table" then config else DEFAULT_UPGRADE
end

local function getBrainrotConfigs(framework)
	local configs = framework and framework.Config and framework.Config.Brainrots
	return if type(configs) == "table" then configs else {}
end

local function getMutationConfigs(framework)
	local mutations = framework
		and framework.Config
		and framework.Config.Mutations
		and framework.Config.Mutations.Mutations
	return if type(mutations) == "table" then mutations else {}
end

function BrainrotUpgrade.GetBrainrotConfig(framework, brainrotName: string?, modelName: string?)
	local configs = getBrainrotConfigs(framework)
	return configs[tostring(brainrotName or "")] or configs[tostring(modelName or "")] or {}
end

function BrainrotUpgrade.GetMutationConfig(framework, mutationName: string?)
	return getMutationConfigs(framework)[tostring(mutationName or DEFAULT_MUTATION)] or {}
end

function BrainrotUpgrade.GetUpgradeMultiplier(framework, level: number?): number
	local upgradeConfig = getUpgradeConfig(framework)
	local safeLevel = math.max(0, math.floor(tonumber(level) or 0))
	local power = tonumber(upgradeConfig.UpgradePower) or DEFAULT_UPGRADE.UpgradePower
	local exponent = tonumber(upgradeConfig.UpgradeExponent) or DEFAULT_UPGRADE.UpgradeExponent
	return 1 + (power * (safeLevel ^ exponent))
end

function BrainrotUpgrade.GetVisualScale(framework, level: number?): number
	local upgradeConfig = getUpgradeConfig(framework)
	local safeLevel = math.max(0, math.floor(tonumber(level) or 0))
	local power = tonumber(upgradeConfig.VisualScalePower) or DEFAULT_UPGRADE.VisualScalePower
	local exponent = tonumber(upgradeConfig.VisualScaleExponent) or DEFAULT_UPGRADE.VisualScaleExponent
	local maxScale = tonumber(upgradeConfig.MaxVisualScale) or DEFAULT_UPGRADE.MaxVisualScale
	return math.min(maxScale, 1 + (power * (safeLevel ^ exponent)))
end

function BrainrotUpgrade.GetMutationIncomeMultiplier(mutationConfig): number
	return tonumber(mutationConfig and mutationConfig.IncomeMultiplier)
		or tonumber(mutationConfig and mutationConfig.Multiplier)
		or 1
end

function BrainrotUpgrade.GetMutationCostMultiplier(mutationConfig): number
	return tonumber(mutationConfig and mutationConfig.UpgradeCostMultiplier) or 1
end

function BrainrotUpgrade.GetRarityCostMultiplier(framework, brainrotConfig, rarity: string?): number
	local upgradeConfig = getUpgradeConfig(framework)
	local rarityCostMultipliers = upgradeConfig.RarityCostMultipliers or DEFAULT_UPGRADE.RarityCostMultipliers
	return tonumber(brainrotConfig and brainrotConfig.RarityCostMultiplier)
		or tonumber(rarityCostMultipliers and rarityCostMultipliers[tostring(rarity or DEFAULT_RARITY)])
		or 1
end

function BrainrotUpgrade.GetBaseIncome(framework, model: Model?, brainrotName: string?): number
	local config = BrainrotUpgrade.GetBrainrotConfig(
		framework,
		brainrotName or (model and (model:GetAttribute("BrainrotId") or model.Name)),
		model and (model:GetAttribute("ModelName") or model.Name)
	)
	return tonumber(model and model:GetAttribute("BaseIncome")) or tonumber(config.BaseIncome) or 1
end

function BrainrotUpgrade.GetBaseIncomeForData(framework, data, modelName: string?): number
	local brainrotName = tostring((type(data) == "table" and data.BrainrotId) or modelName or "")
	local config = BrainrotUpgrade.GetBrainrotConfig(framework, brainrotName, modelName)
	return tonumber(type(data) == "table" and data.BaseIncome) or tonumber(config.BaseIncome) or 1
end

function BrainrotUpgrade.GetIncomeForData(framework, data, modelName: string?, level: number?): number
	local brainrotName = tostring((type(data) == "table" and data.BrainrotId) or modelName or "")
	local brainrotConfig = BrainrotUpgrade.GetBrainrotConfig(framework, brainrotName, modelName)
	local mutationName = tostring((type(data) == "table" and data.Mutation) or brainrotConfig.Mutation or DEFAULT_MUTATION)
	local mutationConfig = BrainrotUpgrade.GetMutationConfig(framework, mutationName)
	local rarityMultiplier = tonumber(brainrotConfig.RarityMultiplier) or 1
	local baseIncome = BrainrotUpgrade.GetBaseIncomeForData(framework, data, modelName)
	local upgradeMultiplier = BrainrotUpgrade.GetUpgradeMultiplier(framework, level)

	return baseIncome * rarityMultiplier * BrainrotUpgrade.GetMutationIncomeMultiplier(mutationConfig) * upgradeMultiplier
end

function BrainrotUpgrade.GetUpgradeCostForData(framework, data, modelName: string?, level: number?): number
	local upgradeConfig = getUpgradeConfig(framework)
	local brainrotName = tostring((type(data) == "table" and data.BrainrotId) or modelName or "")
	local brainrotConfig = BrainrotUpgrade.GetBrainrotConfig(framework, brainrotName, modelName)
	local rarity = tostring((type(data) == "table" and data.Rarity) or brainrotConfig.Rarity or DEFAULT_RARITY)
	local mutationName = tostring((type(data) == "table" and data.Mutation) or brainrotConfig.Mutation or DEFAULT_MUTATION)
	local mutationConfig = BrainrotUpgrade.GetMutationConfig(framework, mutationName)
	local safeLevel = math.max(0, math.floor(tonumber(level) or 0))
	local baseIncome = BrainrotUpgrade.GetBaseIncomeForData(framework, data, modelName)
	local baseUpgradeCost = tonumber(brainrotConfig.BaseUpgradeCost)
		or (baseIncome * (tonumber(upgradeConfig.BaseUpgradeCostScale) or DEFAULT_UPGRADE.BaseUpgradeCostScale))
	local cost = baseUpgradeCost
		* BrainrotUpgrade.GetRarityCostMultiplier(framework, brainrotConfig, rarity)
		* BrainrotUpgrade.GetMutationCostMultiplier(mutationConfig)
		* ((tonumber(upgradeConfig.CostGrowth) or DEFAULT_UPGRADE.CostGrowth) ^ safeLevel)

	return math.floor(math.max(cost, tonumber(upgradeConfig.MinUpgradeCost) or DEFAULT_UPGRADE.MinUpgradeCost))
end

function BrainrotUpgrade.GetUpgradeStateForData(framework, data, modelName: string?)
	if type(data) ~= "table" then
		return nil
	end

	local level = math.max(0, math.floor(tonumber(data.UpgradeLevel) or tonumber(data.UpgradeCount) or 0))
	local income = BrainrotUpgrade.GetIncomeForData(framework, data, modelName, level)
	local nextIncome = BrainrotUpgrade.GetIncomeForData(framework, data, modelName, level + 1)

	return {
		BrainrotName = tostring(data.BrainrotId or modelName or ""),
		Level = level,
		Income = income,
		NextIncome = nextIncome,
		Gain = math.max(0, nextIncome - income),
		Cost = BrainrotUpgrade.GetUpgradeCostForData(framework, data, modelName, level),
	}
end

function BrainrotUpgrade.GetIncomeForModel(framework, model: Model, level: number?): number
	local brainrotName = tostring(model:GetAttribute("BrainrotId") or model.Name)
	local brainrotConfig = BrainrotUpgrade.GetBrainrotConfig(framework, brainrotName, model.Name)
	local mutationName = tostring(model:GetAttribute("Mutation") or brainrotConfig.Mutation or DEFAULT_MUTATION)
	local mutationConfig = BrainrotUpgrade.GetMutationConfig(framework, mutationName)
	local rarityMultiplier = tonumber(brainrotConfig.RarityMultiplier) or 1
	local baseIncome = BrainrotUpgrade.GetBaseIncome(framework, model, brainrotName)
	local upgradeMultiplier = BrainrotUpgrade.GetUpgradeMultiplier(framework, level)

	return baseIncome * rarityMultiplier * BrainrotUpgrade.GetMutationIncomeMultiplier(mutationConfig) * upgradeMultiplier
end

function BrainrotUpgrade.GetUpgradeCostForModel(framework, model: Model, level: number?): number
	local upgradeConfig = getUpgradeConfig(framework)
	local brainrotName = tostring(model:GetAttribute("BrainrotId") or model.Name)
	local brainrotConfig = BrainrotUpgrade.GetBrainrotConfig(framework, brainrotName, model.Name)
	local rarity = tostring(model:GetAttribute("Rarity") or brainrotConfig.Rarity or DEFAULT_RARITY)
	local mutationName = tostring(model:GetAttribute("Mutation") or brainrotConfig.Mutation or DEFAULT_MUTATION)
	local mutationConfig = BrainrotUpgrade.GetMutationConfig(framework, mutationName)
	local safeLevel = math.max(0, math.floor(tonumber(level) or 0))
	local baseIncome = BrainrotUpgrade.GetBaseIncome(framework, model, brainrotName)
	local baseUpgradeCost = tonumber(brainrotConfig.BaseUpgradeCost)
		or (baseIncome * (tonumber(upgradeConfig.BaseUpgradeCostScale) or DEFAULT_UPGRADE.BaseUpgradeCostScale))
	local cost = baseUpgradeCost
		* BrainrotUpgrade.GetRarityCostMultiplier(framework, brainrotConfig, rarity)
		* BrainrotUpgrade.GetMutationCostMultiplier(mutationConfig)
		* ((tonumber(upgradeConfig.CostGrowth) or DEFAULT_UPGRADE.CostGrowth) ^ safeLevel)

	return math.floor(math.max(cost, tonumber(upgradeConfig.MinUpgradeCost) or DEFAULT_UPGRADE.MinUpgradeCost))
end

function BrainrotUpgrade.GetUpgradeStateForModel(framework, model: Model?)
	if not model or not model:IsA("Model") then
		return nil
	end

	local level = math.max(0, math.floor(tonumber(model:GetAttribute("UpgradeLevel")) or tonumber(model:GetAttribute("UpgradeCount")) or 0))
	local income = BrainrotUpgrade.GetIncomeForModel(framework, model, level)
	local nextIncome = BrainrotUpgrade.GetIncomeForModel(framework, model, level + 1)

	return {
		BrainrotName = tostring(model:GetAttribute("BrainrotId") or model.Name),
		Level = level,
		Income = income,
		NextIncome = nextIncome,
		Gain = math.max(0, nextIncome - income),
		Cost = BrainrotUpgrade.GetUpgradeCostForModel(framework, model, level),
	}
end

return BrainrotUpgrade
