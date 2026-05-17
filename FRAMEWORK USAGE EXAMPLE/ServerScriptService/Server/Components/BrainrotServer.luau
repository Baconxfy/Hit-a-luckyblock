local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)
local BrainrotBillboard = require(ReplicatedStorage:WaitForChild('Shared').Utils:WaitForChild('BrainrotBillboard'))
local BrainrotIdle = require(ReplicatedStorage:WaitForChild('Shared').Utils:WaitForChild('BrainrotIdle'))
local BrainrotModels = require(ReplicatedStorage:WaitForChild('Shared').Utils:WaitForChild('BrainrotModels'))
local BrainrotUpgrade = require(ReplicatedStorage:WaitForChild('Shared').Utils:WaitForChild('BrainrotUpgrade'))

local BrainrotServer = BaseComponent:Extend('BrainrotServer')

local DEFAULT_MONEY_PER_SECOND = 1
local COLLECT_JUMP_HEIGHT = 1.25
local COLLECT_JUMP_UP_TIME = 0.14
local COLLECT_JUMP_DOWN_TIME = 0.22
local ORIGINAL_SCALE_ATTRIBUTE = 'OriginalBrainrotScale'

local function getInventoryConfig(framework)
	return (framework and framework.Config and framework.Config.Inventory) or {}
end

local function getBrainrotConfig(framework)
	return (framework and framework.Config and framework.Config.Brainrot) or {}
end

