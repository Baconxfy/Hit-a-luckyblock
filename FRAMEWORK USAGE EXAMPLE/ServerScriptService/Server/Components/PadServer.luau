local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BaseComponent =
	require(ReplicatedStorage:WaitForChild("Shared").Components:FindFirstChild("BaseComponent", true) :: ModuleScript)
local BrainrotIdle = require(ReplicatedStorage:WaitForChild("Shared").Utils:WaitForChild("BrainrotIdle"))
local BrainrotUpgrade = require(ReplicatedStorage:WaitForChild("Shared").Utils:WaitForChild("BrainrotUpgrade"))
local Numbers = require(ReplicatedStorage:WaitForChild("Shared").Utils:WaitForChild("Numbers"))

local PadServer = BaseComponent:Extend("PadServer")

local BRAINROT_SLOT_NAME = "BrainrotSlot"
local PAD_BRAINROT_FOLDER_NAME = "PlacedBrainrot"
local PAD_OCCUPIED_ATTRIBUTE = "PadOccupied"
local PAD_BUSY_ATTRIBUTE = "PadBusy"
local PAD_OPERATION_VERSION_ATTRIBUTE = "PadOperationVersion"
local INVENTORY_SLOT_ATTRIBUTE = "InventorySlot"
local LEVEL_UP_SIGN_NAME = "LEVELUPSIGN"
local LEVEL_UP_BUTTON_NAME = "Click"

local CLAIM_COOLDOWN = 0.5
local MONEY_UPDATE_INTERVAL = 0.25

local function getPadConfig(framework)
	return (framework and framework.Config and framework.Config.Pads) or {}
end

local function formatMoney(value: number): string
	return "$" .. Numbers.Format.abbreviate(math.max(0, tonumber(value) or 0), 2)
end

local function formatRate(value: number): string
	return "$" .. Numbers.Format.abbreviate(tonumber(value) or 0, 2) .. "/s"
end

local function findBrainrotSlot(root: Instance): BasePart?
	local slot = root:FindFirstChild(BRAINROT_SLOT_NAME, true)
	if slot and slot:IsA("BasePart") then
		return slot
	end

	return nil
end

local function clearInventorySlot(model: Model)
	model:SetAttribute(INVENTORY_SLOT_ATTRIBUTE, nil)
end

local function findTextLabel(root: Instance?, name: string?): TextLabel?
	if not root then
		return nil
	end

	if name then
		local label = root:FindFirstChild(name, true)
		if label and label:IsA("TextLabel") then
			return label
		end
	end

	return root:FindFirstChildWhichIsA("TextLabel", true)
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

function PadServer:Create(padModel: Model, baseServer: any?, padIndex: number?)
	self.Model = padModel
	self.Base = baseServer
	self.Index = padIndex or tonumber(padModel.Name:match("%d+")) or 1
	self.VisibilityState = {}

	self.PressureButton = padModel:FindFirstChild("Money Display", true)
	self.MoneyDisplayLabel = self.PressureButton and self.PressureButton:FindFirstChildWhichIsA("TextLabel", true)
		or nil

	if self.MoneyDisplayLabel then
		self.MoneyDisplayLabel.Text = ""
	end

	self.CurrentBrainrot = nil
	self.CashToClaim = 0
	self.LastClaimAt = 0
	self.LastAccrueAt = os.clock()
	self.LastDisplayUpdateAt = 0
	self.TouchingPartsByPlayer = {}
	self.ClaimedThisTouchByPlayer = {}
	self.OperationBusy = false
	self.OperationPlayer = nil
	self.OperationVersion = tonumber(padModel:GetAttribute(PAD_OPERATION_VERSION_ATTRIBUTE)) or 0
	self.LevelUpSignVisibilityState = {}

	self.InteractPrompt = padModel:FindFirstChild("PadPrompt", true)
	self.LevelUpSign = padModel:FindFirstChild(LEVEL_UP_SIGN_NAME, true)
	self.LevelUpLabel = findTextLabel(self.LevelUpSign)
	self.LevelUpLevelLabel = findTextLabel(self.LevelUpSign, "Level")
	self.LevelUpCostLabel = findTextLabel(self.LevelUpSign, "UpgradeCost")
	self.LevelUpButton = findTextButton(self.LevelUpSign)
	self:CaptureLevelUpSignOriginalState()
	self.BrainrotSlot = findBrainrotSlot(padModel)
	self.BrainrotFolder = padModel:FindFirstChild(PAD_BRAINROT_FOLDER_NAME) or Instance.new("Folder")
	self.BrainrotFolder.Name = PAD_BRAINROT_FOLDER_NAME
	self.BrainrotFolder.Parent = padModel
	self.BrainrotFolder:ClearAllChildren()

	self:SetBusy(false)
	self:SetEnabled(self:GetConfiguredEnabled())

	if self.InteractPrompt and self.InteractPrompt:IsA("ProximityPrompt") then
		self.InteractPrompt.Enabled = self.Enabled == true
		self:AddConnection(self.InteractPrompt.Triggered:Connect(function(player)
			self:HandleInteract(player)
		end))
	end

	if self.PressureButton and self.PressureButton:IsA("BasePart") then
		self:AddConnection(self.PressureButton.Touched:Connect(function(part)
			self:HandleButtonTouched(part)
		end))

		self:AddConnection(self.PressureButton.TouchEnded:Connect(function(part)
			self:HandleButtonTouchEnded(part)
		end))
	end

	self:AddConnection(RunService.Heartbeat:Connect(function()
		self:UpdateCash()
	end))

	self:RefreshDisplay()
