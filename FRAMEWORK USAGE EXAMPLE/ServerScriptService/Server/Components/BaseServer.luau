local ReplicatedStorage = game:GetService('ReplicatedStorage')
local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)
local Numbers = require(ReplicatedStorage:WaitForChild('Shared').Utils:WaitForChild('Numbers'))

local BaseServer = BaseComponent:Extend('BaseServer')

local function formatMoney(value: number): string
	return '$' .. Numbers.Format.abbreviate(math.max(0, tonumber(value) or 0), 2)
end

local function formatPercent(value: number): string
	return ('%.1f%%'):format(math.clamp(tonumber(value) or 0, 0, 1) * 100):gsub('%.0%%', '%%')
end

local function getPadIndex(padModel: Model, fallbackIndex: number): number
	local configuredIndex = padModel:GetAttribute('PadIndex')
	if type(configuredIndex) == 'number' then
		return configuredIndex
	end

	return tonumber(padModel.Name:match('%d+')) or fallbackIndex
end

local function getTextLabel(root: Instance?, name: string): TextLabel?
	if not root then
		return nil
	end

	local instance = root:FindFirstChild(name, true)
	return if instance and instance:IsA('TextLabel') then instance else nil
end

local function getTextButton(root: Instance?, name: string): TextButton?
	if not root then
		return nil
	end

	local instance = root:FindFirstChild(name, true)
	return if instance and instance:IsA('TextButton') then instance else nil
end

local function getGuiObject(root: Instance?, name: string): GuiObject?
	if not root then
		return nil
	end

	local instance = root:FindFirstChild(name, true)
	return if instance and instance:IsA('GuiObject') then instance else nil
end

local function setUpgradeCard(card: GuiObject?, title: string, value: string, visible: boolean)
	if not card then
		return
	end

	card.Visible = visible
	if not visible then
		return
	end

	local nameLabel = getTextLabel(card, 'ValueName')
	local valueLabel = getTextLabel(card, 'Value')
	if nameLabel then
		nameLabel.Text = title
	end
	if valueLabel then
		valueLabel.Text = value
	end
end

local function setNamedRow(row: GuiObject?, titleNames: { string }, valueNames: { string }, title: string, value: string, visible: boolean)
	if not row then
		return
	end

	row.Visible = visible
	if not visible then
		return
	end

	for _, name in ipairs(titleNames) do
		local label = getTextLabel(row, name)
		if label then
			label.Text = title
			break
		end
	end

	for _, name in ipairs(valueNames) do
		local label = getTextLabel(row, name)
		if label then
			label.Text = value
			break
		end
	end
end

local function getStageTemplate(stageConfig)
	local assets = ReplicatedStorage:FindFirstChild('Assets')
	local bases = assets and assets:FindFirstChild('Bases')
	local templateName = stageConfig and stageConfig.TemplateName
	local template = templateName and bases and bases:FindFirstChild(templateName)
	return if template and template:IsA('Model') then template else nil
end

local function getMicrowaveConfig(framework)
	return (framework and framework.Config and framework.Config.Microwave) or {}
end

local function getMicrowaveShopEntry(framework, microwaveId: string)
	local shop = getMicrowaveConfig(framework).Shop
	if type(shop) ~= 'table' then
		return nil
	end

	for _, entry in ipairs(shop) do
		if type(entry) == 'table' and tostring(entry.Id) == microwaveId then
			return entry
		end
	end
	return nil
end

local function getMicrowaveAssetName(framework, microwaveId: string): string
	local entry = getMicrowaveShopEntry(framework, microwaveId)
	if type(entry) == 'table' and type(entry.AssetName) == 'string' and entry.AssetName ~= '' then
		return entry.AssetName
	end

	return (microwaveId:gsub('Microwave$', ''))
end

