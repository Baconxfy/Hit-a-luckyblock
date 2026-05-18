local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local HitMinigame = script.Parent
local HitButton = HitMinigame:WaitForChild("HitButton")

HitMinigame.Enabled = true
HitButton.Visible = false

local HitZone = workspace:WaitForChild("Zones"):WaitForChild("HitZone")
local touchCount = 0

HitZone.Touched:Connect(function(hit)
	local char = LocalPlayer.Character
	if not char or not hit:IsDescendantOf(char) then return end
	touchCount += 1
	if touchCount == 1 then
		HitButton.Visible = true
	end
end)

HitZone.TouchEnded:Connect(function(hit)
	local char = LocalPlayer.Character
	if not char or not hit:IsDescendantOf(char) then return end
	touchCount = math.max(0, touchCount - 1)
	if touchCount == 0 then
		HitButton.Visible = false
	end
end)

LocalPlayer.CharacterAdded:Connect(function()
	touchCount = 0
	HitButton.Visible = false
end)