end

function PadServer:GetConfiguredEnabled(): boolean
	local config = getPadConfig(self.Framework)
	local unlockConfig = config.Unlocks and config.Unlocks[self.Index]

	if unlockConfig and type(unlockConfig.Enabled) == "boolean" then
		return unlockConfig.Enabled
	end

	return self.Index <= (config.DefaultEnabledCount or math.huge)
end

function PadServer:GetEnabledAttributeName(): string
	return getPadConfig(self.Framework).EnabledAttribute or "PadEnabled"
end

function PadServer:GetIndexAttributeName(): string
	return getPadConfig(self.Framework).IndexAttribute or "PadIndex"
end

function PadServer:SetBusy(busy: boolean, player: Player?)
	self.OperationBusy = busy == true
	self.OperationPlayer = if self.OperationBusy then player else nil

	self.Model:SetAttribute(PAD_BUSY_ATTRIBUTE, self.OperationBusy)

	if self.InteractPrompt and self.InteractPrompt:IsA("ProximityPrompt") then
		self.InteractPrompt:SetAttribute(PAD_BUSY_ATTRIBUTE, self.OperationBusy)
	end
end

function PadServer:BumpOperationVersion()
	self.OperationVersion = (tonumber(self.OperationVersion) or 0) + 1
	self.Model:SetAttribute(PAD_OPERATION_VERSION_ATTRIBUTE, self.OperationVersion)

	if self.InteractPrompt and self.InteractPrompt:IsA("ProximityPrompt") then
		self.InteractPrompt:SetAttribute(PAD_OPERATION_VERSION_ATTRIBUTE, self.OperationVersion)
	end
end

function PadServer:CaptureVisibilityState(descendant: Instance)
	if self.VisibilityState[descendant] then
		return self.VisibilityState[descendant]
	end

	local state = {}

	if descendant:IsA("BasePart") then
		state.Transparency = descendant.Transparency
		state.CanCollide = descendant.CanCollide
		state.CanTouch = descendant.CanTouch
		state.CanQuery = descendant.CanQuery
	elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
		state.Transparency = descendant.Transparency
	elseif
		descendant:IsA("SurfaceGui")
		or descendant:IsA("BillboardGui")
		or descendant:IsA("ParticleEmitter")
		or descendant:IsA("Beam")
	then
		state.Enabled = descendant.Enabled
	end

	self.VisibilityState[descendant] = state
	return state
end

function PadServer:ApplyDescendantEnabled(descendant: Instance, enabled: boolean)
	local state = self:CaptureVisibilityState(descendant)

	if descendant:IsA("BasePart") then
		descendant.Transparency = if enabled then state.Transparency else 1
		descendant.CanCollide = if enabled then state.CanCollide else false
		descendant.CanTouch = if enabled then state.CanTouch else false
		descendant.CanQuery = if enabled then state.CanQuery else false
	elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
		descendant.Transparency = if enabled then state.Transparency else 1
	elseif
		descendant:IsA("SurfaceGui")
		or descendant:IsA("BillboardGui")
		or descendant:IsA("ParticleEmitter")
		or descendant:IsA("Beam")
	then
		descendant.Enabled = if enabled then state.Enabled else false
	end
