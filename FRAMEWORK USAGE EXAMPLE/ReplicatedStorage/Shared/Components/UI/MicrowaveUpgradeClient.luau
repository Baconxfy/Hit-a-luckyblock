local ReplicatedStorage = game:GetService('ReplicatedStorage')

local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)
local Numbers = require(ReplicatedStorage:WaitForChild('Shared').Utils:WaitForChild('Numbers'))

local MicrowaveUpgradeClient = BaseComponent:Extend('MicrowaveUpgradeClient')

local function findTextLabel(root: Instance?, name: string): TextLabel?
	local instance = root and root:FindFirstChild(name, true)
	return if instance and instance:IsA('TextLabel') then instance else nil
end

local function findTextButton(root: Instance?, name: string): TextButton?
	local instance = root and root:FindFirstChild(name, true)
	return if instance and instance:IsA('TextButton') then instance else nil
end

local function findGuiObject(root: Instance?, name: string): GuiObject?
	local instance = root and root:FindFirstChild(name, true)
	return if instance and instance:IsA('GuiObject') then instance else nil
end

local function formatMoney(value: number): string
	return '$' .. Numbers.Format.abbreviate(math.max(0, tonumber(value) or 0), 2)
end

local function setButtonEnabled(button: TextButton?, enabled: boolean)
	if not button then
		return
	end

	button.Active = enabled
	button.AutoButtonColor = false
	pcall(function()
		(button :: any).Interactable = enabled
	end)
end

local function setRow(row: GuiObject?, titleNames: { string }, valueNames: { string }, title: string, value: string, visible: boolean)
	if not row then
		return
	end

	row.Visible = visible
	if not visible then
		return
	end

	for _, name in ipairs(titleNames) do
		local label = findTextLabel(row, name)
		if label then
			label.Text = title
			break
		end
	end

	for _, name in ipairs(valueNames) do
		local label = findTextLabel(row, name)
		if label then
			label.Text = value
			break
		end
	end
end

function MicrowaveUpgradeClient:Create(upgradeModel: Model)
	self.Model = upgradeModel
	self.BaseService = self.Framework:GetService('BaseService')
	self.IsBuying = false
	self.PurchaseModeIndex = 1
	self.PurchaseModes = { 1, 10, 'Max' }

	self.PurchaseButton = findTextButton(upgradeModel, 'PurchaseButton')
	self.MultiplierButton = findTextButton(upgradeModel, 'MultiplierButton')
	self.PriceLabel = findTextLabel(self.PurchaseButton, 'PriceTag') or findTextLabel(upgradeModel, 'PriceTag')
	self.MultiplierLabel = findTextLabel(self.MultiplierButton, 'PriceTag')
	self.TitleLabel = findTextLabel(upgradeModel, 'TitleLabel')
	self.CurrentLevelLabel = findTextLabel(upgradeModel, 'CurrentLevelLabel')
	self.NextLevelLabel = findTextLabel(upgradeModel, 'NextLevelLabel')
	self.NextUpgradeLabel = findTextLabel(upgradeModel, 'NextUpgradeLabel')
	self.LuckRow = findGuiObject(upgradeModel, 'LuckRow') or findGuiObject(upgradeModel, 'Luck')
	self.MutationRow = findGuiObject(upgradeModel, 'MutationRow') or findGuiObject(upgradeModel, 'Mutation')
	self.CookSpeedRow = findGuiObject(upgradeModel, 'CookSpeedRow') or findGuiObject(upgradeModel, 'CookSpeed')
	self.ProgressBar = upgradeModel:FindFirstChild('LevelProgressBar', true)
	self.ProgressFill = findGuiObject(self.ProgressBar, 'Fill')

	if self.PurchaseButton then
		self.Button = self.Framework.Components.Button:new(self.PurchaseButton)
		self.Button:SetOnClick(function()
			self:Buy()
		end)
		self:AddChild(self.Button)
	end
	if self.MultiplierButton then
		self.MultiplierButtonComp = self.Framework.Components.Button:new(self.MultiplierButton)
		self.MultiplierButtonComp:SetOnClick(function()
			self:CyclePurchaseMode()
		end)
		self:AddChild(self.MultiplierButtonComp)
	end

	self:Refresh()
end

function MicrowaveUpgradeClient:GetPurchaseAmount()
	return self.PurchaseModes[self.PurchaseModeIndex] or 1
end

function MicrowaveUpgradeClient:Refresh()
	local ok, state = pcall(function()
		return self.BaseService:GetMicrowaveUpgradeState(self:GetPurchaseAmount())
	end)

	if ok then
		self:ApplyState(state)
	else
		warn(('[MicrowaveUpgradeClient] GetMicrowaveUpgradeState failed: %s'):format(tostring(state)))
		self:ApplyState(nil)
	end
