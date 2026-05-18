local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local HitMinigameController = Framework:CreateController("HitMinigameController")

function HitMinigameController:Initialize()
	self.Player = Players.LocalPlayer
	self.TouchingParts = {}
	self.HitMinigame = nil
	self.HitButton = nil
	self.HitZone = nil
	self.ButtonSuppressed = false
end

function HitMinigameController:Start()
	self:_bindGui()
	self:_bindHitZone()
	self:_bindCharacterReset()
end

function HitMinigameController:_bindGui()
	local playerGui = self.Player:WaitForChild("PlayerGui")

	self.HitMinigame = playerGui:WaitForChild("HitMinigame")
	self.HitButton = self.HitMinigame:WaitForChild("HitButton")

	self.HitMinigame.Enabled = true
	self:RefreshHitButton()
end

function HitMinigameController:_bindHitZone()
	local zones = workspace:WaitForChild("Zones")
	self.HitZone = zones:WaitForChild("HitZone")

	self.HitZone.Touched:Connect(function(hit)
		self:_onHitZoneTouched(hit)
	end)

	self.HitZone.TouchEnded:Connect(function(hit)
		self:_onHitZoneTouchEnded(hit)
	end)
end

function HitMinigameController:_bindCharacterReset()
	self.Player.CharacterAdded:Connect(function()
		self.TouchingParts = {}
		self.ButtonSuppressed = false
		self:RefreshHitButton()
	end)
end

function HitMinigameController:_isLocalCharacterPart(hit: Instance): boolean
	local character = self.Player.Character

	if not character then
		return false
	end

	return hit:IsDescendantOf(character)
end

function HitMinigameController:IsInHitZone(): boolean
	return next(self.TouchingParts) ~= nil
end

function HitMinigameController:SetHitButtonSuppressed(suppressed: boolean)
	self.ButtonSuppressed = suppressed == true
	self:RefreshHitButton()
end

function HitMinigameController:RefreshHitButton()
	if not self.HitButton then
		return
	end

	self.HitButton.Visible = self:IsInHitZone() and not self.ButtonSuppressed
end

function HitMinigameController:_onHitZoneTouched(hit: Instance)
	if not self:_isLocalCharacterPart(hit) then
		return
	end

	self.TouchingParts[hit] = true
	self:RefreshHitButton()
end

function HitMinigameController:_onHitZoneTouchEnded(hit: Instance)
	if not self:_isLocalCharacterPart(hit) then
		return
	end

	self.TouchingParts[hit] = nil
	self:RefreshHitButton()
end

return HitMinigameController