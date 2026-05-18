local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = require(ReplicatedStorage:WaitForChild("Framework"))

local HitGUIController = Framework:CreateController("HitGUIController")

local HIT_TYPES = {
	{ Name = "Bad", Min = 0, Max = 0.2 },
	{ Name = "Mid", Min = 0.2, Max = 0.4 },
	{ Name = "Good", Min = 0.4, Max = 0.6 },
	{ Name = "Great", Min = 0.6, Max = 0.8 },
	{ Name = "Excellent", Min = 0.8, Max = 0.96 },
	{ Name = "Perfect", Min = 0.96, Max = 1 },
}

function HitGUIController:Initialize()
	self.Player = Players.LocalPlayer
	self.StartHitService = Framework:GetService("StartHitService")
	self.GuiController = Framework.Utils.GuiController

	self.HitMinigameGui = nil
	self.HitButton = nil
	self.ChargingLabel = nil
	self.MessageLabel = nil
	self.Bar = nil
	self.MovingBar = nil

	self._charging = false
	self._inputConnection = nil
	self._barTween = nil
	self._gradientConnection = nil
	self._holdTrack = nil
	self._highlight = nil
	self._anchoredRoot = nil
	self._controls = nil

	self:_initGuiController()
end

function HitGUIController:Start()
	self:_bindHitGui()
	self:_bindHitButton()
end

function HitGUIController:_initGuiController()
	local playerGui = self.Player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD", 30)

	local allGuis = {}

	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child ~= hud then
			table.insert(allGuis, child)
		end
	end

	self.GuiController:Init(hud, allGuis)

	local hitMinigameGui = playerGui:WaitForChild("HitMinigame", 30)

	if hitMinigameGui then
		self.GuiController:RegisterGui(hitMinigameGui)
		self.GuiController:SetConstantGui(hitMinigameGui, true)
		self.GuiController:SetNonEffectGui(hitMinigameGui, true)
	end

	local playerModule = self.Player:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")

	if playerModule then
		local ok, module = pcall(require, playerModule)

		if ok and module and module.GetControls then
			self._controls = module:GetControls()
		end
	end
end

function HitGUIController:_bindHitGui()
	local playerGui = self.Player:WaitForChild("PlayerGui")

	self.HitMinigameGui = playerGui:WaitForChild("HitMinigame", 30)

	if not self.HitMinigameGui then
		warn("[HitGUIController] Missing HitMinigame gui")
		return
	end

	self.HitButton = self.HitMinigameGui:WaitForChild("HitButton", 10)
	self.ChargingLabel = self.HitMinigameGui:WaitForChild("Charging", 10)
	self.MessageLabel = self.HitMinigameGui:WaitForChild("Message", 10)
	self.Bar = self.HitMinigameGui:WaitForChild("Bar", 10)
	self.MovingBar = self.Bar and self.Bar:WaitForChild("MovingBar", 10)

	if not (self.HitButton and self.ChargingLabel and self.MessageLabel and self.Bar and self.MovingBar) then
		warn("[HitGUIController] Missing HitMinigame UI elements")
		return
	end

	self.Bar.Visible = false
	self.ChargingLabel.Visible = false
	self.MessageLabel.Visible = false
	self.MessageLabel.Text = ""
	self.MovingBar.Size = UDim2.fromScale(1, 0)
end

function HitGUIController:_bindHitButton()
	if not self.HitButton then
		return
	end

	self.HitButton.Activated:Connect(function()
		self:StartCharge()
	end)

	self:_bindButtonHover()
end

function HitGUIController:_bindButtonHover()
	local scale = self.HitButton:FindFirstChildOfClass("UIScale")

	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = self.HitButton
	end

	self.HitButton.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), {
			Scale = 1.06,
		}):Play()
	end)

	self.HitButton.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), {
			Scale = 1,
		}):Play()
	end)
end

function HitGUIController:StartCharge()
	if self._charging then
		return
	end

	if not (self.HitButton and self.ChargingLabel and self.MessageLabel and self.Bar and self.MovingBar) then
		return
	end

	self._charging = true
	self:_setHitButtonSuppressed(true)

	if self._controls then
		self._controls:Disable()
	end

	self.HitButton.Visible = false
	self.MessageLabel.Text = ""
	self.MessageLabel.Visible = true
	self.Bar.Visible = true
	self.ChargingLabel.Visible = true
	self.MovingBar.Size = UDim2.fromScale(1, 0)

	self._barTween = TweenService:Create(
		self.MovingBar,
		TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, true),
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(237, 142, 26),
		}
	)

	self._barTween:Play()

	self:_playHoldEffects()

	task.delay(0.08, function()
		if not self._charging then
			return
		end

		self._inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				self:FinishCharge()
			end
		end)
	end)
end