end

function PadServer:CaptureLevelUpSignState(descendant: Instance)
	if self.LevelUpSignVisibilityState[descendant] then
		return self.LevelUpSignVisibilityState[descendant]
	end

	local state = {}
	if descendant:IsA("BasePart") then
		state.Transparency = descendant.Transparency
		state.CanCollide = descendant.CanCollide
		state.CanTouch = descendant.CanTouch
		state.CanQuery = descendant.CanQuery
	elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
		state.Transparency = descendant.Transparency
	elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
		state.Enabled = descendant.Enabled
	elseif descendant:IsA("GuiObject") then
		state.Visible = descendant.Visible
	end

	self.LevelUpSignVisibilityState[descendant] = state
	return state
end

function PadServer:CaptureLevelUpSignOriginalState()
	if not self.LevelUpSign then
		return
	end

	for _, descendant in ipairs(self.LevelUpSign:GetDescendants()) do
		self:CaptureLevelUpSignState(descendant)
	end
end

function PadServer:ApplyLevelUpSignDescendantVisible(descendant: Instance, visible: boolean)
	local state = self:CaptureLevelUpSignState(descendant)

	if descendant:IsA("BasePart") then
		descendant.Transparency = if visible then state.Transparency else 1
		descendant.CanCollide = if visible then state.CanCollide else false
		descendant.CanTouch = if visible then state.CanTouch else false
		descendant.CanQuery = if visible then state.CanQuery else false
	elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
		descendant.Transparency = if visible then state.Transparency else 1
	elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
		descendant.Enabled = if visible then state.Enabled else false
	elseif descendant:IsA("GuiObject") then
		descendant.Visible = if visible then state.Visible else false
	end
end

function PadServer:SetLevelUpSignVisible(visible: boolean)
	if not self.LevelUpSign then
		return
	end

	for _, descendant in ipairs(self.LevelUpSign:GetDescendants()) do
		self:ApplyLevelUpSignDescendantVisible(descendant, visible)
	end
end

function PadServer:SetEnabled(enabled: boolean)
	self.Enabled = enabled == true
	self.Model:SetAttribute(self:GetEnabledAttributeName(), self.Enabled)
	self.Model:SetAttribute(self:GetIndexAttributeName(), self.Index)

	for _, descendant in ipairs(self.Model:GetDescendants()) do
		self:ApplyDescendantEnabled(descendant, self.Enabled)
	end

	if self.InteractPrompt and self.InteractPrompt:IsA("ProximityPrompt") then
		self.InteractPrompt:SetAttribute(self:GetEnabledAttributeName(), self.Enabled)
		self.InteractPrompt.Enabled = self.Enabled
	end

	if not self.Enabled then
		self:Reset()
	end

	self:RefreshDisplay()
end

function PadServer:IsEnabled(): boolean
	return self.Enabled == true
end

function PadServer:IsOwner(player: Player): boolean
	return not self.Base or self.Base.Owner == player
end

function PadServer:RefreshDisplay()
	local occupied = self.CurrentBrainrot ~= nil

	self.Model:SetAttribute(PAD_OCCUPIED_ATTRIBUTE, occupied)
	self.Model:SetAttribute(PAD_BUSY_ATTRIBUTE, self.OperationBusy == true)
	self.Model:SetAttribute(PAD_OPERATION_VERSION_ATTRIBUTE, self.OperationVersion)

	if self.InteractPrompt and self.InteractPrompt:IsA("ProximityPrompt") then
		self.InteractPrompt:SetAttribute(PAD_OCCUPIED_ATTRIBUTE, occupied)
		self.InteractPrompt:SetAttribute(PAD_BUSY_ATTRIBUTE, self.OperationBusy == true)
		self.InteractPrompt:SetAttribute(PAD_OPERATION_VERSION_ATTRIBUTE, self.OperationVersion)
	end

	self:RefreshLevelUpSign()

	if not self.MoneyDisplayLabel then
		return
	end

	if not self:IsEnabled() or not occupied then
		self.MoneyDisplayLabel.Text = ""
		return
	end

	self.MoneyDisplayLabel.Text = formatMoney(self.CashToClaim)