local function getMicrowaveTemplate(framework, microwaveId: string): Model?
	local config = getMicrowaveConfig(framework)
	local assets = ReplicatedStorage:FindFirstChild('Assets')
	if not assets then
		return nil
	end

	local microwaves = assets:FindFirstChild(config.AssetsFolderName or 'Microwaves') or assets
	local assetName = getMicrowaveAssetName(framework, microwaveId)
	local folder = microwaves:FindFirstChild(assetName) or microwaves:FindFirstChild(microwaveId)
	local template = folder and folder:FindFirstChildWhichIsA('Model')
	if template and template:IsA('Model') then
		return template
	end

	local directTemplate = microwaves:FindFirstChild(assetName) or microwaves:FindFirstChild(microwaveId)
	if directTemplate and directTemplate:IsA('Model') then
		return directTemplate
	end
	return nil
end

local function findFirstBasePart(root: Instance): BasePart?
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA('BasePart') then
			return descendant
		end
	end
	return nil
end

local function ensureRuntimePart(replacement: Model, existing: Model, childName: string)
	if replacement:FindFirstChild(childName, true) then
		return
	end

	local source = existing:FindFirstChild(childName, true)
	if not source then
		return
	end

	local clone = source:Clone()
	if clone:IsA('ProximityPrompt') then
		local preferredParent = replacement:FindFirstChild('Glass', true)
		if preferredParent and preferredParent:IsA('BasePart') then
			clone.Parent = preferredParent
		else
			local fallbackParent = findFirstBasePart(replacement)
			if fallbackParent then
				clone.Parent = fallbackParent
			else
				clone:Destroy()
			end
		end
	elseif clone:IsA('BasePart') then
		clone.Parent = replacement
	else
		clone.Parent = replacement
	end
end

function BaseServer:Create(baseFolder:Folder)
	self.BaseFolder = baseFolder
	self.Owner = nil
	self.Pads = {}
	self.Fridges = {}
	self.Stage = nil
	self.StageModel = nil
	self:SetStage(self:GetDefaultStage(), self:GetDefaultEnabledCount(), true)
	self:SetPlayerNameText('Unclaimed')
end

function BaseServer:ClearStageComponents()
	for _, pad in ipairs(self.Pads) do
		pad:Destroy()
	end
	table.clear(self.Pads)

	for _, fridge in ipairs(self.Fridges) do
		fridge:Destroy()
	end
	table.clear(self.Fridges)

	self.PadUpgradeModel = nil
	self.PadUpgradeButton = nil
	self.PadUpgradePriceLabel = nil
	self.PadUpgradeSlotsLabel = nil
	self.FridgeUpgradeModel = nil
	self.FridgeUpgradeButton = nil
	self.FridgeUpgradePriceLabel = nil
	self.FridgeUpgradeTitleLabel = nil
	self.FridgeUpgradeCurrentLevelLabel = nil
	self.FridgeUpgradeNextLevelLabel = nil
	self.FridgeUpgradeNextUpgradeLabel = nil
	self.FridgeUpgradePumpPowerCard = nil
	self.FridgeUpgradeMutationCard = nil
	self.MicrowaveUpgradeModel = nil
	self.MicrowaveUpgradeButton = nil
	self.MicrowaveUpgradePriceLabel = nil
	self.MicrowaveUpgradeTitleLabel = nil
	self.MicrowaveUpgradeCurrentLevelLabel = nil
	self.MicrowaveUpgradeNextLevelLabel = nil
	self.MicrowaveUpgradeNextUpgradeLabel = nil
	self.MicrowaveUpgradeLuckRow = nil
	self.MicrowaveUpgradeMutationRow = nil
	self.MicrowaveUpgradeCookSpeedRow = nil
end

function BaseServer:GetCurrentStageModel(): Model?
	local stageModel = self.BaseFolder:FindFirstChild('WHOLE BASE')
	if stageModel and stageModel:IsA('Model') then
		return stageModel
	end

	for _, child in ipairs(self.BaseFolder:GetChildren()) do
		if child:IsA('Model') and (child:FindFirstChild('Pads', true) or child:FindFirstChild('PlayerName', true)) then
			return child
		end
	end

	return nil
