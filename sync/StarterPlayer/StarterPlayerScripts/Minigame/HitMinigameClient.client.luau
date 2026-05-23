-- HitMinigameClient
-- Ported from reference game + full cutscene camera system.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local HitEvent = ReplicatedStorage:WaitForChild("HitEvent")
local CarryEvent = ReplicatedStorage:WaitForChild("LuckyBlockCarryEvent")
local CutsceneEvent = ReplicatedStorage:WaitForChild("CutsceneEvent")

local Map = workspace:WaitForChild("Map")
local HitZone = Map:WaitForChild("Safe")

local HitHighlightTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HitLuckyBlock"):WaitForChild("HitHighlight")
HitHighlightTemplate.Enabled = false

local CARRY_ANIM_ID = "rbxassetid://130233565570548"
local HOLD_ANIM_ID = "rbxassetid://128745131098374"

local carryAnimObj = Instance.new("Animation")
carryAnimObj.AnimationId = CARRY_ANIM_ID
local holdAnimObj = Instance.new("Animation")
holdAnimObj.AnimationId = HOLD_ANIM_ID

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({ carryAnimObj, holdAnimObj })
	end)
end)

local localCarryTrack = nil
local localCarryAnimationId = nil
local disabledAnimateScript = nil

local function setAnimateScriptEnabled(isEnabled)
	local char = LocalPlayer.Character
	local animateScript = char and char:FindFirstChild("Animate")
	if isEnabled then
		if disabledAnimateScript and disabledAnimateScript.Parent then
			disabledAnimateScript.Enabled = true
		end
		disabledAnimateScript = nil
		return
	end
	if animateScript and animateScript:IsA("LocalScript") and animateScript.Enabled then
		disabledAnimateScript = animateScript
		animateScript.Enabled = false
	end
end

local function playLocalCarry(animationObj, label)
	local char = LocalPlayer.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	local nextAnimation = animationObj or carryAnimObj
	if localCarryTrack and localCarryTrack.IsPlaying and localCarryAnimationId == nextAnimation.AnimationId then return end
	if localCarryTrack then
		localCarryTrack:Stop(0.1)
		localCarryTrack = nil
		localCarryAnimationId = nil
	end
	local ok, trackOrError = pcall(function()
		local track = animator:LoadAnimation(nextAnimation)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0)
		return track
	end)
	if ok then
		localCarryTrack = trackOrError
		localCarryAnimationId = nextAnimation.AnimationId
	else
		warn("[HitMinigameClient] " .. (label or "Carry") .. " animation failed:", trackOrError)
	end
end

local function stopLocalCarry()
	if localCarryTrack then
		localCarryTrack:Stop(0.1)
		localCarryTrack = nil
		localCarryAnimationId = nil
	end
end

local function restoreLocalAnimateScript()
	setAnimateScriptEnabled(true)
end

local function prepareCharacterForHoldPose()
	local char = LocalPlayer.Character
	if not char then return end
	setAnimateScriptEnabled(false)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.Anchored = true
	end
	if hum then
		hum:Move(Vector3.zero, false)
		hum.WalkSpeed = 0
		hum.AutoRotate = false
		if hum.UseJumpPower then hum.JumpPower = 0 else hum.JumpHeight = 0 end
	end
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0.05) end
	end
end

-- ── GUI ──────────────────────────────────────────────────────────────────────
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local HitMinigame = PlayerGui:WaitForChild("HitMinigame")
local Bar = HitMinigame:WaitForChild("Bar")
local MovingBar = Bar:WaitForChild("MovingBar")
local Charging = HitMinigame:WaitForChild("Charging")
local Message = HitMinigame:WaitForChild("Message")
local HitButton = HitMinigame:WaitForChild("HitButton")
local HitButtonLabel = HitButton:WaitForChild("Label")

HitMinigame.Enabled = true
Bar.Visible = false
Charging.Visible = false
Message.Visible = false
HitButton.Visible = false

local GRADES = {
	{ min = 0.9,  text = "PERFECT", color = Color3.fromRGB(204, 75, 199),  distance = 600 },
	{ min = 0.75, text = "GREAT",   color = Color3.fromRGB(25, 250, 241),   distance = 100 },
	{ min = 0.50, text = "GOOD",    color = Color3.fromRGB(100, 220, 100),  distance = 80  },
	{ min = 0.25, text = "OKAY",    color = Color3.fromRGB(250, 156, 107),  distance = 60  },
	{ min = 0,    text = "BAD",     color = Color3.fromRGB(204, 0, 21),     distance = 40  },
}

local SPEED = 2
local FLASH_SETTINGS = { FadeTime = 0.4 }

local inZone = false
local inMinigame = false
local barScale = 0
local barDirection = 1
local barConn = nil
local chargeReadyAt = 0