end

function PadServer:SetLevelUpButtonEnabled(enabled: boolean)
	if not self.LevelUpButton then
		return
	end

	self.LevelUpButton.Visible = enabled == true
	self.LevelUpButton.Active = enabled == true
	self.LevelUpButton.AutoButtonColor = false
	pcall(function()
		(self.LevelUpButton :: any).Interactable = enabled == true
	end)
end

function PadServer:RefreshLevelUpSign()
	if not self.LevelUpLabel and not self.LevelUpLevelLabel and not self.LevelUpCostLabel and not self.LevelUpButton then
		return
	end

	local hasBrainrot = self.CurrentBrainrot ~= nil and self.CurrentBrainrot.Model ~= nil
	local showSign = self:IsEnabled() and hasBrainrot
	self:SetLevelUpSignVisible(showSign)

	if not showSign then
		if self.LevelUpLabel then
			self.LevelUpLabel.Text = ""
		end
		if self.LevelUpLevelLabel then
			self.LevelUpLevelLabel.Text = ""
		end
		if self.LevelUpCostLabel then
			self.LevelUpCostLabel.Text = ""
		end
		self:SetLevelUpButtonEnabled(false)
		return
	end

	local state = self:GetBrainrotUpgradeState(self.Base and self.Base.Owner)
	if not state.Ok then
		if self.LevelUpLevelLabel then
			self.LevelUpLevelLabel.Text = "Upgrade unavailable"
		end
		if self.LevelUpCostLabel then
			self.LevelUpCostLabel.Text = ""
		end
		if self.LevelUpLabel and not self.LevelUpLevelLabel and not self.LevelUpCostLabel then
			self.LevelUpLabel.Text = "Brainrot\nUpgrade unavailable"
		end
		self:SetLevelUpButtonEnabled(false)
		return
	end

	if self.LevelUpLevelLabel then
		self.LevelUpLevelLabel.Text = ("Lvl %d > Lvl %d"):format(
			tonumber(state.Level) or 0,
			(tonumber(state.Level) or 0) + 1
		)
	end

	if self.LevelUpCostLabel then
		self.LevelUpCostLabel.Text = formatMoney(tonumber(state.Cost) or 0)
	end

	if self.LevelUpLabel and not self.LevelUpLevelLabel and not self.LevelUpCostLabel then
		self.LevelUpLabel.Text = ("%s\nLevel %d\n%s\nUpgrade: %s\n+%s"):format(
			tostring(state.BrainrotName or "Brainrot"),
			tonumber(state.Level) or 0,
			formatRate(tonumber(state.Income) or 0),
			formatMoney(tonumber(state.Cost) or 0),
			formatRate(tonumber(state.Gain) or 0)
		)
	end

	self:SetLevelUpButtonEnabled(true)
end

function PadServer:GetBrainrotUpgradeState(player: Player?)
	if not self:IsEnabled() then
		return {
			Ok = false,
			Reason = "PadDisabled",
		}
	end

	if not self.CurrentBrainrot or not self.CurrentBrainrot.Model then
		return {
			Ok = false,
			Reason = "EmptyPad",
		}
	end

	local state = if self.CurrentBrainrot.GetUpgradeState then self.CurrentBrainrot:GetUpgradeState() else nil
	if not state then
		return {
			Ok = false,
			Reason = "NoBrainrot",
		}
	end

	local cash = 0
	if player then
		cash = tonumber(self.Framework:GetService("DataService"):GetData(player.UserId, "Cash")) or 0
	end

	state.Ok = true
	state.PadIndex = self.Index
	state.CanAfford = cash >= state.Cost
	state.Cash = cash
	return state
end