end

function BaseServer:RebuildStageComponents()
	self:ClearStageComponents()

	self.StageModel = self:GetCurrentStageModel()
	local root = self.StageModel or self.BaseFolder
	self.SpawnLocation = root:FindFirstChildWhichIsA('SpawnLocation', true)

	local playerName = root:FindFirstChild('PlayerName', true)
	self.PlayerNameTextLabel = playerName and playerName:FindFirstChildWhichIsA('TextLabel', true) or nil
	self.PadUpgradeModel = root:FindFirstChild('PadUpgrade', true) or root:FindFirstChild('Pad Upgrade', true)
	self.PadUpgradeButton = getTextButton(self.PadUpgradeModel, 'Button')
	self.PadUpgradePriceLabel = getTextLabel(self.PadUpgradeModel, 'PriceTag')
	self.PadUpgradeSlotsLabel = getTextLabel(self.PadUpgradeModel, 'SlotsAmount')
	self.FridgeUpgradeModel = root:FindFirstChild('FridgeUpgrade', true) or root:FindFirstChild('Fridge Upgrade', true)
	self.FridgeUpgradeButton = getTextButton(self.FridgeUpgradeModel, 'PurchaseButton')
	self.FridgeUpgradePriceLabel = getTextLabel(self.FridgeUpgradeButton, 'PriceTag') or getTextLabel(self.FridgeUpgradeModel, 'PriceTag')
	self.FridgeUpgradeTitleLabel = getTextLabel(self.FridgeUpgradeModel, 'TitleLabel')
	self.FridgeUpgradeCurrentLevelLabel = getTextLabel(self.FridgeUpgradeModel, 'CurrentLevelLabel')
	self.FridgeUpgradeNextLevelLabel = getTextLabel(self.FridgeUpgradeModel, 'NextLevelLabel')
	self.FridgeUpgradeNextUpgradeLabel = getTextLabel(self.FridgeUpgradeModel, 'NextUpgradeLabel')
	self.FridgeUpgradePumpPowerCard = getGuiObject(self.FridgeUpgradeModel, 'PumpPower')
	self.FridgeUpgradeMutationCard = getGuiObject(self.FridgeUpgradeModel, 'Mutation')
	self.MicrowaveUpgradeModel = root:FindFirstChild('MicrowaveUpgrade', true) or root:FindFirstChild('Microwave Upgrade', true)
	self.MicrowaveUpgradeButton = getTextButton(self.MicrowaveUpgradeModel, 'PurchaseButton')
	self.MicrowaveUpgradePriceLabel = getTextLabel(self.MicrowaveUpgradeButton, 'PriceTag') or getTextLabel(self.MicrowaveUpgradeModel, 'PriceTag')
	self.MicrowaveUpgradeTitleLabel = getTextLabel(self.MicrowaveUpgradeModel, 'TitleLabel')
	self.MicrowaveUpgradeCurrentLevelLabel = getTextLabel(self.MicrowaveUpgradeModel, 'CurrentLevelLabel')
	self.MicrowaveUpgradeNextLevelLabel = getTextLabel(self.MicrowaveUpgradeModel, 'NextLevelLabel')
	self.MicrowaveUpgradeNextUpgradeLabel = getTextLabel(self.MicrowaveUpgradeModel, 'NextUpgradeLabel')
	self.MicrowaveUpgradeLuckRow = getGuiObject(self.MicrowaveUpgradeModel, 'LuckRow') or getGuiObject(self.MicrowaveUpgradeModel, 'Luck')
	self.MicrowaveUpgradeMutationRow = getGuiObject(self.MicrowaveUpgradeModel, 'MutationRow') or getGuiObject(self.MicrowaveUpgradeModel, 'Mutation')
	self.MicrowaveUpgradeCookSpeedRow = getGuiObject(self.MicrowaveUpgradeModel, 'CookSpeedRow') or getGuiObject(self.MicrowaveUpgradeModel, 'CookSpeed')

	local padsFolder = root:FindFirstChild('Pads', true)
	if padsFolder then
		local padModels = {}
		for _, padModel in ipairs(padsFolder:GetChildren()) do
			if padModel:IsA('Model') then
				table.insert(padModels, padModel)
			end
		end

		table.sort(padModels, function(a, b)
			return getPadIndex(a, math.huge) < getPadIndex(b, math.huge)
		end)

		for fallbackIndex, padModel in ipairs(padModels) do
			table.insert(self.Pads, self.Framework.Components.PadServer:new(padModel, self, getPadIndex(padModel, fallbackIndex)))
		end
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA('Model') and descendant.Name == 'Fridge' then
			table.insert(self.Fridges, self.Framework.Components.FridgeServer:new(descendant, self))
		end
	end

	self:ApplyOwnerMicrowave()
