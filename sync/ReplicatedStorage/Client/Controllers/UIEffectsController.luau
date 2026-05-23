local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local UIEffectsController = Framework:CreateController("UIEffectsController")

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

function UIEffectsController:Start()
	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	local HUD = PlayerGui:WaitForChild("HUD")
	
	-- Run UI effect
	local runGui = HUD:WaitForChild("Run")
	local runColor1 = Color3.fromRGB(77, 0, 1)
	local runColor2 = Color3.fromRGB(39, 0, 1)
	local runTween = nil
	
	local function updateRunTween()
		if runTween then
			runTween:Cancel()
			runTween = nil
		end
		if runGui.Visible then
			runGui.BackgroundColor3 = runColor1
			runTween = TweenService:Create(runGui, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				BackgroundColor3 = runColor2
			})
			runTween:Play()
		end
	end
	runGui:GetPropertyChangedSignal("Visible"):Connect(updateRunTween)
	task.spawn(updateRunTween)
	
	-- WaveBlur UI effect
	local waveBlurGui = HUD:WaitForChild("WaveBlur")
	local waveBlurTween = nil
	
	local function updateWaveBlurTween()
		if waveBlurTween then
			waveBlurTween:Cancel()
			waveBlurTween = nil
		end
		if waveBlurGui.Visible then
			waveBlurGui.ImageTransparency = 0.85
			waveBlurTween = TweenService:Create(waveBlurGui, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				ImageTransparency = 0.55
			})
			waveBlurTween:Play()
		end
	end
	waveBlurGui:GetPropertyChangedSignal("Visible"):Connect(updateWaveBlurTween)
	task.spawn(updateWaveBlurTween)
	
	-- UIGradient rotation effect for Store button
	local storeGradient = HUD:WaitForChild("LeftButtons"):WaitForChild("Store"):WaitForChild("UIGradient")
	task.spawn(function()
		while true do
			TweenService:Create(storeGradient, TweenInfo.new(20, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
				Rotation = 360
			}):Play()
			task.wait(20)
			storeGradient.Rotation = 0
		end
	end)
end

return UIEffectsController
