local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local BaseComponent =
	require(ReplicatedStorage:WaitForChild("Shared").Components:FindFirstChild("BaseComponent", true) :: ModuleScript)

local PadClient = BaseComponent:Extend("PadClient")

local PRESS_TWEEN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local PAD_ENABLED_ATTRIBUTE = "PadEnabled"
local PAD_OCCUPIED_ATTRIBUTE = "PadOccupied"
local PAD_BUSY_ATTRIBUTE = "PadBusy"
local PAD_OPERATION_VERSION_ATTRIBUTE = "PadOperationVersion"

local PLACE_ACTION_TEXT = "Place"
local REPLACE_ACTION_TEXT = "Replace"
local PICKUP_ACTION_TEXT = "Pick Up"
local LOCAL_OPERATION_TIMEOUT = 3
local LEVEL_UP_SIGN_NAME = "LEVELUPSIGN"
local LEVEL_UP_BUTTON_NAME = "Click"

local function getPadEnabledAttribute(framework): string
	return (framework and framework.Config and framework.Config.Pads and framework.Config.Pads.EnabledAttribute)
		or PAD_ENABLED_ATTRIBUTE
end

local function findTextButton(root: Instance?): TextButton?
	if not root then
		return nil
	end

	local button = root:FindFirstChild(LEVEL_UP_BUTTON_NAME, true)
	if button and button:IsA("TextButton") then
		return button
	end

	return root:FindFirstChildWhichIsA("TextButton", true)
end

function PadClient:Create(padModel: Model)
	self.Model = padModel
	self.InteractPrompt = padModel:FindFirstChild("PadPrompt", true)
	self.LevelUpSign = padModel:FindFirstChild(LEVEL_UP_SIGN_NAME, true)
	self.LevelUpButtonGui = findTextButton(self.LevelUpSign)
	self.PressureButton = padModel:FindFirstChild("Money Display", true)
	self._touchingParts = {}
	self._touchingCount = 0
	self._localOperationActive = false
	self._sawServerBusy = false
	self._operationToken = nil
	self._ignoreNextInventoryChanged = false
	self._lastPromptEnabled = nil
	self._lastPromptActionText = nil

	self:BindPrompt()
	self:BindLevelUpButton()

	if not self.PressureButton or not self.PressureButton:IsA("BasePart") then
		return
	end

	self._restCFrame = self.PressureButton.CFrame
	self._pressedCFrame = self._restCFrame
		* CFrame.new(0, -math.clamp(self.PressureButton.Size.Y * 0.18, 0.08, 0.35), 0)

	self:AddConnection(self.PressureButton.Touched:Connect(function(part)
		if self:_IsLocalCharacterPart(part) and not self._touchingParts[part] then
			self._touchingParts[part] = true
			self._touchingCount += 1
			self:_TweenButton(self._pressedCFrame, PRESS_TWEEN)
		end
	end))

	self:AddConnection(self.PressureButton.TouchEnded:Connect(function(part)
		if self._touchingParts[part] then
			self._touchingParts[part] = nil
			self._touchingCount = math.max(0, self._touchingCount - 1)

			if self._touchingCount == 0 then
				self:_TweenButton(self._restCFrame, RELEASE_TWEEN)
			end
		end
	end))
end

function PadClient:BindPrompt()
	if not self.InteractPrompt or not self.InteractPrompt:IsA("ProximityPrompt") then
		return
	end

	local enabledAttribute = getPadEnabledAttribute(self.Framework)

	local function handleAttributeChanged(attributeName: string)
		if attributeName == PAD_BUSY_ATTRIBUTE then
			self:UpdateOperationState()
		elseif attributeName == PAD_OPERATION_VERSION_ATTRIBUTE then
			if self._localOperationActive and not self:IsServerBusy() then
				self:EndLocalOperation()
			else
				self:RefreshPrompt()
			end
		else
			self:RefreshPrompt()
		end
	end

	local function bindAttribute(instance: Instance, attributeName: string)
		self:AddConnection(instance:GetAttributeChangedSignal(attributeName):Connect(function()
			handleAttributeChanged(attributeName)
		end))
	end

	bindAttribute(self.Model, enabledAttribute)
	bindAttribute(self.Model, PAD_OCCUPIED_ATTRIBUTE)
	bindAttribute(self.Model, PAD_BUSY_ATTRIBUTE)
	bindAttribute(self.Model, PAD_OPERATION_VERSION_ATTRIBUTE)
	bindAttribute(self.InteractPrompt, enabledAttribute)
	bindAttribute(self.InteractPrompt, PAD_OCCUPIED_ATTRIBUTE)
	bindAttribute(self.InteractPrompt, PAD_BUSY_ATTRIBUTE)
	bindAttribute(self.InteractPrompt, PAD_OPERATION_VERSION_ATTRIBUTE)

	local inventoryController = self.Framework:GetController("InventoryController")
	if inventoryController and inventoryController.Changed then
		self:AddConnection(inventoryController.Changed.Event:Connect(function()
			if self._ignoreNextInventoryChanged then
				self._ignoreNextInventoryChanged = false
				self:RefreshPrompt()
				return
			end

			self:RefreshPrompt()
		end))
	end

	self:AddConnection(self.InteractPrompt.Triggered:Connect(function(player)
		if player == nil or player == Players.LocalPlayer then
			self:BeginLocalOperation()
		end
	end))

	self:RefreshPrompt()