function PadServer:UpgradeBrainrot(player: Player)
	if not self:IsEnabled() or not player or not self:IsOwner(player) then
		return {
			Ok = false,
			Reason = "NotOwner",
		}
	end

	if self.OperationBusy then
		return self:GetBrainrotUpgradeState(player)
	end

	local state = self:GetBrainrotUpgradeState(player)
	if not state.Ok then
		return state
	end

	if not state.CanAfford then
		state.Reason = "NotEnoughCash"
		return state
	end

	self:SetBusy(true, player)
	local dataService = self.Framework:GetService("DataService")
	if not dataService:AddPlayerData(player.UserId, "Cash", -state.Cost) then
		self:SetBusy(false)
		self:RefreshDisplay()
		state.Ok = false
		state.Reason = "SpendFailed"
		return state
	end

	local nextLevel = (tonumber(state.Level) or 0) + 1
	local upgradeOk, newIncome = pcall(function()
		return self.CurrentBrainrot:SetUpgradeLevel(nextLevel)
	end)

	if not upgradeOk then
		dataService:AddPlayerData(player.UserId, "Cash", state.Cost)
		self:SetBusy(false)
		self:RefreshDisplay()
		state.Ok = false
		state.Reason = "UpgradeFailed"
		warn(("[PadServer] Failed to upgrade brainrot on %s: %s"):format(self.Model:GetFullName(), tostring(newIncome)))
		return state
	end

	self.LastAccrueAt = os.clock()
	self:SetBusy(false)
	self:BumpOperationVersion()
	self:RefreshDisplay()

	local newState = self:GetBrainrotUpgradeState(player)
	newState.NewLevel = nextLevel
	newState.NewIncome = newIncome
	return newState
end

function PadServer:UpdateCash()
	local now = os.clock()
	local elapsed = now - (self.LastAccrueAt or now)
	self.LastAccrueAt = now

	if self:IsEnabled() and self.CurrentBrainrot then
		local moneyPerSecond = tonumber(self.CurrentBrainrot.MoneyPerSecond) or 0
		self.CashToClaim += moneyPerSecond * math.max(0, elapsed)
	end

	if now - self.LastDisplayUpdateAt >= MONEY_UPDATE_INTERVAL then
		self.LastDisplayUpdateAt = now
		self:RefreshDisplay()
	end
end

function PadServer:GetPlayerFromPart(part: Instance): Player?
	local character = part:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

function PadServer:HandleButtonTouched(part: Instance)
	if not self:IsEnabled() then
		return
	end

	local player = self:GetPlayerFromPart(part)
	if not player then
		return
	end

	local touchingParts = self.TouchingPartsByPlayer[player]
	if not touchingParts then
		touchingParts = {}
		self.TouchingPartsByPlayer[player] = touchingParts
	end

	if touchingParts[part] then
		return
	end

	touchingParts[part] = true

	if self.ClaimedThisTouchByPlayer[player] ~= true then
		self:ClaimCash(player)
	end
end

function PadServer:HandleButtonTouchEnded(part: Instance)
	if not self:IsEnabled() then
		return
	end

	local player = self:GetPlayerFromPart(part)
	if not player then
		return
	end

	local touchingParts = self.TouchingPartsByPlayer[player]
	if not touchingParts then
		return
	end

	touchingParts[part] = nil

	if next(touchingParts) == nil then
		self.TouchingPartsByPlayer[player] = nil
		self.ClaimedThisTouchByPlayer[player] = nil
	end
end

function PadServer:ClaimCash(player: Player)
	if not self:IsEnabled() or not player or not self:IsOwner(player) or self.CashToClaim <= 0 then
		return false
	end

	local now = os.clock()
	if now - self.LastClaimAt < CLAIM_COOLDOWN then
		return false
	end

	self.LastClaimAt = now

	local amount = math.floor(self.CashToClaim)
	if amount <= 0 then
		return false
	end

	local dataService = self.Framework:GetService("DataService")
	if not dataService:AddPlayerData(player.UserId, "Cash", amount) then
		return false
	end

	self.CashToClaim -= amount

	if self.CurrentBrainrot and self.CurrentBrainrot.PlayCollectJump then
		self.CurrentBrainrot:PlayCollectJump()
	end

	self.ClaimedThisTouchByPlayer[player] = true
	self:RefreshDisplay()
	return true
end