end

function BaseServer:GetBaseConfig()
	return (self.Framework.Config and self.Framework.Config.Base) or {}
end

function BaseServer:GetStageConfig(stage: number)
	local config = self:GetBaseConfig()
	return config.Stages and config.Stages[stage] or nil
end

function BaseServer:GetDefaultStage(): number
	return tonumber(self:GetBaseConfig().DefaultStage) or 1
end

function BaseServer:GetStagePadCount(stage: number): number
	local stageConfig = self:GetStageConfig(stage)
	return tonumber(stageConfig and stageConfig.Pads) or self:GetTotalPads()
end

function BaseServer:GetNextStage(stage: number): number?
	local nextStage = stage + 1
	return if self:GetStageConfig(nextStage) then nextStage else nil
end

function BaseServer:SetPlayerNameText(text: string)
	if self.PlayerNameTextLabel then
		self.PlayerNameTextLabel.Text = text
	end
end

function BaseServer:CapturePadContents()
	local contents = {}
	for _, pad in ipairs(self.Pads) do
		local content = pad:ExtractPlacedBrainrot()
		if content then
			content.PadIndex = pad.Index
			table.insert(contents, content)
		end
	end
	return contents
end

function BaseServer:ReturnPadContentToOwner(content)
	local model = content and content.Model
	if not model then
		return
	end

	if self.Owner then
		local cashToClaim = math.floor(tonumber(content.CashToClaim) or 0)
		if cashToClaim > 0 then
			self.Framework:GetService('DataService'):AddPlayerData(self.Owner.UserId, 'Cash', cashToClaim)
		end
		self.Framework:GetService('InventoryService'):AddItem(self.Owner, model, 'Brainrot', model.Name)
	end
	model:Destroy()
end

function BaseServer:RestorePadContents(contents)
	for _, content in ipairs(contents or {}) do
		local pad = self:GetPad(content.PadIndex)
		if not pad or not pad:RestorePlacedBrainrot(content.Model, content.CashToClaim) then
			self:ReturnPadContentToOwner(content)
		end
	end
end

function BaseServer:SetStage(stage: number, unlockedCount: number?, forceRebuild: boolean?)
	stage = math.max(1, math.floor(tonumber(stage) or self:GetDefaultStage()))
	if self.Stage == stage and forceRebuild ~= true then
		if unlockedCount ~= nil then
			self:ApplyPadUnlockCount(unlockedCount)
		end
		return true
	end

	local stageConfig = self:GetStageConfig(stage)
	if not stageConfig then
		return false
	end

	local template = getStageTemplate(stageConfig)
	if not template then
		return false
	end

	local padContents = self:CapturePadContents()
	local oldStageModel = self:GetCurrentStageModel()
	local pivot = oldStageModel and oldStageModel:GetPivot()
	self:ClearStageComponents()
	if oldStageModel then
		oldStageModel:Destroy()
	end

	local newStageModel = template:Clone()
	newStageModel.Name = 'WHOLE BASE'
	newStageModel.Parent = self.BaseFolder
	if pivot then
		newStageModel:PivotTo(pivot)
	end

	self.Stage = stage
	self:RebuildStageComponents()
	if unlockedCount ~= nil then
		self:ApplyPadUnlockCount(unlockedCount)
	end
	self:RestorePadContents(padContents)
	if self.Owner then
		self:SetPlayerNameText(self.Owner.DisplayName .. "'s Base")
	else
		self:SetPlayerNameText('Unclaimed')
	end
	return true
