local Framework = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"))
local HitGUIController = Framework:CreateController("HitGUIController")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HIT_TYPES = {
	{ name = "Bad", min = 0, max = 0.2 },
	{ name = "Mid", min = 0.2, max = 0.4 },
	{ name = "Good", min = 0.4, max = 0.6 },
	{ name = "Great", min = 0.6, max = 0.8 },
	{ name = "Excellent", min = 0.8, max = 0.96 },
	{ name = "Perfect", min = 0.96, max = 1 },
}

function HitGUIController:Initialize() end

function HitGUIController:Start()
	self.StartHitService = Framework:GetService("StartHitService")
	local LocalPlayer = Players.LocalPlayer
	local InputConn = nil

	local PlayerModule = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"))
	local Controls = PlayerModule and PlayerModule:GetControls()

	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	local HitMinigameGUi = PlayerGui:WaitForChild("HitMinigame")
	if not HitMinigameGUi then
		return
	end

	local HitButton = HitMinigameGUi:FindFirstChild("HitButton")
	local ChargingLabel = HitMinigameGUi:FindFirstChild("Charging")
	local MessageLabel = HitMinigameGUi:FindFirstChild("Message")
	local Bar_CanvasGroup = HitMinigameGUi:FindFirstChild("Bar")
	local MovingBar = Bar_CanvasGroup and Bar_CanvasGroup:FindFirstChild("MovingBar")

	if not (HitButton and ChargingLabel and MessageLabel and Bar_CanvasGroup and MovingBar) then
		return
	end

	MessageLabel.Text = ""
	MessageLabel.Visible = false
	Bar_CanvasGroup.Visible = false
	ChargingLabel.Visible = false

	local TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, true)
	local TWEEN_INFO2 = TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local Tween = TweenService:Create(MovingBar, TWEEN_INFO, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(237, 142, 26),
	})

	local isClicking = false
	HitButton.MouseButton1Click:Connect(function()
		if isClicking then
			return
		end
		isClicking = true

		if InputConn then
			InputConn:Disconnect()
			InputConn = nil
		end

		if Controls then
			Controls:Disable()
		end
		HitButton.Visible = false

		MessageLabel.Text = ""
		MessageLabel.Visible = true
		Bar_CanvasGroup.Visible = true
		ChargingLabel.Visible = true

		MovingBar.Size = UDim2.fromScale(1, 0)
		Tween:Play()

		local Character = LocalPlayer.Character
		if not Character then
			isClicking = false
			return
		end

		local Humanoid = Character:FindFirstChild("Humanoid")
		local Animator = Humanoid and Humanoid:FindFirstChild("Animator")
		local HumanoidRootPart = Character.PrimaryPart
		if not (Animator and HumanoidRootPart) then
			isClicking = false
			return
		end

		local HoldAnim = ReplicatedStorage:WaitForChild("Assets")
			:WaitForChild("HitLuckyBlock")
			:WaitForChild("Animations")
			:WaitForChild("HoldAnim")
		local HoldAnimTrack = Animator:LoadAnimation(HoldAnim)
		HoldAnimTrack.Priority = Enum.AnimationPriority.Action
		HoldAnimTrack.Looped = true
		HoldAnimTrack:Play()

		local Highlight = Instance.new("Highlight")
		Highlight.FillTransparency = 1
		Highlight.OutlineTransparency = 1
		Highlight.FillColor = Color3.fromRGB(255, 255, 255)
		Highlight.Enabled = true
		Highlight.Parent = Character

		InputConn = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				InputConn:Disconnect()
				InputConn = nil

				Tween:Pause()

				local TweenHighlight = TweenService:Create(Highlight, TWEEN_INFO2, {
					FillTransparency = 1,
				})

				TweenHighlight.Completed:Once(function()
					TweenHighlight:Destroy()
					TweenHighlight = nil
					task.wait()
					Highlight:Destroy()
				end)

				Highlight.FillTransparency = 0
				TweenHighlight:Play()

				local barValue = MovingBar.Size.Y.Scale
				if barValue >= 0.96 then
					MovingBar.Size = UDim2.fromScale(1, 1)
					barValue = 1
				end

				local Pos = HumanoidRootPart.Position
				HumanoidRootPart.CFrame = CFrame.new(Pos) * CFrame.Angles(0, math.rad(90), 0)
				HumanoidRootPart.Anchored = true

				HoldAnimTrack:Destroy()
				HoldAnimTrack = nil
				self.StartHitService.Fire:StartHit(barValue)

				local hitType = "Bad"
				for _, data in ipairs(HIT_TYPES) do
					if data.name == "Perfect" then
						if barValue >= data.min and barValue <= data.max then
							hitType = data.name
							break
						end
					else
						if barValue >= data.min and barValue < data.max then
							hitType = data.name
							break
						end
					end
				end

				local gradient = MessageLabel:FindFirstChild(hitType)
				local gradientEffectConn = nil
				if gradient then
					gradient.Enabled = true
					if hitType == "Perfect" then
						gradientEffectConn = RunService.Heartbeat:Connect(function(deltaTime)
							local limit = 0.85
							local step = deltaTime * 1.5
							local Xval = gradient.Offset.X
							if Xval >= limit then
								Xval = -limit
							elseif Xval <= -limit then
								Xval = limit
							end
							Xval = Xval + step
							gradient.Offset = Vector2.new(Xval, gradient.Offset.Y)
						end)
					end
				end

				MessageLabel.Text = hitType

				task.wait(1.25)

				-- Unlock Gui
				if Controls then
					Controls:Enable()
				end
				HitMinigameGUi.Enabled = false

				task.wait(0.5)

				if gradientEffectConn then
					gradientEffectConn:Disconnect()
					gradientEffectConn = nil
				end

				if gradient then
					gradient.Enabled = false
				end

				MessageLabel.Text = ""
				MessageLabel.Visible = false
				Bar_CanvasGroup.Visible = false
				ChargingLabel.Visible = false

				HitButton.Visible = true
				isClicking = false
			end
		end)
	end)
end

return HitGUIController