end

function PadClient:GetPadIndex(): number
	local indexAttribute = self.Framework
		and self.Framework.Config
		and self.Framework.Config.Pads
		and self.Framework.Config.Pads.IndexAttribute
		or "PadIndex"
	local configuredIndex = self.Model:GetAttribute(indexAttribute)
	if type(configuredIndex) == "number" then
		return math.floor(configuredIndex)
	end

	return tonumber(self.Model.Name:match("%d+")) or 0
end

function PadClient:BindLevelUpButton()
	if not self.LevelUpButtonGui then
		return
	end

	self.LevelUpButton = self.Framework.Components.Button:new(self.LevelUpButtonGui)
	self.LevelUpButton:SetOnClick(function()
		self:UpgradeBrainrot()
	end)
	self:AddChild(self.LevelUpButton)
end

function PadClient:SetLevelUpButtonEnabled(enabled: boolean)
	if not self.LevelUpButtonGui then
		return
	end

	self.LevelUpButtonGui.Active = enabled == true
	pcall(function()
		(self.LevelUpButtonGui :: any).Interactable = enabled == true
	end)
end

function PadClient:UpgradeBrainrot()
	if self._upgradeRequestActive then
		return
	end

	self._upgradeRequestActive = true
	self:SetLevelUpButtonEnabled(false)

	local brainrotService = self.Framework:GetService("BrainrotService")
	local ok, result = pcall(function()
		return brainrotService:UpgradePadBrainrot(self:GetPadIndex())
	end)

	self._upgradeRequestActive = false

	if not rawget(self, "_alive") then
		return
	end

	if not ok then
		warn(("[PadClient] UpgradeBrainrot failed: %s"):format(tostring(result)))
	end

	if self:IsOccupied() then
		self:SetLevelUpButtonEnabled(true)
	end

	self:RefreshPrompt()
end

function PadClient:GetInventoryController()
	return self.Framework and self.Framework:GetController("InventoryController")
end

function PadClient:SetInventoryActionsEnabled(enabled: boolean)
	local inventoryController = self:GetInventoryController()
	if inventoryController and inventoryController.SetActionsEnabled then
		inventoryController:SetActionsEnabled(enabled)
	end
end

function PadClient:RequestInventorySnapshot()
	local inventoryController = self:GetInventoryController()
	if inventoryController and inventoryController.RequestSnapshotSoon then
		inventoryController:RequestSnapshotSoon(0)
	end
end

function PadClient:ScheduleOperationTimeout()
	local token = {}
	self._operationToken = token

	task.delay(LOCAL_OPERATION_TIMEOUT, function()
		if rawget(self, "_operationToken") ~= token or rawget(self, "_localOperationActive") ~= true then
			return
		end

		if self:IsServerBusy() then
			self:ScheduleOperationTimeout()
			return
		end

		self:EndLocalOperation()
	end)
end

function PadClient:BeginLocalOperation()
	if self._localOperationActive then
		return
	end

	self._localOperationActive = true
	self._sawServerBusy = false
	self._ignoreNextInventoryChanged = true
	self:SetInventoryActionsEnabled(false)
	self._ignoreNextInventoryChanged = false
	self:RefreshPrompt()
	self:ScheduleOperationTimeout()
end

function PadClient:EndLocalOperation()
	if not self._localOperationActive then
		return
	end

	self._localOperationActive = false
	self._sawServerBusy = false
	self._operationToken = nil
	self._ignoreNextInventoryChanged = false
	self:SetInventoryActionsEnabled(true)
	self:RequestInventorySnapshot()
	self:RefreshPrompt()
end