end

function BaseServer:Claim(player:Player)
	if self.Owner ~= nil then return end
	self.Owner = player
	local baseService = self.Framework:GetService('BaseService')
	local stage = baseService:GetPlayerStage(player)
	local unlockedCount = baseService:GetUnlockedPadCount(player)
	self:SetStage(stage, unlockedCount)
	self:ApplyOwnerMicrowave()
	self:UpdatePadUpgradeDisplay(baseService:GetPadUpgradeState(player))
	self:UpdateFridgeUpgradeDisplay(baseService:GetFridgeUpgradeState(player))
	self:UpdateMicrowaveUpgradeDisplay(baseService:GetMicrowaveUpgradeState(player))
	self.Framework:GetController('BaseController').Server.Fire:ClaimBase(player, self.BaseFolder)
	self:SetPlayerNameText(player.DisplayName .. "'s Base")
end

function BaseServer:GetMicrowaveModel(): Model?
	local config = getMicrowaveConfig(self.Framework)
	local modelName = config.ModelName or 'Microwave'
	local root = self.StageModel or self:GetCurrentStageModel() or self.BaseFolder
	local microwave = root and root:FindFirstChild(modelName, true)
	return if microwave and microwave:IsA('Model') then microwave else nil
end

function BaseServer:GetOwnerMicrowaveId(): string
	local config = getMicrowaveConfig(self.Framework)
	if not self.Owner then
		return config.DefaultMicrowaveId or 'DefaultMicrowave'
	end

	local dataService = self.Framework:GetService('DataService')
	local equippedKey = config.EquippedDataKey or 'EquippedMicrowave'
	local equipped = dataService:GetData(self.Owner.UserId, equippedKey)
	return tostring(equipped or config.DefaultMicrowaveId or 'DefaultMicrowave')
end

function BaseServer:ApplyOwnerMicrowave(): boolean
	return self:ApplyMicrowave(self:GetOwnerMicrowaveId())
end

function BaseServer:ApplyMicrowave(microwaveId: string): boolean
	local existing = self:GetMicrowaveModel()
	if not existing then
		warn(('[BaseServer] Missing active microwave model for %s'):format(self.BaseFolder:GetFullName()))
		return false
	end

	local template = getMicrowaveTemplate(self.Framework, microwaveId)
	if not template then
		warn(('[BaseServer] Missing microwave asset for %s'):format(tostring(microwaveId)))
		return false
	end

	local parent = existing.Parent
	local pivot = existing:GetPivot()
	local oldName = existing.Name

	local replacement = template:Clone()
	replacement.Name = oldName
	replacement:SetAttribute('MicrowaveId', microwaveId)
	replacement.Parent = parent
	replacement:PivotTo(pivot)

	local config = getMicrowaveConfig(self.Framework)
	ensureRuntimePart(replacement, existing, config.PromptName or 'MicrowavePrompt')
	ensureRuntimePart(replacement, existing, config.LuckyblockSlotName or 'LuckyblockSlot')

	existing:Destroy()
	return true
end

function BaseServer:Unclaim()
	self.Owner = nil
	self:SetStage(self:GetDefaultStage(), self:GetDefaultEnabledCount(), true)
	self:SetPlayerNameText('Unclaimed')
	self:UpdatePadUpgradeDisplay(nil)
	self:UpdateFridgeUpgradeDisplay(nil)
	self:UpdateMicrowaveUpgradeDisplay(nil)
	for _, pad in ipairs(self.Pads) do
		pad:Reset()
	end
	for _, fridge in ipairs(self.Fridges) do
		fridge:Reset()
	end