function PadServer:RunPadInventoryOperation(player: Player, callback)
	if self.OperationBusy then
		return false
	end

	local inventoryService = self.Framework:GetService("InventoryService")
	if inventoryService.IsInventoryLocked and inventoryService:IsInventoryLocked(player) then
		return false
	end

	self:SetBusy(true, player)
	inventoryService:SetInventoryLocked(player, true)

	local ok, result = pcall(function()
		return inventoryService:WithSuppressedRefresh(player, function()
			return callback(inventoryService)
		end)
	end)

	if not ok then
		warn(
			("[PadServer] Pad operation failed for %s on %s: %s"):format(
				player.Name,
				self.Model:GetFullName(),
				tostring(result)
			)
		)
		result = false
	end

	self:RefreshDisplay()
	local refreshOk, refreshResult = pcall(function()
		return inventoryService:RefreshPlayer(player, true)
	end)

	if not refreshOk then
		warn(
			("[PadServer] Failed to refresh inventory after pad operation for %s on %s: %s"):format(
				player.Name,
				self.Model:GetFullName(),
				tostring(refreshResult)
			)
		)
		result = false
	end

	inventoryService:SetInventoryLocked(player, false)
	self:SetBusy(false)
	self:BumpOperationVersion()
	self:RefreshDisplay()

	return result == true
end

function PadServer:CreatePlacedBrainrotFromInventoryModel(player: Player, inventoryService, inventoryModel: Model, brainrotData)
	if not inventoryModel or not inventoryModel:IsA("Model") then
		return nil
	end

	local placedModel = inventoryModel:Clone()
	placedModel.Name = inventoryModel.Name
	clearInventorySlot(placedModel)
	self.BrainrotFolder:ClearAllChildren()
	placedModel.Parent = self.BrainrotFolder

	local ok, brainrotComponent = pcall(function()
		return self.Framework.Components.BrainrotServer:new(placedModel, self.BrainrotSlot, brainrotData)
	end)

	if not ok or not brainrotComponent then
		warn(
			("[PadServer] Failed to create placed brainrot %s: %s"):format(
				inventoryModel.Name,
				tostring(brainrotComponent)
			)
		)
		placedModel:Destroy()
		inventoryService:AddItem(player, inventoryModel, "Brainrot", inventoryModel.Name, true, brainrotData)
		inventoryModel:Destroy()
		return nil
	end

	inventoryModel:Destroy()
	return brainrotComponent
end

function PadServer:PlaceBrainrot(player: Player)
	return self:RunPadInventoryOperation(player, function(inventoryService)
		if not self:IsEnabled() or self.CurrentBrainrot or not self.BrainrotSlot then
			return false
		end

		local inventoryModel, _, _, brainrotData = inventoryService:TakeEquippedItem(player, "Brainrot", true)
		if not inventoryModel then
			return false
		end

		local brainrotComponent = self:CreatePlacedBrainrotFromInventoryModel(player, inventoryService, inventoryModel, brainrotData)
		if not brainrotComponent then
			return false
		end

		self.CurrentBrainrot = brainrotComponent
		self.CashToClaim = 0
		self.LastAccrueAt = os.clock()
		return true
	end)
end

function PadServer:ReturnExtractedBrainrot(player: Player, content, suppressRefresh: boolean?): boolean
	local model = content and content.Model
	if not model or not model:IsA("Model") then
		return false
	end

	local snapshot = self.Framework
		:GetService("InventoryService")
		:AddItem(player, model, "Brainrot", model.Name, suppressRefresh == true, content.Data)
	if not snapshot then
		return false
	end

	local cashToClaim = math.floor(tonumber(content.CashToClaim) or 0)
	if cashToClaim > 0 then
		self.Framework:GetService("DataService"):AddPlayerData(player.UserId, "Cash", cashToClaim)
	end

	model:Destroy()
	return true
end

function PadServer:PickupBrainrot(player: Player)
	return self:RunPadInventoryOperation(player, function()
		if not self:IsEnabled() or not self.CurrentBrainrot then
			return false
		end

		local content = self:ExtractPlacedBrainrot(true)
		if not content then
			return false
		end

		if self:ReturnExtractedBrainrot(player, content, true) then
			return true
		end

		self:RestorePlacedBrainrot(content.Model, content.CashToClaim, true, content.Data)
		return false
	end)
end

