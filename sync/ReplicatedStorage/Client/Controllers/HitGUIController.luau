local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local HitGUIController = Framework:CreateController("HitGUIController")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blink = require(ReplicatedStorage:WaitForChild("Blink"):WaitForChild("Client"))
local TitleEffectManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Vfx"):WaitForChild("TitleEffectManager"))
local GuiLibrary = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("GuiLibrary"))
local GuiController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("GuiController"))

local HIT_TYPES = {
	{name = "Bad",       min = 0,    max = 0.2},
	{name = "Mid",       min = 0.2,  max = 0.4},
	{name = "Good",      min = 0.4,  max = 0.6},
	{name = "Great",     min = 0.6,  max = 0.8},
	{name = "Excellent", min = 0.8,  max = 0.96},
	{name = "Perfect",   min = 0.96, max = 1},
}

function HitGUIController:Initialize()
	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

	local HUD = PlayerGui:WaitForChild("HUD", 30)
	local allGuis = {}
	for _, v in ipairs(PlayerGui:GetChildren()) do
		if v:IsA("ScreenGui") and v ~= HUD then
			table.insert(allGuis, v)
		end
	end
	GuiController:Init(HUD, allGuis)

	-- HitMinigame visibility is handled by HitZoneDetector (LocalScript inside it).
	-- Register as constant so GuiController never disables it.
	local HitMinigameGui = PlayerGui:WaitForChild("HitMinigame", 30)
	if HitMinigameGui then
		GuiController:RegisterGui(HitMinigameGui)
		GuiController:SetConstantGui(HitMinigameGui, true)
		GuiController:SetNonEffectGui(HitMinigameGui, true)
	end
end

function HitGUIController:Start()
	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	local InputConn = nil

	local Controls = GuiController:GetVariable("PlayerModule")
	if Controls then Controls = Controls:GetControls() end

	local HitMinigameGui = PlayerGui:WaitForChild("HitMinigame", 30)
	if not HitMinigameGui then return end

	local HitButton       = HitMinigameGui:WaitForChild("HitButton", 10)
	local ChargingLabel   = HitMinigameGui:WaitForChild("Charging", 10)
	local MessageLabel    = HitMinigameGui:WaitForChild("Message", 10)
	local Bar_CanvasGroup = HitMinigameGui:WaitForChild("Bar", 10)
	local MovingBar       = Bar_CanvasGroup and Bar_CanvasGroup:WaitForChild("MovingBar", 10)

	if not (HitButton and ChargingLabel and MessageLabel and Bar_CanvasGroup and MovingBar) then
		warn("[HitGUIController] Missing UI elements")
		return
	end

	local TWEEN_INFO  = TweenInfo.new(.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, true)
	local TWEEN_INFO2 = TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local Tween = TweenService:Create(MovingBar, TWEEN_INFO, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(237, 142, 26),
	})

	GuiLibrary.Button.OnClick(HitButton, function(inputObj, clickCount)
		if InputConn then InputConn:Disconnect(); InputConn = nil end
		if Controls then Controls:Disable() end

		HitButton.Visible       = false
		MessageLabel.Text       = ""
		MessageLabel.Visible    = true
		Bar_CanvasGroup.Visible = true
		ChargingLabel.Visible   = true

		MovingBar.Size = UDim2.fromScale(1, 0)
		Tween:Play()

		local Character = LocalPlayer.Character
		if not Character then return end

		local Humanoid         = Character:FindFirstChild("Humanoid")
		local Animator         = Humanoid and Humanoid:FindFirstChild("Animator")
		local HumanoidRootPart = Character.PrimaryPart
		if not (Animator and HumanoidRootPart) then return end

		local HoldAnim = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HitLuckyBlock"):WaitForChild("Animations"):WaitForChild("HoldAnim")
		local HoldAnimTrack = Animator:LoadAnimation(HoldAnim)
		HoldAnimTrack.Priority = Enum.AnimationPriority.Action
		HoldAnimTrack.Looped = true
		HoldAnimTrack:Play()

		local Highlight = Instance.new("Highlight")
		Highlight.FillTransparency = 1
		Highlight.OutlineTransparency = 1
		Highlight.FillColor = Color3.fromRGB(255,255,255)
		Highlight.Enabled = true
		Highlight.Parent = Character

		InputConn = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				InputConn:Disconnect()
				InputConn = nil
				Tween:Pause()

				local TweenHighlight = TweenService:Create(Highlight, TWEEN_INFO2, { FillTransparency = 1 })
				TweenHighlight.Completed:Once(function()
					TweenHighlight:Destroy()
					task.wait()
					Highlight:Destroy()
				end)
				Highlight.FillTransparency = 0
				TweenHighlight:Play()

				local barValue = MovingBar.Size.Y.Scale
				if barValue >= 0.96 then MovingBar.Size = UDim2.fromScale(1,1); barValue = 1 end

				local Pos = HumanoidRootPart.Position
				HumanoidRootPart.CFrame = CFrame.new(Pos) * CFrame.Angles(0, math.rad(90), 0)
				HumanoidRootPart.Anchored = true

				HoldAnimTrack:Stop(); HoldAnimTrack:Destroy(); HoldAnimTrack = nil
				Blink.StartHit.Fire(barValue)

				local hitType = "Bad"
				for _, data in ipairs(HIT_TYPES) do
					if data.name == "Perfect" then
						if barValue >= data.min and barValue <= data.max then hitType = data.name; break end
					else
						if barValue >= data.min and barValue < data.max then hitType = data.name; break end
					end
				end

				local gradient = MessageLabel:FindFirstChild(hitType)
				local gradientEffectConn = nil
				if gradient then
					gradient.Enabled = true
					if hitType == "Perfect" then
						gradientEffectConn = RunService.Heartbeat:Connect(function(dt)
							TitleEffectManager.HorizontalEffect(gradient, dt * 1.5, .85)
						end)
					end
				end

				MessageLabel.Text = hitType
				task.wait(1.25)

				Bar_CanvasGroup.Visible = false
				ChargingLabel.Visible   = false
				task.wait(0.5)

				if gradientEffectConn then gradientEffectConn:Disconnect() end
				if gradient then gradient.Enabled = false end
				MessageLabel.Text    = ""
				MessageLabel.Visible = false
				-- HitButton.Visible is owned by HitZoneDetector — it will re-show if still in zone
			end
		end)
	end, true, true)

	GuiLibrary.Button.Hover(HitButton, nil, nil, true, true)
end

return HitGUIController