end

function BaseServer:GetPad(index: number)
	for _, pad in ipairs(self.Pads) do
		if pad.Index == index then
			return pad
		end
	end
	return nil
end

function BaseServer:SetPadEnabled(index: number, enabled: boolean)
	local pad = self:GetPad(index)
	if not pad then
		return false
	end

	pad:SetEnabled(enabled)
	return true
end

function BaseServer:GetDefaultEnabledCount(): number
	local config = (self.Framework.Config and self.Framework.Config.Pads) or {}
	return tonumber(config.DefaultEnabledCount) or 1
end

function BaseServer:GetTotalPads(): number
	return #self.Pads
end

function BaseServer:ApplyPadUnlockCount(unlockedCount: number)
	local count = math.clamp(math.floor(tonumber(unlockedCount) or self:GetDefaultEnabledCount()), 0, self:GetTotalPads())
	for _, pad in ipairs(self.Pads) do
		pad:SetEnabled(pad.Index <= count)
	end
	return count
end

function BaseServer:UpdatePadUpgradeDisplay(state)
	if self.PadUpgradeSlotsLabel then
		self.PadUpgradeSlotsLabel.Text = if state and not state.Maxed and state.NextPadIndex then ('Slot #%d'):format(state.NextPadIndex) else ''
	end

	if self.PadUpgradePriceLabel then
		self.PadUpgradePriceLabel.Text = if state and not state.Maxed and state.NextPrice then formatMoney(state.NextPrice) else ''
	end

	if self.PadUpgradeButton then
		self.PadUpgradeButton.Visible = state == nil or state.Maxed ~= true
		self.PadUpgradeButton.Active = state == nil or state.Maxed ~= true
		pcall(function()
			(self.PadUpgradeButton :: any).Interactable = state == nil or state.Maxed ~= true
		end)
		self.PadUpgradeButton.AutoButtonColor = false
	end
end

function BaseServer:UpdateFridgeUpgradeDisplay(state)
	if self.FridgeUpgradeTitleLabel then
		self.FridgeUpgradeTitleLabel.Text = if state and state.Ok
			then ('FRIDGE UPGRADE [%d]'):format(tonumber(state.UpgradeCount) or 0)
			else 'FRIDGE UPGRADE [0]'
	end

	if self.FridgeUpgradeCurrentLevelLabel then
		self.FridgeUpgradeCurrentLevelLabel.Text = if state and state.Ok
			then ('LVL %d'):format(tonumber(state.FridgeLevel) or 1)
			else ''
	end

	if self.FridgeUpgradeNextLevelLabel then
		self.FridgeUpgradeNextLevelLabel.Text = if state and state.Ok
			then ('LVL %d'):format(tonumber(state.NextFridgeLevel) or ((tonumber(state.FridgeLevel) or 1) + 1))
			else ''
	end

	if self.FridgeUpgradeNextUpgradeLabel then
		self.FridgeUpgradeNextUpgradeLabel.Text = if state and state.Ok then 'NEXT UPGRADE' else ''
	end

	local pumpGain = tonumber(state and state.PumpPowerGain) or 0
	local mutationGain = tonumber(state and state.MutationPointGain) or 0
	setUpgradeCard(
		self.FridgeUpgradePumpPowerCard,
		'Pump Power',
		('+%s XP'):format(Numbers.Format.abbreviate(pumpGain, 2)),
		state and state.Ok == true and pumpGain > 0
	)
	setUpgradeCard(
		self.FridgeUpgradeMutationCard,
		'Mutation Chance',
		('+%s'):format(formatPercent((tonumber(state and state.NextMutationChance) or 0) - (tonumber(state and state.MutationChance) or 0))),
		state and state.Ok == true and mutationGain > 0
	)

	if self.FridgeUpgradePriceLabel then
		self.FridgeUpgradePriceLabel.Text = if state and state.Ok and state.NextPrice then formatMoney(state.NextPrice) else ''
	end
	if self.FridgeUpgradeButton then
		local enabled = state ~= nil and state.Ok == true
		self.FridgeUpgradeButton.Visible = enabled
		self.FridgeUpgradeButton.Active = enabled
		self.FridgeUpgradeButton.AutoButtonColor = false
		pcall(function()
			(self.FridgeUpgradeButton :: any).Interactable = enabled
		end)
	end