end

function MicrowaveUpgradeClient:ApplyState(state)
	if type(state) ~= 'table' or state.Ok ~= true then
		if self.PurchaseButton then
			self.PurchaseButton.Visible = false
		end
		if self.MultiplierButton then
			self.MultiplierButton.Visible = false
		end
		setButtonEnabled(self.PurchaseButton, false)
		setButtonEnabled(self.MultiplierButton, false)
		return
	end

	if tostring(state.RequestedAmount or 1) ~= tostring(self:GetPurchaseAmount()) then
		task.defer(function()
			if rawget(self, '_alive') then
				self:Refresh()
			end
		end)
		return
	end

	self.LastState = state
	local purchaseAmount = state.PurchaseAmount or self:GetPurchaseAmount()
	local luckGain = tonumber(state.BulkLuckGain) or tonumber(state.LuckGain) or 0
	local mutationGain = tonumber(state.BulkMutationLuckGain) or tonumber(state.MutationLuckGain) or 0
	local cookSpeedGain = tonumber(state.BulkCookSpeedGain) or tonumber(state.CookSpeedGain) or 0

	if self.PurchaseButton then
		self.PurchaseButton.Visible = true
	end
	if self.MultiplierButton then
		self.MultiplierButton.Visible = true
	end

	if self.TitleLabel then
		self.TitleLabel.Text = ('MICROWAVE UPGRADE [%d]'):format(tonumber(state.UpgradeCount) or 0)
	end
	if self.CurrentLevelLabel then
		self.CurrentLevelLabel.Text = ('LVL %d'):format(tonumber(state.MicrowaveLevel) or 1)
	end
	if self.NextLevelLabel then
		self.NextLevelLabel.Text = ('LVL %d'):format(tonumber(state.NextMicrowaveLevel) or ((tonumber(state.MicrowaveLevel) or 1) + 1))
	end
	if self.NextUpgradeLabel then
		self.NextUpgradeLabel.Text = 'NEXT UPGRADE'
	end

	setRow(self.LuckRow, { 'LuckName', 'ValueName' }, { 'LuckValue', 'Value' }, 'Luck', ('+%s'):format(Numbers.Format.abbreviate(luckGain, 2)), luckGain > 0)
	setRow(self.MutationRow, { 'MutationName', 'ValueName' }, { 'MutationValue', 'Value' }, 'Mutation', ('+%s'):format(Numbers.Format.abbreviate(mutationGain, 2)), mutationGain > 0)
	setRow(self.CookSpeedRow, { 'CookSpeedName', 'ValueName' }, { 'CookSpeedValue', 'Value' }, 'Cook Speed', ('+x%.2f'):format(cookSpeedGain):gsub('%.00', ''), cookSpeedGain > 0)

	if self.PriceLabel then
		self.PriceLabel.Text = formatMoney(tonumber(state.NextPrice) or 0)
	end
	if self.MultiplierLabel then
		self.MultiplierLabel.Text = if self:GetPurchaseAmount() == 'Max'
			then 'MAX'
			else ('x%d'):format(tonumber(purchaseAmount) or 1)
	end
	if self.ProgressFill and self.ProgressFill:IsA('GuiObject') then
		local size = self.ProgressFill.Size
		local progress = math.clamp(tonumber(state.LevelProgress) or 0, 0, 1)
		self.ProgressFill.Size = UDim2.new(progress, 0, size.Y.Scale, size.Y.Offset)
	end

	setButtonEnabled(self.PurchaseButton, not self.IsBuying)
	setButtonEnabled(self.MultiplierButton, not self.IsBuying)
end

function MicrowaveUpgradeClient:CyclePurchaseMode()
	if self.IsBuying then
		return
	end

	self.PurchaseModeIndex += 1
	if self.PurchaseModeIndex > #self.PurchaseModes then
		self.PurchaseModeIndex = 1
	end
	self:Refresh()
end

function MicrowaveUpgradeClient:Buy()
	if self.IsBuying then
		return
	end

	self.IsBuying = true
	local ok, state = pcall(function()
		return self.BaseService:BuyMicrowaveUpgrade(self:GetPurchaseAmount())
	end)
	self.IsBuying = false

	if not rawget(self, '_alive') then
		return
	end

	if ok then
		self:ApplyState(state)
	else
		warn(('[MicrowaveUpgradeClient] BuyMicrowaveUpgrade failed: %s'):format(tostring(state)))
		self:Refresh()
	end
end

return MicrowaveUpgradeClient