function PadServer:ReplaceBrainrot(player: Player)
	return self:RunPadInventoryOperation(player, function(inventoryService)
		if not self:IsEnabled() or not self.CurrentBrainrot or not self.BrainrotSlot then
			return false
		end

		local newInventoryModel, _, _, newBrainrotData = inventoryService:TakeEquippedItem(player, "Brainrot", true)
		if not newInventoryModel then
			return false
		end

		local oldContent = self:ExtractPlacedBrainrot(true)
		if not oldContent then
			inventoryService:AddItem(player, newInventoryModel, "Brainrot", newInventoryModel.Name, true, newBrainrotData)
			newInventoryModel:Destroy()
			return false
		end

		local newBrainrotComponent =
			self:CreatePlacedBrainrotFromInventoryModel(player, inventoryService, newInventoryModel, newBrainrotData)
		if not newBrainrotComponent then
			self:RestorePlacedBrainrot(oldContent.Model, oldContent.CashToClaim, true, oldContent.Data)
			return false
		end

		self.CurrentBrainrot = newBrainrotComponent
		self.CashToClaim = 0
		self.LastAccrueAt = os.clock()

		if self:ReturnExtractedBrainrot(player, oldContent, true) then
			return true
		end

		local newContent = self:ExtractPlacedBrainrot(true)
		self:RestorePlacedBrainrot(oldContent.Model, oldContent.CashToClaim, true, oldContent.Data)

		if newContent then
			self:ReturnExtractedBrainrot(player, newContent, true)
		end

		return false
	end)
end

function PadServer:ExtractPlacedBrainrot(suppressDisplay: boolean?)
	if not self.CurrentBrainrot or not self.CurrentBrainrot.Model then
		return nil
	end

	local model = self.CurrentBrainrot.Model
	local brainrotData = if self.CurrentBrainrot.GetData then self.CurrentBrainrot:GetData() else nil
	local cashToClaim = self.CashToClaim

	BrainrotIdle.Stop(model)
	self.CurrentBrainrot.Model = nil
	self.CurrentBrainrot:Destroy()
	self.CurrentBrainrot = nil

	model.Parent = nil
	self.BrainrotFolder:ClearAllChildren()
	self.CashToClaim = 0
	table.clear(self.TouchingPartsByPlayer)
	table.clear(self.ClaimedThisTouchByPlayer)

	if not suppressDisplay then
		self:RefreshDisplay()
	end

	return {
		Model = model,
		Data = brainrotData,
		CashToClaim = cashToClaim,
	}
end

function PadServer:RestorePlacedBrainrot(model: Model, cashToClaim: number?, suppressDisplay: boolean?, brainrotData)
	if not self:IsEnabled() or self.CurrentBrainrot or not self.BrainrotSlot or not model then
		return false
	end

	clearInventorySlot(model)
	self.BrainrotFolder:ClearAllChildren()
	model.Parent = self.BrainrotFolder
	self.CurrentBrainrot = self.Framework.Components.BrainrotServer:new(model, self.BrainrotSlot, brainrotData)
	self.CashToClaim = math.max(0, tonumber(cashToClaim) or 0)
	self.LastAccrueAt = os.clock()

	if not suppressDisplay then
		self:RefreshDisplay()
	end

	return true
end

function PadServer:HandleInteract(player: Player)
	if not self:IsEnabled() or not player or not self:IsOwner(player) then
		return
	end

	if self.OperationBusy then
		return
	end

	local inventoryService = self.Framework:GetService("InventoryService")
	if inventoryService.IsInventoryLocked and inventoryService:IsInventoryLocked(player) then
		return
	end

	if not self.CurrentBrainrot then
		self:PlaceBrainrot(player)
		return
	end

	local equippedItem = inventoryService:GetEquippedItem(player)
	if equippedItem and equippedItem.ItemType == "Brainrot" then
		self:ReplaceBrainrot(player)
	else
		self:PickupBrainrot(player)
	end
end

function PadServer:Reset()
	self:SetBusy(false)

	if self.CurrentBrainrot then
		self.CurrentBrainrot:Destroy()
		self.CurrentBrainrot = nil
	end

	self.BrainrotFolder:ClearAllChildren()
	self.CashToClaim = 0
	table.clear(self.TouchingPartsByPlayer)
	table.clear(self.ClaimedThisTouchByPlayer)
	self:RefreshDisplay()
end

function PadServer:CleanUp()
	self:Reset()
end

return PadServer