end

function BaseServer:UpdateMicrowaveUpgradeDisplay(state)
	if self.MicrowaveUpgradeTitleLabel then
		self.MicrowaveUpgradeTitleLabel.Text = if state and state.Ok
			then ('MICROWAVE UPGRADE [%d]'):format(tonumber(state.UpgradeCount) or 0)
			else 'MICROWAVE UPGRADE [0]'
	end

	if self.MicrowaveUpgradeCurrentLevelLabel then
		self.MicrowaveUpgradeCurrentLevelLabel.Text = if state and state.Ok
			then ('LVL %d'):format(tonumber(state.MicrowaveLevel) or 1)
			else ''
	end

	if self.MicrowaveUpgradeNextLevelLabel then
		self.MicrowaveUpgradeNextLevelLabel.Text = if state and state.Ok
			then ('LVL %d'):format(tonumber(state.NextMicrowaveLevel) or ((tonumber(state.MicrowaveLevel) or 1) + 1))
			else ''
	end

	if self.MicrowaveUpgradeNextUpgradeLabel then
		self.MicrowaveUpgradeNextUpgradeLabel.Text = if state and state.Ok then 'NEXT UPGRADE' else ''
	end

	local luckGain = tonumber(state and state.BulkLuckGain) or tonumber(state and state.LuckGain) or 0
	local mutationGain = tonumber(state and state.BulkMutationLuckGain) or tonumber(state and state.MutationLuckGain) or 0
	local cookSpeedGain = tonumber(state and state.BulkCookSpeedGain) or tonumber(state and state.CookSpeedGain) or 0

	setNamedRow(
		self.MicrowaveUpgradeLuckRow,
		{ 'LuckName', 'ValueName' },
		{ 'LuckValue', 'Value' },
		'Luck',
		('+%s'):format(Numbers.Format.abbreviate(luckGain, 2)),
		state and state.Ok == true and luckGain > 0
	)
	setNamedRow(
		self.MicrowaveUpgradeMutationRow,
		{ 'MutationName', 'ValueName' },
		{ 'MutationValue', 'Value' },
		'Mutation',
		('+%s'):format(Numbers.Format.abbreviate(mutationGain, 2)),
		state and state.Ok == true and mutationGain > 0
	)
	setNamedRow(
		self.MicrowaveUpgradeCookSpeedRow,
		{ 'CookSpeedName', 'ValueName' },
		{ 'CookSpeedValue', 'Value' },
		'Cook Speed',
		('+x%.2f'):format(cookSpeedGain):gsub('%.00', ''),
		state and state.Ok == true and cookSpeedGain > 0
	)

	if self.MicrowaveUpgradePriceLabel then
		self.MicrowaveUpgradePriceLabel.Text = if state and state.Ok and state.NextPrice then formatMoney(state.NextPrice) else ''
	end
	if self.MicrowaveUpgradeButton then
		local enabled = state ~= nil and state.Ok == true
		self.MicrowaveUpgradeButton.Visible = enabled
		self.MicrowaveUpgradeButton.Active = enabled
		self.MicrowaveUpgradeButton.AutoButtonColor = false
		pcall(function()
			(self.MicrowaveUpgradeButton :: any).Interactable = enabled
		end)
	end
end

return BaseServer
