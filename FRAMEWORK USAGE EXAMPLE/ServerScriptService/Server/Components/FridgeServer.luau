local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)
local Numbers = require(ReplicatedStorage:WaitForChild('Shared').Utils:WaitForChild('Numbers'))

local FridgeServer = BaseComponent:Extend('FridgeServer')

local LUCKYBLOCK_MODELS = ReplicatedStorage:WaitForChild('Assets'):WaitForChild('Luckyblocks')
local CLICK_COOLDOWN = 0.08
local XP_PER_PUMP = 10
local MIN_BLOCK_SCALE = 0.35
local MAX_BLOCK_SCALE = 1
local DEFAULT_MUTATION = 'Normal'

local function getBlockOrder(config)
	local order = {}
	for name, blockConfig in pairs(config) do
		if type(blockConfig) == 'table' and tonumber(blockConfig.XpRequired) then
			table.insert(order, name)
		end
	end
	table.sort(order, function(a, b)
		local aRequired = tonumber(config[a].XpRequired) or math.huge
		local bRequired = tonumber(config[b].XpRequired) or math.huge
		if aRequired == bRequired then
			return a < b
		end
		return aRequired < bRequired
	end)
	return order
end

local function findDescendantByName(root: Instance, name: string): Instance?
	local wanted = string.lower(name)
	for _, descendant in ipairs(root:GetDescendants()) do
		if string.lower(descendant.Name) == wanted then
			return descendant
		end
	end
	return nil
end

local function getTextLabel(root: Instance, name: string): TextLabel?
	local wanted = string.lower(name)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA('TextLabel') and string.lower(descendant.Name) == wanted then
			return descendant
		end
	end
	return nil
end

local function formatNumber(value: number): string
	return Numbers.Format.abbreviate(value, 2)
end

local function getFridgeConfig(framework)
	return (framework and framework.Config and framework.Config.Fridge) or {}
end

local function getXPConfig(framework)
	return getFridgeConfig(framework).LuckyBlockXP or {}
end

local function getMutationConfig(framework)
	return getFridgeConfig(framework).Mutation or {}
end

local function getMutationChance(framework, mutationPoints: number): number
	local mutationConfig = getMutationConfig(framework)
	local maxChance = tonumber(mutationConfig.MaxChance) or 0.65
	local scalingRate = tonumber(mutationConfig.ScalingRate) or 0.045
	return maxChance * (1 - math.exp(-math.max(0, mutationPoints) * scalingRate))
end

local function getXPRequired(framework, level: number): number
	local xpConfig = getXPConfig(framework)
	local baseXP = tonumber(xpConfig.BaseXP) or 25
	local growthRate = tonumber(xpConfig.GrowthRate) or 1.35
	return math.max(1, math.floor(baseXP * (growthRate ^ (math.max(1, math.floor(level)) - 1))))
end

local function getMaxLevelsPerPump(framework): number
	return math.max(1, math.floor(tonumber(getXPConfig(framework).MaxLevelsPerPump) or 5))
end