function HitGUIController:FinishCharge()
	if not self._charging then
		return
	end

	self._charging = false

	if self._inputConnection then
		self._inputConnection:Disconnect()
		self._inputConnection = nil
	end

	if self._barTween then
		self._barTween:Pause()
	end

	local barValue = math.clamp(self.MovingBar.Size.Y.Scale, 0, 1)

	if barValue >= 0.96 then
		barValue = 1
		self.MovingBar.Size = UDim2.fromScale(1, 1)
	end

	local character = self.Player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

	if humanoidRootPart then
		local position = humanoidRootPart.Position
		humanoidRootPart.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0)
		humanoidRootPart.Anchored = true
		self._anchoredRoot = humanoidRootPart
	end

	self:_stopHoldEffects(true)

	local origin, direction = self:_getAimRay()

	if not origin or not direction then
		origin, direction = self:_getCharacterAim()
	end

	local ok, result = pcall(function()
		return self.StartHitService:StartHit(origin, direction, barValue)
	end)

	if not ok then
		warn("[HitGUIController] StartHit failed:", result)
	elseif not result or not result.Ok then
		warn("[HitGUIController] StartHit denied:", result and result.Reason)
	end

	self:_showHitMessage(barValue)

	task.delay(1.75, function()
		self:_resetAfterHit()
	end)
end

function HitGUIController:_getAimRay()
	local camera = workspace.CurrentCamera

	if not camera then
		return nil, nil
	end

	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X * 0.5, viewport.Y * 0.5)

	return ray.Origin, ray.Direction
end

function HitGUIController:_getCharacterAim()
	local character = self.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return nil, nil
	end

	return root.Position + Vector3.yAxis * 2, root.CFrame.LookVector
end

function HitGUIController:_getHitType(barValue: number): string
	for _, hitType in ipairs(HIT_TYPES) do
		if hitType.Name == "Perfect" then
			if barValue >= hitType.Min and barValue <= hitType.Max then
				return hitType.Name
			end
		elseif barValue >= hitType.Min and barValue < hitType.Max then
			return hitType.Name
		end
	end

	return "Bad"
end

function HitGUIController:_showHitMessage(barValue: number)
	local hitType = self:_getHitType(barValue)

	self.MessageLabel.Text = hitType
	self.MessageLabel.Visible = true

	local gradient = self.MessageLabel:FindFirstChild(hitType)

	if gradient and gradient:IsA("UIGradient") then
		gradient.Enabled = true

		if hitType == "Perfect" then
			local offset = 0

			self._gradientConnection = RunService.Heartbeat:Connect(function(dt)
				offset = (offset + dt * 1.5) % 2
				gradient.Offset = Vector2.new(offset - 1, 0)
			end)
		end
	end
end

function HitGUIController:_playHoldEffects()
	local character = self.Player.Character

	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animations = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HitLuckyBlock"):FindFirstChild("Animations")
	local holdAnim = animations and animations:FindFirstChild("HoldAnim")

	if animator and holdAnim and holdAnim:IsA("Animation") then
		local holdTrack = animator:LoadAnimation(holdAnim)
		holdTrack.Priority = Enum.AnimationPriority.Action
		holdTrack.Looped = true
		holdTrack:Play()

		self._holdTrack = holdTrack
	end

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.Enabled = true
	highlight.Parent = character

	self._highlight = highlight
end

function HitGUIController:_stopHoldEffects(flashHighlight: boolean)
	if self._holdTrack then
		self._holdTrack:Stop()
		self._holdTrack:Destroy()
		self._holdTrack = nil
	end

	local highlight = self._highlight
	self._highlight = nil

	if not highlight then
		return
	end

	if not flashHighlight then
		highlight:Destroy()
		return
	end

	highlight.FillTransparency = 0

	local tween = TweenService:Create(
		highlight,
		TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			FillTransparency = 1,
		}
	)

	tween.Completed:Once(function()
		highlight:Destroy()
	end)

	tween:Play()
end

function HitGUIController:_resetAfterHit()
	if self._gradientConnection then
		self._gradientConnection:Disconnect()
		self._gradientConnection = nil
	end

	if self.MessageLabel then
		for _, child in ipairs(self.MessageLabel:GetChildren()) do
			if child:IsA("UIGradient") then
				child.Enabled = false
			end
		end

		self.MessageLabel.Text = ""
		self.MessageLabel.Visible = false
	end

	if self.Bar then
		self.Bar.Visible = false
	end

	if self.ChargingLabel then
		self.ChargingLabel.Visible = false
	end

	if self._anchoredRoot then
		self._anchoredRoot.Anchored = false
		self._anchoredRoot = nil
	end

	if self._controls then
		self._controls:Enable()
	end

	self:_setHitButtonSuppressed(false)
end

function HitGUIController:_setHitButtonSuppressed(suppressed: boolean)
	local hitMinigameController = Framework:GetController("HitMinigameController")

	if hitMinigameController and hitMinigameController.SetHitButtonSuppressed then
		hitMinigameController:SetHitButtonSuppressed(suppressed)
		return
	end

	if self.HitButton then
		self.HitButton.Visible = not suppressed
	end
end

return HitGUIController