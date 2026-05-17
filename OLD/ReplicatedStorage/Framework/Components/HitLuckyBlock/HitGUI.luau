--< Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--< Modules
local Blink = require(ReplicatedStorage:WaitForChild("Blink"):WaitForChild("Client"))
local TitleEffectManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Vfx"):WaitForChild("TitleEffectManager"))
local GuiLibrary = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("GuiLibrary"))
local GuiController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("GuiController"))

--< Resources
local Assets = ReplicatedStorage:WaitForChild("Assets")

local HitLuckyBlockAssets = Assets.HitLuckyBlock
local AnimationsFolder = HitLuckyBlockAssets.Animations
local HoldAnim = AnimationsFolder.HoldAnim

--< Constants
local TWEEN_INFO = TweenInfo.new(.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, true)
local TWEEN_INFO2 = TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out)


-- Ordered array to guarantee evaluation order and cover all ranges without gaps
local HIT_TYPES = {
	{name = "Bad",       min = 0,    max = 0.2},
	{name = "Mid",       min = 0.2,  max = 0.4},
	{name = "Good",      min = 0.4,  max = 0.6},
	{name = "Great",     min = 0.6,  max = 0.8},
	{name = "Excellent", min = 0.8,  max = 0.96},
	{name = "Perfect",   min = 0.96, max = 1},
}

--< Variables
local LocalPlayer = Players.LocalPlayer
local InputConn: RBXScriptConnection

return function()

	local Controls = GuiController:GetVariable("PlayerModule"):GetControls()

	local HitMinigameGUi: ScreenGui = GuiController:GetGui("HitMinigame")
	GuiController:SetNonEffectGui(HitMinigameGUi, true)

	local MainFrame: Frame = HitMinigameGUi:FindFirstChildOfClass("Frame")
	local HitButton: ImageButton = MainFrame:FindFirstChild("HitButton")

	local ChargingLabel: TextLabel = MainFrame:FindFirstChild("Charging")
	local MessageLabel: TextLabel = MainFrame:FindFirstChild("Message")

	local Bar_CanvasGroup: CanvasGroup = MainFrame:FindFirstChild("Bar")
	local MovingBar: Frame = Bar_CanvasGroup:FindFirstChild("MovingBar")

	MessageLabel.Text = ""

	MessageLabel.Visible = false
	Bar_CanvasGroup.Visible = false
	ChargingLabel.Visible = false

	local MESSAGE_SIZE = MessageLabel.Size
	local BAR_SIZE = Bar_CanvasGroup.Size
	local CHARGING_SIZE = ChargingLabel.Size
	local ZERO_SIZE = UDim2.fromScale(0, 0)

	MovingBar.Size = UDim2.fromScale(1, 0)
	local Tween = TweenService:Create(MovingBar, TWEEN_INFO, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(237, 142, 26),
	})
	Tween:Play()

	GuiLibrary.Button.OnClick(HitButton, function(inputObj: InputObject, clickCount: number)
		if InputConn then
			InputConn:Disconnect()
			InputConn = nil
		end

		Controls:Disable()
		HitButton.Visible = false

		MessageLabel.Text = ""
		MessageLabel.Visible = true
		Bar_CanvasGroup.Visible = true
		ChargingLabel.Visible = true
		

		local Character = LocalPlayer.Character
		if not Character then return end

		local Humanoid :Humanoid = Character:FindFirstChild("Humanoid")
		local Animator :Animator = Humanoid:FindFirstChild("Animator")
		
		local HumanoidRootPart :BasePart = Character.PrimaryPart
		
		local HoldAnimTrack :AnimationTrack = Animator:LoadAnimation(HoldAnim)
		HoldAnimTrack.Priority = Enum.AnimationPriority.Action
		HoldAnimTrack.Looped = true
		HoldAnimTrack:Play()
		
		local Highlight = Instance.new("Highlight")
		Highlight.FillTransparency = 1
		Highlight.OutlineTransparency = 1
		Highlight.FillColor = Color3.fromRGB(255,255,255)
		Highlight.Enabled = true
		Highlight.Parent = Character

		InputConn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				InputConn:Disconnect()
				InputConn = nil

				Tween:Pause()
				
				local TweenHighlight = TweenService:Create(Highlight, TWEEN_INFO2, {
					FillTransparency = 1
				})
				
				TweenHighlight.Completed:Once(function(playbackState: Enum.PlaybackState) 
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
				
				HoldAnimTrack:Stop()
				HoldAnimTrack:Destroy()
				HoldAnimTrack = nil
				Blink.StartHit.Fire(barValue)
				
				-- Determine the hit type using ipairs over the ordered array
				local hitType: string = "Bad" -- default
				for _, data in ipairs(HIT_TYPES) do
					-- Use < on max except for the last range (Perfect) to avoid overlaps
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

				local gradient: UIGradient = MessageLabel:FindFirstChild(hitType)
				local gradientEffectConn: RBXScriptConnection = nil
				if gradient then
					gradient.Enabled = true
					if hitType == "Perfect" then
						gradientEffectConn = RunService.Heartbeat:Connect(function(deltaTime: number)
							TitleEffectManager.HorizontalEffect(gradient, deltaTime * 1.5, .85)
						end)
					end
				end

				MessageLabel.Text = hitType

				task.wait(1.25)
				GuiController:UnlockGui(HitMinigameGUi)
				GuiController:CloseMainFrame(MainFrame)

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
			end
		end)
		
	end, true, true)
	
	GuiLibrary.Button.Hover(HitButton, nil, nil, true, true)
end