function PadClient:UpdateOperationState()
	local serverBusy = self:IsServerBusy()

	if serverBusy then
		self._sawServerBusy = true
		self:RefreshPrompt()
		return
	end

	if self._localOperationActive and self._sawServerBusy then
		self:RefreshPrompt()
		return
	end

	self:RefreshPrompt()
end

function PadClient:HasEquippedBrainrot(): boolean
	local inventoryController = self:GetInventoryController()
	local equippedItem = inventoryController and inventoryController:GetEquippedItem()
	return equippedItem ~= nil and equippedItem.ItemType == "Brainrot"
end

function PadClient:IsPadEnabled(): boolean
	local enabledAttribute = getPadEnabledAttribute(self.Framework)
	local padEnabled = self.InteractPrompt and self.InteractPrompt:GetAttribute(enabledAttribute)

	if type(padEnabled) ~= "boolean" then
		padEnabled = self.Model:GetAttribute(enabledAttribute)
	end

	return padEnabled ~= false
end

function PadClient:IsOccupied(): boolean
	local occupied = self.InteractPrompt and self.InteractPrompt:GetAttribute(PAD_OCCUPIED_ATTRIBUTE)

	if type(occupied) ~= "boolean" then
		occupied = self.Model:GetAttribute(PAD_OCCUPIED_ATTRIBUTE)
	end

	return occupied == true
end

function PadClient:IsServerBusy(): boolean
	local busy = self.InteractPrompt and self.InteractPrompt:GetAttribute(PAD_BUSY_ATTRIBUTE)

	if type(busy) ~= "boolean" then
		busy = self.Model:GetAttribute(PAD_BUSY_ATTRIBUTE)
	end

	return busy == true
end

function PadClient:IsBusy(): boolean
	return self._localOperationActive == true or self:IsServerBusy()
end

function PadClient:ApplyPromptState(enabled: boolean, actionText: string)
	if not self.InteractPrompt or not self.InteractPrompt:IsA("ProximityPrompt") then
		return
	end

	enabled = enabled == true
	actionText = tostring(actionText or "")
	local storedActionText = if enabled then actionText else self._lastPromptActionText

	if self._lastPromptEnabled == enabled and self._lastPromptActionText == storedActionText then
		return
	end

	self._lastPromptEnabled = enabled
	self._lastPromptActionText = storedActionText

	if enabled then
		if self.InteractPrompt.ActionText ~= actionText then
			self.InteractPrompt.ActionText = actionText
		end
		if not self.InteractPrompt.Enabled then
			self.InteractPrompt.Enabled = true
		end
	else
		if self.InteractPrompt.Enabled then
			self.InteractPrompt.Enabled = false
		end
	end
end

function PadClient:SetPromptHidden()
	self:ApplyPromptState(false, "")
end

function PadClient:SetPromptAction(actionText: string)
	self:ApplyPromptState(true, actionText)
end

function PadClient:RefreshPrompt()
	if not self.InteractPrompt or not self.InteractPrompt:IsA("ProximityPrompt") then
		return
	end

	if not self:IsPadEnabled() then
		self:SetPromptHidden()
		return
	end
	local occupied = self:IsOccupied()
	local hasEquippedBrainrot = self:HasEquippedBrainrot()

	if self:IsBusy() then
		self:SetPromptHidden()
		return
	end

	if occupied then
		self:SetPromptAction(if hasEquippedBrainrot then REPLACE_ACTION_TEXT else PICKUP_ACTION_TEXT)
		return
	end

	if hasEquippedBrainrot then
		self:SetPromptAction(PLACE_ACTION_TEXT)
		return
	end

	self:SetPromptHidden()
end

function PadClient:_IsLocalCharacterPart(part: Instance): boolean
	local character = Players.LocalPlayer.Character
	return character ~= nil and part:IsDescendantOf(character)
end

function PadClient:_TweenButton(cframe: CFrame, tweenInfo: TweenInfo)
	if not self.PressureButton then
		return
	end

	if self._tween then
		self._tween:Cancel()
	end

	self._tween = TweenService:Create(self.PressureButton, tweenInfo, { CFrame = cframe })
	self._tween:Play()
end

function PadClient:CleanUp()
	self:SetInventoryActionsEnabled(true)
	self._localOperationActive = false
	self._operationToken = nil

	if self._tween then
		self._tween:Cancel()
		self._tween = nil
	end

	table.clear(self._touchingParts)
	self._touchingCount = 0

	if self.PressureButton and self._restCFrame then
		self.PressureButton.CFrame = self._restCFrame
	end

end

return PadClient