local function ResetHitButtonAppearance()
	HitButtonLabel.Text = "HIT!"
	HitButtonLabel.Visible = true
	local buttonScale = HitButton:FindFirstChildOfClass("UIScale")
	if buttonScale then buttonScale.Scale = 1 end
end

local function getGrade(scale)
	for _, g in ipairs(GRADES) do
		if scale >= g.min then return g end
	end
	return GRADES[#GRADES]
end

local function playResultFlash(char)
	if not char then return end
	local oldFlash = char:FindFirstChild("HitResultFlash")
	if oldFlash then oldFlash:Destroy() end
	local highlight = HitHighlightTemplate:Clone()
	highlight.Name = "HitResultFlash"
	highlight.Adornee = char
	highlight.Enabled = true
	highlight.Parent = char
	TweenService:Create(highlight,
		TweenInfo.new(FLASH_SETTINGS.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(highlight, FLASH_SETTINGS.FadeTime + 0.05)
end

local function startMinigame()
	if inMinigame then return end
	inMinigame = true
	barScale = 0
	barDirection = 1
	prepareCharacterForHoldPose()
	playLocalCarry(holdAnimObj, "Hold")
	CarryEvent:FireServer("Hold")
	MovingBar.Size = UDim2.fromScale(1, 0)
	MovingBar.Position = UDim2.fromScale(0.5, 1)
	Message.Text = ""
	Message.Visible = false
	HitButton.Visible = false
	Charging.Visible = true
	Bar.Visible = true
	ResetHitButtonAppearance()
	chargeReadyAt = tick() + 0.15

	local chargingScale = Charging:FindFirstChildOfClass("UIScale")
	if chargingScale then chargingScale:Destroy() end
	chargingScale = Instance.new("UIScale", Charging)
	chargingScale.Scale = 0
	TweenService:Create(chargingScale,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local uiScale = Bar:FindFirstChildOfClass("UIScale")
	if uiScale then uiScale:Destroy() end
	uiScale = Instance.new("UIScale", Bar)
	uiScale.Scale = 0
	TweenService:Create(uiScale,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	barConn = RunService.RenderStepped:Connect(function(dt)
		barScale = barScale + barDirection * SPEED * dt
		if barScale >= 1 then barScale = 1; barDirection = -1
		elseif barScale <= 0 then barScale = 0; barDirection = 1 end
		MovingBar.Size = UDim2.fromScale(1, barScale)
		MovingBar.BackgroundColor3 = Color3.fromRGB(239, 216, 8):Lerp(Color3.fromRGB(168, 240, 93), barScale)
	end)
end

local function commitHit()
	if not inMinigame then return end
	inMinigame = false
	stopLocalCarry()
	if barConn then barConn:Disconnect(); barConn = nil end
	Charging.Visible = false

	local grade = getGrade(barScale)
	local char = LocalPlayer.Character
	CutsceneEvent:FireServer("Start")
	playResultFlash(char)

	if char then
		local leftHand = char:FindFirstChild("LeftHand")
		if leftHand then
			for _, child in ipairs(leftHand:GetChildren()) do
				if child:IsA("Motor6D") and child.Name == "LuckyBlock" then
					local block = child.Part1
					if block then
						block.LocalTransparencyModifier = 1
						for _, v in pairs(block:GetDescendants()) do
							if v:IsA("BasePart") or v:IsA("MeshPart") then
								v.LocalTransparencyModifier = 1
							end
						end
					end
				end
			end
		end
	end

	local uiScale = Bar:FindFirstChildOfClass("UIScale")
	if uiScale then
		TweenService:Create(uiScale,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
	end

	Message.Text = grade.text
	Message.TextColor3 = grade.color
	Message.Visible = true
	local msgScale = Message:FindFirstChildOfClass("UIScale")
	if msgScale then msgScale:Destroy() end
	msgScale = Instance.new("UIScale", Message)
	msgScale.Scale = 0
	TweenService:Create(msgScale,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	ResetHitButtonAppearance()
	HitButton.Visible = false
	HitEvent:FireServer(grade.distance)

	task.delay(2, function()
		if msgScale and msgScale.Parent then
			TweenService:Create(msgScale,
				TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
			task.wait(0.35)
		end
		Message.Visible = false
		Charging.Visible = false
		Bar.Visible = false
	end)
end

-- ── Zone detection ────────────────────────────────────────────────────────────
local touchCount = 0

local function onTouched(hit)
	if inMinigame then return end
	local char = LocalPlayer.Character
	if not char or not hit:IsDescendantOf(char) then return end
	touchCount += 1
	if touchCount == 1 then
		inZone = true
		playLocalCarry(carryAnimObj, "Carry")
		CarryEvent:FireServer(true)
		Bar.Visible = false
		Charging.Visible = false
		Message.Visible = false
		HitButton.Visible = true
		ResetHitButtonAppearance()
	end
end

local function onTouchEnded(hit)
	if inMinigame then return end
	local char = LocalPlayer.Character
	if not char or not hit:IsDescendantOf(char) then return end
	touchCount = math.max(0, touchCount - 1)
	if touchCount == 0 then
		inZone = false
		stopLocalCarry()
		CarryEvent:FireServer(false)
		restoreLocalAnimateScript()
		HitButton.Visible = false
		Charging.Visible = false
		Bar.Visible = false
	end
end

-- ── Cutscene camera ───────────────────────────────────────────────────────────
local cam = workspace.CurrentCamera
local cameraConn = nil

local function disconnectCamera()
	if cameraConn then
		cameraConn:Disconnect()
		cameraConn = nil
	end
end

local function releaseCamera()
	disconnectCamera()
	local char = LocalPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then cam.CameraSubject = humanoid end
	cam.CameraType = Enum.CameraType.Custom
end

local function setCameraFollow(getPosFn, offset)
	disconnectCamera()
	cam.CameraType = Enum.CameraType.Scriptable
	cameraConn = RunService.RenderStepped:Connect(function()
		local pos = getPosFn()
		if typeof(pos) ~= "Vector3" then return end
		cam.CFrame = CFrame.lookAt(pos + offset, pos)
	end)
end

local function setCameraFocus(targetPos, offset, tweenTime)
	disconnectCamera()
	cam.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(cam,
		TweenInfo.new(tweenTime or 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.lookAt(targetPos + offset, targetPos) }):Play()
end

local function getBlockPosition(block)
	if not block or not block.Parent then return nil end
	if block:IsA("Model") then
		local root = block:FindFirstChild("Root")
			or block.PrimaryPart
			or block:FindFirstChildWhichIsA("BasePart", true)
		return root and root.Position or nil
	elseif block:IsA("BasePart") then
		return block.Position
	end
	return nil
end

-- ── Unanchor / restore movement after morph ───────────────────────────────────
local function restoreMovement(walkSpeed)
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	-- prepareCharacterForHoldPose anchored the HRP on the client side.
	-- The server restores its own anchor but cannot clear the client-side flag,
	-- so we must do it explicitly here.
	if hrp then hrp.Anchored = false end
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
		hum.WalkSpeed = walkSpeed or 16
		if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end
	end
end

-- ── Cutscene event handler ────────────────────────────────────────────────────
local function handleCutsceneEvent(eventType, payload)
	if eventType == "Start" then
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local back = -root.CFrame.LookVector
			setCameraFollow(function()
				return root and root.Parent and root.Position or Vector3.zero
			end, back * 10 + Vector3.new(0, 5, 0))
		end

	elseif eventType == "FollowBlock" then
		local block = payload
		if not block then return end
		setCameraFollow(function()
			return getBlockPosition(block)
		end, Vector3.new(0, 14, 22))

	elseif eventType == "FocusReward" then
		local pos = getBlockPosition(payload)
		if pos then setCameraFocus(pos, Vector3.new(0, 16, -12), 0.6) end

	elseif eventType == "FocusOpening" then
		local pos = getBlockPosition(payload)
		if pos then setCameraFocus(pos, Vector3.new(0, 9, -14), 0.35) end

	elseif eventType == "FocusTsunami" then
		if type(payload) ~= "table" then return end
		local focusPos = payload.FocusPosition
		local moveDir = payload.MoveDirection or Vector3.new(1, 0, 0)
		if typeof(focusPos) ~= "Vector3" then return end
		local side = moveDir:Cross(Vector3.new(0, 1, 0)).Unit * 28 + Vector3.new(0, 20, 0)
		local waveRoot = payload.Target
		if waveRoot and waveRoot:IsA("BasePart") then
			setCameraFollow(function()
				return waveRoot and waveRoot.Parent and waveRoot.Position or focusPos
			end, side)
		else
			setCameraFocus(focusPos, side, 0.4)
		end

	elseif eventType == "Release" or eventType == "End" then
		releaseCamera()
		restoreLocalAnimateScript()
		local ws = type(payload) == "table" and payload.WalkSpeed or nil
		restoreMovement(ws)
	end
end

-- ── Wire up ───────────────────────────────────────────────────────────────────
local function connectEvents()
	HitButton.MouseButton1Click:Connect(function()
		if not inMinigame then startMinigame() end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not inMinigame then return end
		if tick() < chargeReadyAt then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA then
			commitHit()
		end
	end)

	LocalPlayer.CharacterAdded:Connect(function()
		disabledAnimateScript = nil
		disconnectCamera()
	end)

	HitZone.Touched:Connect(onTouched)
	HitZone.TouchEnded:Connect(onTouchEnded)
end

local function connectBindables() end

local function connectRemotes()
	CutsceneEvent.OnClientEvent:Connect(handleCutsceneEvent)
end

connectEvents()
connectBindables()
connectRemotes()
print("[HitMinigameClient] Started")