local function rollWeighted(random: Random, pool)
	local totalWeight = 0
	for _, entry in ipairs(pool) do
		totalWeight += math.max(0, tonumber(entry.Weight) or 0)
	end
	if totalWeight <= 0 then
		return nil
	end

	local roll = random:NextNumber(0, totalWeight)
	local cursor = 0
	for _, entry in ipairs(pool) do
		cursor += math.max(0, tonumber(entry.Weight) or 0)
		if roll <= cursor then
			return entry
		end
	end
	return pool[#pool]
end

local function rollMutation(framework, random: Random): string
	local mutations = getFridgeConfig(framework).Mutations
	if type(mutations) ~= 'table' then
		return DEFAULT_MUTATION
	end

	local rolled = rollWeighted(random, mutations)
	return tostring(rolled and rolled.Name or DEFAULT_MUTATION)
end

function FridgeServer:Create(fridgeModel: Model, baseServer: any?)
	self.Model = fridgeModel
	self.Base = baseServer
	self.Button = fridgeModel:FindFirstChild('Button', true)
	self.TakePrompt = fridgeModel:FindFirstChild('TakePrompt', true)
	self.SpawnPart = findDescendantByName(fridgeModel, 'BlockSpawnPos')
	self.Config = self.Framework.Config.Luckyblocks or {}
	self.BlockOrder = getBlockOrder(self.Config)
	self.BlockIndex = nil
	self.TotalXP = 0
	self.BlockLevel = 1
	self.BlockXP = 0
	self.BlockMutation = DEFAULT_MUTATION
	self.CurrentBlock = nil
	self.LastPumpAt = 0
	self.XPPerPump = XP_PER_PUMP
	self.Random = Random.new()
	self.MinScale = MIN_BLOCK_SCALE
	self.MaxScale = MAX_BLOCK_SCALE
	self.LevelLabel = getTextLabel(fridgeModel, 'Level')
	self.XPLabel = getTextLabel(fridgeModel, 'XP')
	self.XPHolder = self.XPLabel and self.XPLabel.Parent or nil
	self.XPBar = self.XPLabel and self.XPLabel.Parent and self.XPLabel.Parent:FindFirstChild('Holder') or nil

	if not self.Button or not self.Button:IsA('BasePart') then
		warn(('[FridgeServer] %s is missing a Button part'):format(fridgeModel:GetFullName()))
		return
	end

	if not self.SpawnPart or not self.SpawnPart:IsA('BasePart') then
		warn(('[FridgeServer] %s is missing BlockSpawnPos'):format(fridgeModel:GetFullName()))
		return
	end

	self.ButtonRestCFrame = self.Button.CFrame
	self.BlockFolder = fridgeModel:FindFirstChild('GeneratedLuckyblocks') or Instance.new('Folder')
	self.BlockFolder.Name = 'GeneratedLuckyblocks'
	self.BlockFolder.Parent = fridgeModel
	self.BlockFolder:ClearAllChildren()

	self.ClickDetector = self.Button:FindFirstChildWhichIsA('ClickDetector') or Instance.new('ClickDetector')
	self.ClickDetector.MaxActivationDistance = 14
	self.ClickDetector.Parent = self.Button

	self:AddConnection(self.ClickDetector.MouseClick:Connect(function(player)
		self:Pump(player)
	end))

	if self.TakePrompt and self.TakePrompt:IsA('ProximityPrompt') then
		self.TakePrompt.Enabled = false
		self:AddConnection(self.TakePrompt.Triggered:Connect(function(player)
			self:Take(player)
		end))
	else
		warn(('[FridgeServer] %s is missing TakePrompt'):format(fridgeModel:GetFullName()))
	end

	self:RefreshBillboards()
end

function FridgeServer:GetBlockName(index: number?): string?
	local blockIndex = index or self.BlockIndex
	return blockIndex and self.BlockOrder[blockIndex] or nil
end

function FridgeServer:GetBlockConfig(index: number?)
	local blockName = self:GetBlockName(index)
	return blockName and self.Config[blockName] or nil
end

function FridgeServer:GetRequiredXP(index: number): number
	local config = self:GetBlockConfig(index)
	return tonumber(config and config.XpRequired) or math.huge
end

function FridgeServer:IsOwner(player: Player): boolean
	return not self.Base or self.Base.Owner == player
end

function FridgeServer:GetBlockIndexForXP(xp: number): number?
	local bestIndex = nil
	for index in ipairs(self.BlockOrder) do
		if xp >= self:GetRequiredXP(index) then
			bestIndex = index
		else
			break
		end
	end
	return bestIndex
end

function FridgeServer:GetBlockIndexForLevel(level: number): number?
	if #self.BlockOrder == 0 then
		return nil
	end

	return math.clamp(math.max(1, math.floor(tonumber(level) or 1)), 1, #self.BlockOrder)
end

function FridgeServer:GetBlockProgress(index: number): number
	local required = getXPRequired(self.Framework, self.BlockLevel or 1)
	if required <= 0 then
		return 0
	end
	return (self.BlockXP or 0) / required
end

function FridgeServer:GetBlockLuck(index: number?): number
	local blockIndex = index or self.BlockIndex
	if not blockIndex then
		return 1
	end

	local blockConfig = self:GetBlockConfig(blockIndex) or {}
	local rollConfig = (self.Framework.Config.Microwave and self.Framework.Config.Microwave.Roll) or {}
	local baseLuck = tonumber(rollConfig.BaseLuck) or 1
	local tierJump = tonumber(rollConfig.TierLuckJump) or 1.75
	local inTierBonus = tonumber(rollConfig.InTierLuckBonus) or 0.55
	local progress = math.clamp(self:GetBlockProgress(blockIndex), 0, 1)
	local luckBonus = tonumber(blockConfig.LuckBonus) or 0
	local level = math.max(1, math.floor(tonumber(self.BlockLevel) or 1))

	return math.max(0, baseLuck + ((level - 1) * tierJump) + luckBonus + (progress * inTierBonus))
end

function FridgeServer:GetNextRequiredXP(): number
	return getXPRequired(self.Framework, self.BlockLevel or 1)
end

function FridgeServer:GetXPProgress(): number
	if not self.CurrentBlock or not self.BlockIndex then
		return 0
	end

	return math.clamp(self:GetBlockProgress(self.BlockIndex), 0, 1)
end

function FridgeServer:GetLuckyblockData(index: number?)
	local blockIndex = index or self.BlockIndex
	return {
		XP = self.BlockXP,
		TotalXP = self.TotalXP,
		Level = self.BlockLevel,
		Mutation = self.BlockMutation,
		Tier = blockIndex,
		Progress = blockIndex and math.clamp(self:GetBlockProgress(blockIndex), 0, 1) or 0,
		Luck = self:GetBlockLuck(blockIndex),
	}
end

function FridgeServer:ApplyCurrentBlockAttributes()
	if not self.CurrentBlock or not self.CurrentBlock.Model then
		return
	end

	local data = self:GetLuckyblockData(self.BlockIndex)
	local model = self.CurrentBlock.Model
	model:SetAttribute('ItemType', 'Luckyblock')
	model:SetAttribute('LuckyblockId', self:GetBlockName(self.BlockIndex))
	model:SetAttribute('Level', data.Level)
	model:SetAttribute('XP', data.XP)
	model:SetAttribute('TotalXP', data.TotalXP)
	model:SetAttribute('Mutation', data.Mutation)
	model:SetAttribute('Tier', data.Tier)
	model:SetAttribute('Progress', data.Progress)
	model:SetAttribute('Luck', data.Luck)
end

function FridgeServer:RefreshBillboards()
	local hasBlock = self.CurrentBlock ~= nil
	if self.LevelLabel then
		self.LevelLabel.Visible = hasBlock
	end
	if self.XPHolder and self.XPHolder:IsA('GuiObject') then
		self.XPHolder.Visible = hasBlock
	end

	if self.LevelLabel then
		self.LevelLabel.Text = ('Level %d'):format(self.BlockLevel or 1)
	end

	if self.XPLabel then
		local nextRequired = self:GetNextRequiredXP()
		self.XPLabel.Text = ('XP %s / %s'):format(formatNumber(self.BlockXP or 0), formatNumber(nextRequired))
	end

	if self.XPBar and self.XPBar:IsA('GuiObject') then
		local progress = self:GetXPProgress()
		local size = self.XPBar.Size
		self.XPBar.Size = UDim2.new(progress, 0, size.Y.Scale, size.Y.Offset)
	end
end

function FridgeServer:SpawnBlock(index: number)
	local blockName = self:GetBlockName(index)
	local template = blockName and LUCKYBLOCK_MODELS:FindFirstChild(blockName)

	if not template or not template:IsA('Model') then
		warn(('[FridgeServer] Missing luckyblock model for %s'):format(tostring(blockName)))
		return
	end

	if self.CurrentBlock then
		self.CurrentBlock:Destroy()
	end

	self.BlockIndex = index
	self.CurrentBlock = self.Framework.Components.LuckyblockServer:new(
		template,
		blockName,
		self.BlockFolder,
		self.SpawnPart,
		self.MinScale,
		self.MaxScale
	)
end

function FridgeServer:RefreshBlock()
	local index = self:GetBlockIndexForLevel(self.BlockLevel)
	if not index then
		self:RefreshBillboards()
		return
	end

	if self.BlockIndex ~= index or not self.CurrentBlock then
		self:SpawnBlock(index)
	end

	if self.CurrentBlock then
		self.CurrentBlock:SetProgress(self:GetBlockProgress(index))
		self:ApplyCurrentBlockAttributes()
	end

	if self.TakePrompt and self.TakePrompt:IsA('ProximityPrompt') then
		self.TakePrompt.Enabled = self.CurrentBlock ~= nil
	end

	self:RefreshBillboards()
end

function FridgeServer:PlayPumpFeedback()
	local downCFrame = self.ButtonRestCFrame * CFrame.new(0, -0.12, 0)
	TweenService:Create(self.Button, TweenInfo.new(0.045, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = downCFrame }):Play()
	task.delay(0.05, function()
		if self._alive and self.Button then
			TweenService:Create(self.Button, TweenInfo.new(0.09, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = self.ButtonRestCFrame }):Play()
		end
	end)
end

function FridgeServer:Pump(player: Player)
	if player and not self:IsOwner(player) then
		return
	end

	local now = os.clock()
	if now - self.LastPumpAt < CLICK_COOLDOWN then
		return
	end
	self.LastPumpAt = now

	local fridgeState = player and self.Framework:GetService('BaseService'):GetFridgeUpgradeState(player) or nil
	self.XPPerPump = math.max(1, math.floor(tonumber(fridgeState and fridgeState.PumpPower) or self.XPPerPump or XP_PER_PUMP))
	local mutationPoints = math.max(0, math.floor(tonumber(fridgeState and fridgeState.MutationPoints) or 0))

	self.BlockXP += self.XPPerPump
	self.TotalXP += self.XPPerPump

	local levelsGained = 0
	while levelsGained < getMaxLevelsPerPump(self.Framework) do
		local required = getXPRequired(self.Framework, self.BlockLevel)
		if self.BlockXP < required then
			break
		end

		self.BlockXP -= required
		self.BlockLevel += 1
		levelsGained += 1

		if self.BlockMutation == DEFAULT_MUTATION and self.Random:NextNumber(0, 1) < getMutationChance(self.Framework, mutationPoints) then
			self.BlockMutation = rollMutation(self.Framework, self.Random)
		end
	end

	self:RefreshBlock()
	self:PlayPumpFeedback()
end

function FridgeServer:Take(player: Player)
	if not player or not self:IsOwner(player) or not self.CurrentBlock then
		return
	end

	local blockName = self:GetBlockName()
	local blockModel = self.CurrentBlock.Model
	if not blockName or not blockModel then
		return
	end

	local blockData = self:GetLuckyblockData(self.BlockIndex)
	self:ApplyCurrentBlockAttributes()

	local inventoryService = self.Framework:GetService('InventoryService')
	inventoryService:AddItem(player, blockModel, 'Luckyblock', blockName, false, blockData)
	self:Reset()
end

function FridgeServer:Reset()
	self.BlockIndex = nil
	self.TotalXP = 0
	self.BlockLevel = 1
	self.BlockXP = 0
	self.BlockMutation = DEFAULT_MUTATION
	if self.CurrentBlock then
		self.CurrentBlock:Destroy()
		self.CurrentBlock = nil
	end
	self.BlockFolder:ClearAllChildren()
	if self.TakePrompt and self.TakePrompt:IsA('ProximityPrompt') then
		self.TakePrompt.Enabled = false
	end
	self:RefreshBillboards()
end

function FridgeServer:CleanUp()
	if self.CurrentBlock then
		self.CurrentBlock:Destroy()
		self.CurrentBlock = nil
	end
end

return FridgeServer
