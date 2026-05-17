--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local LuckyBlockTemplate = Assets:WaitForChild("LuckyBlock")
local BaseballTemplate = Assets:WaitForChild("Baseball")

local HIT_ANIM_ID = "rbxassetid://109049329968119"
local CARRY_ANIM_ID = "rbxassetid://130233565570548"
local HOLD_ANIM_ID = "rbxassetid://128745131098374"

local LUCKY_BLOCK_HAND_OFFSET = CFrame.new(1.08, -0.27, -0.02)
local BAT_HAND_OFFSET = CFrame.new(0, -0.15, 0)

-- ============================================================================
-- ATTACH: LUCKYBLOCK (Motor6D on LeftHand)
-- ============================================================================
-- Clones the LuckyBlock template and attaches it to LeftHand via a Motor6D
-- named "LuckyBlock" — the name the animation expects in order to drive the prop.

local function AttachLuckyBlock(character: Model): (Model?, Motor6D?)
	local leftHand = character:FindFirstChild("LeftHand")
	if not leftHand or not leftHand:IsA("BasePart") then
		warn("[AttachLuckyBlock] LeftHand not found")
		return nil, nil
	end

	local block = LuckyBlockTemplate:Clone()
	block.Name = "LuckyBlock"

	local root = block:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		block:Destroy()
		warn("[AttachLuckyBlock] Template has no Root")
		return nil, nil
	end

	-- Make every part non-physical so it follows the hand cleanly.
	for _, part in ipairs(block:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
		end
	end

	-- Position before parenting so it doesn't flash inside the torso.
	block:PivotTo(leftHand.CFrame * LUCKY_BLOCK_HAND_OFFSET)

	local motor = Instance.new("Motor6D")
	motor.Name = "LuckyBlock"
	motor.Part0 = leftHand
	motor.Part1 = root
	motor.C0 = LUCKY_BLOCK_HAND_OFFSET
	motor.Parent = leftHand

	block.Parent = character

	return block, motor
end

-- ============================================================================
-- ATTACH: BAT (Motor6D on RightHand)
-- ============================================================================
-- Clones the bat and attaches it to RightHand via a Motor6D named "Bat" —
-- the name the Hit animation expects in order to drive the prop.

local function AttachBat(character: Model): (Model?, Motor6D?)
	local rightHand = character:FindFirstChild("RightHand")
	if not rightHand or not rightHand:IsA("BasePart") then
		warn("[AttachBat] RightHand not found")
		return nil, nil
	end

	local bat = BaseballTemplate:Clone()
	bat.Name = "Bat"

	local handle = bat:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		bat:Destroy()
		warn("[AttachBat] Bat template has no Handle")
		return nil, nil
	end

	-- Strip any leftover Motor6D from the template.
	for _, m in ipairs(handle:GetChildren()) do
		if m:IsA("Motor6D") then
			m:Destroy()
		end
	end

	-- Make every part non-physical.
	for _, part in ipairs(bat:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
		end
	end

	bat:PivotTo(rightHand.CFrame * BAT_HAND_OFFSET)

	local motor = Instance.new("Motor6D")
	motor.Name = "Bat"
	motor.Part0 = rightHand
	motor.Part1 = handle
	motor.C0 = BAT_HAND_OFFSET
	motor.Parent = rightHand

	bat.Parent = character

	return bat, motor
end

-- ============================================================================
-- ANIMATION TRACK GETTERS
-- ============================================================================
-- Each takes the character and returns a loaded AnimationTrack ready to play.
-- They do NOT call :Play() — the caller decides fade, timing, etc.

local function LoadTrack(character: Model, animationId: string, label: string): AnimationTrack?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn(string.format("[GetTrack/%s] Animator not found", label))
		return nil
	end

	local animObj = Instance.new("Animation")
	animObj.AnimationId = animationId

	pcall(function()
		ContentProvider:PreloadAsync({ animObj })
	end)

	local ok, trackOrErr = pcall(function()
		return animator:LoadAnimation(animObj)
	end)

	animObj:Destroy()

	if not ok then
		warn(string.format("[GetTrack/%s] LoadAnimation failed: %s", label, tostring(trackOrErr)))
		return nil
	end

	local track = trackOrErr :: AnimationTrack
	track.Priority = Enum.AnimationPriority.Action
	return track
end

-- Hold: static waiting pose. Looped.
local function GetHoldTrack(character: Model): AnimationTrack?
	local track = LoadTrack(character, HOLD_ANIM_ID, "Hold")
	if track then
		track.Looped = true
	end
	return track
end

-- Carry: walking-with-block animation. Looped.
local function GetCarryTrack(character: Model): AnimationTrack?
	local track = LoadTrack(character, CARRY_ANIM_ID, "Carry")
	if track then
		track.Looped = true
	end
	return track
end

-- Hit: bat swing. Plays once. Contains the "hit"/"Hit" markers.
local function GetHitTrack(character: Model): AnimationTrack?
	local track = LoadTrack(character, HIT_ANIM_ID, "Hit")
	if track then
		track.Looped = false
	end
	return track
end

return {
	AttachLuckyBlock = AttachLuckyBlock,
	AttachBat = AttachBat,
	GetHoldTrack = GetHoldTrack,
	GetCarryTrack = GetCarryTrack,
	GetHitTrack = GetHitTrack,
}