local function prepPlacedModel(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA('WeldConstraint') then
			descendant:Destroy()
		elseif descendant:IsA('BasePart') then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = false
		end
	end
end

local function getModelScale(model: Model): number
	local ok, scale = pcall(function()
		return model:GetScale()
	end)
	return if ok and type(scale) == 'number' then scale else 1
end

local function getOriginalScale(model: Model, framework, data): number
	local dataScale = tonumber(type(data) == 'table' and data.OriginalScale)
	if dataScale and dataScale > 0 then
		return dataScale
	end

	local templateScale = BrainrotModels.GetTemplateScale(framework, model, data)
	if templateScale then
		return templateScale
	end

	return getModelScale(model)
end

local function cloneData(data)
	if type(data) ~= 'table' then
		return nil
	end

	local copy = {}
	for key, value in pairs(data) do
		if type(value) == 'table' then
			copy[key] = cloneData(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function applyBrainrotAttributes(model: Model, data, itemTypeAttribute: string?)
	model:SetAttribute(itemTypeAttribute or 'ItemType', 'Brainrot')
	model:SetAttribute('BrainrotId', data.BrainrotId)
	model:SetAttribute('ModelName', data.ModelName)
	model:SetAttribute('Rarity', data.Rarity)
	model:SetAttribute('Mutation', data.Mutation)
	model:SetAttribute('BaseIncome', data.BaseIncome)
	model:SetAttribute('Level', data.Level or 1)
	model:SetAttribute('UpgradeLevel', data.UpgradeLevel or 0)
	model:SetAttribute('UpgradeCount', data.UpgradeCount or data.UpgradeLevel or 0)
	model:SetAttribute('MoneyPerSecond', data.MoneyPerSecond or data.BaseIncome)
	model:SetAttribute(ORIGINAL_SCALE_ATTRIBUTE, data.OriginalScale)
end

function BrainrotServer:Create(model: Model, spawnPart: BasePart?, data)
	self.Model = model
	self.Name = model.Name
	local brainrotConfig = getBrainrotConfig(self.Framework)
	self.Config = (self.Framework.Config.Brainrots and self.Framework.Config.Brainrots[self.Name]) or {}
	self.Data = cloneData(data) or {
		BrainrotId = self.Name,
		ModelName = self.Config.ModelName or self.Name,
		Rarity = self.Config.Rarity or 'Common',
		Mutation = self.Config.Mutation or 'Normal',
		BaseIncome = tonumber(self.Config.BaseIncome) or brainrotConfig.DefaultMoneyPerSecond or DEFAULT_MONEY_PER_SECOND,
		UpgradeLevel = 0,
	}
	self.Data.BrainrotId = tostring(self.Data.BrainrotId or self.Name)
	self.Data.ModelName = tostring(self.Data.ModelName or self.Config.ModelName or self.Name)
	self.Data.Rarity = tostring(self.Data.Rarity or self.Config.Rarity or 'Common')
	self.Data.Mutation = tostring(self.Data.Mutation or self.Config.Mutation or 'Normal')
	self.Data.BaseIncome = tonumber(self.Data.BaseIncome)
		or tonumber(self.Config.BaseIncome)
		or brainrotConfig.DefaultMoneyPerSecond
		or DEFAULT_MONEY_PER_SECOND
	self.Data.UpgradeLevel = math.max(0, math.floor(tonumber(self.Data.UpgradeLevel) or tonumber(self.Data.UpgradeCount) or 0))
	self.Level = tonumber(self.Data.Level) or 1
	self.UpgradeLevel = math.max(
		0,
		math.floor(tonumber(self.Data.UpgradeLevel) or tonumber(self.Data.UpgradeCount) or 0)
	)
	self.UpgradeCount = self.UpgradeLevel
	self.SpawnPart = spawnPart
	self.OriginalScale = getOriginalScale(model, self.Framework, self.Data)
	self.Data.OriginalScale = self.OriginalScale
	self:RefreshIncome()
	applyBrainrotAttributes(model, self.Data, getInventoryConfig(self.Framework).ItemTypeAttribute or 'ItemType')
	self:ApplyUpgradeScale()
	prepPlacedModel(model)
	BrainrotIdle.Play(model, self.Framework, self.Data)

	if self.SpawnPart then
		self:PivotToSpawn()
	end
	self:RefreshBillboard()
end

function BrainrotServer:RefreshIncome()
	if not self.Model then
		return 0
	end

	self.UpgradeLevel = math.max(0, math.floor(tonumber(self.UpgradeLevel) or 0))
	self.UpgradeCount = self.UpgradeLevel
	self.Data.UpgradeLevel = self.UpgradeLevel
	self.Data.UpgradeCount = self.UpgradeLevel
	self.MoneyPerSecond = BrainrotUpgrade.GetIncomeForData(self.Framework, self.Data, self.Name, self.UpgradeLevel)
	self.Data.MoneyPerSecond = self.MoneyPerSecond
	self.Model:SetAttribute('UpgradeLevel', self.UpgradeLevel)
	self.Model:SetAttribute('UpgradeCount', self.UpgradeLevel)
	self.Model:SetAttribute('MoneyPerSecond', self.MoneyPerSecond)
	return self.MoneyPerSecond
end

function BrainrotServer:SetUpgradeLevel(level: number)
	if not self.Model then
		return 0
	end

	self.UpgradeLevel = math.max(0, math.floor(tonumber(level) or 0))
	self:RefreshIncome()
	self:ApplyUpgradeScale()
	self:PivotToSpawn()
	self:RefreshBillboard()
	return self.MoneyPerSecond
end

function BrainrotServer:ApplyUpgradeScale()
	if not self.Model then
		return
	end

	local visualScale = if self.UpgradeLevel > 0 then BrainrotUpgrade.GetVisualScale(self.Framework, self.UpgradeLevel) else 1
	pcall(function()
		self.Model:ScaleTo((self.OriginalScale or getOriginalScale(self.Model, self.Framework, self.Data)) * visualScale)
	end)
	self.Model:SetAttribute('PlacedVisualScale', visualScale)
	self.Model:SetAttribute(ORIGINAL_SCALE_ATTRIBUTE, self.OriginalScale or getOriginalScale(self.Model, self.Framework, self.Data))
end

function BrainrotServer:RefreshBillboard()
	if not self.Model then
		return
	end

	BrainrotBillboard.Attach(self.Model, self.Framework, {
		Name = self.Data.BrainrotId or self.Name,
		ModelName = self.Data.ModelName or self.Config.ModelName or self.Name,
		Rarity = self.Data.Rarity,
		Mutation = self.Data.Mutation,
		BaseIncome = self.MoneyPerSecond,
	})
end

function BrainrotServer:GetData()
	local data = cloneData(self.Data) or {}
	data.UpgradeLevel = self.UpgradeLevel
	data.UpgradeCount = self.UpgradeLevel
	data.MoneyPerSecond = self.MoneyPerSecond
	return data
end

function BrainrotServer:GetUpgradeState()
	return BrainrotUpgrade.GetUpgradeStateForData(self.Framework, self:GetData(), self.Name)
end

function BrainrotServer:PivotToSpawn()
	if not self.Model or not self.SpawnPart then
		return
	end

	local pivot = self.Model:GetPivot()
	local boundingBoxCFrame, size = self.Model:GetBoundingBox()
	local pivotToBoundingBox = pivot:ToObjectSpace(boundingBoxCFrame)
	local targetBoundingBoxCFrame = self.SpawnPart.CFrame * CFrame.new(0, size.Y * 0.5, 0)
	self.Model:PivotTo(targetBoundingBoxCFrame * pivotToBoundingBox:Inverse())
	self.BaseCFrame = self.Model:GetPivot()
end

function BrainrotServer:PlayCollectJump()
	if not self.Model then
		return
	end

	if self._jumpValue then
		self._jumpValue:Destroy()
		self._jumpValue = nil
	end

	local baseCFrame = self.BaseCFrame or self.Model:GetPivot()
	local brainrotConfig = getBrainrotConfig(self.Framework)
	local jumpValue = Instance.new('CFrameValue')
	jumpValue.Value = baseCFrame
	self._jumpValue = jumpValue

	local connection = jumpValue:GetPropertyChangedSignal('Value'):Connect(function()
		local model = rawget(self, 'Model')
		if rawget(self, '_alive') and model then
			model:PivotTo(jumpValue.Value)
		end
	end)

	local upTween = TweenService:Create(
		jumpValue,
		TweenInfo.new(brainrotConfig.CollectJumpUpTime or COLLECT_JUMP_UP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = baseCFrame * CFrame.new(0, brainrotConfig.CollectJumpHeight or COLLECT_JUMP_HEIGHT, 0) }
	)
	local downTween = TweenService:Create(
		jumpValue,
		TweenInfo.new(brainrotConfig.CollectJumpDownTime or COLLECT_JUMP_DOWN_TIME, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Value = baseCFrame }
	)

	task.spawn(function()
		upTween:Play()
		upTween.Completed:Wait()
		if rawget(self, '_alive') then
			downTween:Play()
			downTween.Completed:Wait()
		end
		connection:Disconnect()
		if rawget(self, '_jumpValue') == jumpValue then
			rawset(self, '_jumpValue', nil)
		end
		jumpValue:Destroy()
	end)
end

function BrainrotServer:CleanUp()
	local model = rawget(self, 'Model')
	if model then
		BrainrotIdle.Stop(model)
	end
	local jumpValue = rawget(self, '_jumpValue')
	if jumpValue then
		jumpValue:Destroy()
		rawset(self, '_jumpValue', nil)
	end
	if model then
		model:Destroy()
		rawset(self, 'Model', nil)
	end
end

return BrainrotServer
