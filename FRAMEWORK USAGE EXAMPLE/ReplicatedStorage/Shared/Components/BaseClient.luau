local ReplicatedStorage = game:GetService('ReplicatedStorage')
local BaseComponent = require(ReplicatedStorage:WaitForChild('Shared').Components:FindFirstChild('BaseComponent', true) :: ModuleScript)

local BaseClient = BaseComponent:Extend('BaseClient')


function BaseClient:Create(baseFolder: Folder)
	if not baseFolder then
		warn('[BaseClient] Missing base folder')
		return
	end

	self.BaseFolder = baseFolder
	self.SpawnLocation = baseFolder:FindFirstChildWhichIsA('SpawnLocation', true)
	self.Pads = {}
	self.PadUpgrade = nil
	self.FridgeUpgrade = nil
	self.MicrowaveUpgrade = nil

	local padsFolder = baseFolder:FindFirstChild('Pads', true)
	if not padsFolder then
		warn(('[BaseClient] %s is missing Pads'):format(baseFolder:GetFullName()))
		return
	end

	for _, padModel in ipairs(padsFolder:GetChildren()) do
		if padModel:IsA('Model') then
			local pad = self.Framework.Components.PadClient:new(padModel)
			table.insert(self.Pads, pad)
			self:AddChild(pad)
		end
	end

	local padUpgrade = baseFolder:FindFirstChild('PadUpgrade', true) or baseFolder:FindFirstChild('Pad Upgrade', true)
	if padUpgrade and padUpgrade:IsA('Model') then
		self.PadUpgrade = self.Framework.Components.PadUpgradeClient:new(padUpgrade)
		self:AddChild(self.PadUpgrade)
	end

	local fridgeUpgrade = baseFolder:FindFirstChild('FridgeUpgrade', true) or baseFolder:FindFirstChild('Fridge Upgrade', true)
	if fridgeUpgrade and fridgeUpgrade:IsA('Model') then
		self.FridgeUpgrade = self.Framework.Components.FridgeUpgradeClient:new(fridgeUpgrade)
		self:AddChild(self.FridgeUpgrade)
	end

	local microwaveUpgrade = baseFolder:FindFirstChild('MicrowaveUpgrade', true) or baseFolder:FindFirstChild('Microwave Upgrade', true)
	if microwaveUpgrade and microwaveUpgrade:IsA('Model') then
		self.MicrowaveUpgrade = self.Framework.Components.MicrowaveUpgradeClient:new(microwaveUpgrade)
		self:AddChild(self.MicrowaveUpgrade)
	end
end

function BaseClient:ApplyPadUpgradeState(state)
	if self.PadUpgrade then
		self.PadUpgrade:ApplyState(state)
	end
end

function BaseClient:ApplyFridgeUpgradeState(state)
	if self.FridgeUpgrade then
		self.FridgeUpgrade:ApplyState(state)
	end
end

function BaseClient:ApplyMicrowaveUpgradeState(state)
	if self.MicrowaveUpgrade then
		self.MicrowaveUpgrade:ApplyState(state)
	end
end

return BaseClient
