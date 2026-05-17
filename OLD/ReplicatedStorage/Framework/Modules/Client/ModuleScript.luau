--< Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--< Modules

--< Resources
local Assets = ReplicatedStorage:WaitForChild("Assets")
local LuckyBlockTemplate = Assets:WaitForChild("LuckyBlock")
local BaseballTemplate = Assets:WaitForChild("Baseball")

--< Constants
local HIT_ANIM_ID = "rbxassetid://109049329968119"
local CARRY_ANIM_ID = "rbxassetid://130233565570548"
local HOLD_ANIM_ID = "rbxassetid://128745131098374"
local CARRY_BLOCK_OFFSET = CFrame.new(1.08, -0.27, -0.02)

--< Helper Functions

local function MakeTransparency(Object:Instance, TransparencyValue:number)
	for _, v in pairs(Object:GetDescendants()) do
		if (v:IsA("BasePart") or v:IsA("MeshPart")) and v.Name ~= "Root" then
			v.Transparency = TransparencyValue
		end
	end
end

local function CreateAnimationFromID(id) :Animation
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	return animation
end

--< Animation Variables
local HitAnimation = CreateAnimationFromID(HIT_ANIM_ID)
local CarryAnimation = CreateAnimationFromID(CARRY_ANIM_ID)
local HoldAnimation = CreateAnimationFromID(HOLD_ANIM_ID)


--< Main Functions

local function CreateHeldLuckyBlock(leftHand :BasePart) :(BasePart, Motor6D)
	local heldBlock = Instance.new("Part")
	heldBlock.Name = "LuckyBlock"
	heldBlock.Size = Vector3.new(1, 1, 1)
	heldBlock.Transparency = 1

	local template = LuckyBlockTemplate:Clone()
	template.Name = "HeldLuckyBlock"
	for _, child in ipairs(template:GetChildren()) do
		child.Parent = heldBlock
	end
	template:Destroy()

	local rootPart = heldBlock:FindFirstChild("Root")
	if not rootPart then
		heldBlock:Destroy()
		return nil
	end

	local rootMotor = Instance.new("Motor6D")
	rootMotor.Name = "RootR6D"
	rootMotor.Part0 = heldBlock
	rootMotor.Part1 = rootPart
	rootMotor.Parent = heldBlock

	for _, descendant in ipairs(heldBlock:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	heldBlock.CanCollide = false
	heldBlock.CanTouch = false
	heldBlock.CanQuery = false
	heldBlock.Massless = true
	heldBlock.Anchored = false
	-- Spawn the prop directly at its carried offset so it never flashes inside the torso for a frame.
	heldBlock.CFrame = leftHand.CFrame * CARRY_BLOCK_OFFSET

	local rootPart = heldBlock:FindFirstChild("Root")
	if not rootPart then
		heldBlock:Destroy()
		return nil
	end

	local handMotor = Instance.new("Motor6D")
	handMotor.Name = "LuckyBlock"
	handMotor.Part0 = leftHand
	handMotor.Part1 = heldBlock
	handMotor.C0 = CARRY_BLOCK_OFFSET
	handMotor.Parent = leftHand

	MakeTransparency(heldBlock, 0)
	return heldBlock, handMotor
end

local function WeldBat(rightHand:BasePart)

	local bat = BaseballTemplate:Clone()
	local handle = bat:FindFirstChild("Handle")
	for _, m in ipairs(handle:GetChildren()) do
		if m:IsA("Motor6D") and m.Name == "RightHand" then
			m:Destroy()
		end
	end
	handle.CFrame = rightHand.CFrame * CFrame.new(0, -0.15, 0)
	handle.Anchored = false
	handle.CanCollide = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rightHand
	weld.Part1 = handle
	weld.Parent = handle
	MakeTransparency(bat, 1)
	

	local function ShowBatVisuals()
		for _, v in ipairs(bat:GetDescendants()) do
			if v:IsA("BasePart") then
				v.Transparency = if v.Name == "Handle" then 1 else 0
			end
		end
	end
	
	return bat, ShowBatVisuals
end

return function()
	
	local LocalPlayer = Players.LocalPlayer
	local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	
	local Humanoid :Humanoid = Character:WaitForChild("Humanoid", 60)
	local Animator :Animator = Humanoid:WaitForChild("Animator", 60)
	local LeftHand = Character:WaitForChild("LeftHand", 60)
	local RightHand = Character:WaitForChild("RightHand", 60)
	
	local CarryAnimationTrack = Animator:LoadAnimation(CarryAnimation)
	local HoldAnimationTrack = Animator:LoadAnimation(HoldAnimation)
	local HitAnimationTrack = Animator:LoadAnimation(HitAnimation)
	
	local HeldBlock, HandMotor = CreateHeldLuckyBlock(LeftHand)
	HeldBlock.Parent = Character
	HandMotor.Parent = LeftHand
	
	local Bat, ShowBat = WeldBat(RightHand)
	Bat.Parent = Character
	
	HitAnimationTrack:GetMarkerReachedSignal("Hit"):Connect(function(...)
		warn("HIT LUCKY BLOCK")	
		task.delay(3, function()
			Bat:Destroy()
			ShowBat = nil
		end)
		
		task.wait(.15)
		HeldBlock.CanCollide = true
		HandMotor:Destroy()
	end)
	
	task.wait(7)
	
	--< Init
	CarryAnimationTrack.Looped = true
	CarryAnimationTrack:Play()
	
	task.wait(7)
	CarryAnimationTrack:Stop()
	task.wait()

	Character.PrimaryPart.Anchored = true
	HoldAnimationTrack.Looped = true
	HoldAnimationTrack:Play()
	
	task.wait(7)
	HoldAnimationTrack:Stop()
	ShowBat()
	
	task.wait()
	
	HitAnimationTrack:Play()
end