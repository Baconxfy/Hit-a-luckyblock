local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryItemClient = require(
	ReplicatedStorage:WaitForChild("Shared").Components:FindFirstChild("InventoryItemClient", true) :: ModuleScript
)

local BrainrotClient = InventoryItemClient:Extend("BrainrotClient")

local DEFAULT_HOLD_ANIMATION_NAMES = {
	"HoldBrainrot",
	"BrainrotHold",
	"HoldingBrainrot",
}
local DEFAULT_HOLD_ANIMATION_ATTRIBUTE = "HoldAnimationId"
local HOLD_ANIMATION_PRIORITY = Enum.AnimationPriority.Action

local animationById = {}
local tracksByAnimator = setmetatable({}, { __mode = "k" })
local missingAnimationWarned = false

local function getBrainrotHoldConfig(framework)
	local inventoryConfig = framework and framework.Config and framework.Config.Inventory
	local holdConfig = inventoryConfig and inventoryConfig.BrainrotHold
	return if type(holdConfig) == "table" then holdConfig else {}
end

local function normalizeAnimationId(value: string): string
	if value:match("^rbxassetid://") then
		return value
	end

	if value:match("^%d+$") then
		return "rbxassetid://" .. value
	end

	return value
end

local function getCharacter(model: Model?): Model?
	local parent = model and model.Parent
	return if parent and parent:IsA("Model") then parent else nil
end

local function getAnimator(character: Model?): Animator?
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	return animator
end

local function findAnimationInRoot(root: Instance?, animationNames): Animation?
	if not root then
		return nil
	end

	for _, animationName in ipairs(animationNames) do
		local animation = root:FindFirstChild(animationName)
		if animation and animation:IsA("Animation") then
			return animation
		end
	end

	return nil
end

local function findHoldAnimation(holdConfig): Animation?
	local animationNames = holdConfig.AnimationNames or DEFAULT_HOLD_ANIMATION_NAMES
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animations = assets and assets:FindFirstChild("Animations")

	return findAnimationInRoot(animations, animationNames)
		or findAnimationInRoot(assets, animationNames)
		or findAnimationInRoot(ReplicatedStorage, animationNames)
end

local function createHoldAnimation(model: Model?, holdConfig): Animation?
	return findHoldAnimation(holdConfig)
end

local function getHoldTrack(animator: Animator, animation: Animation): AnimationTrack
	local tracksByAnimation = tracksByAnimator[animator]
	if not tracksByAnimation then
		tracksByAnimation = setmetatable({}, { __mode = "k" })
		tracksByAnimator[animator] = tracksByAnimation
	end

	local track = tracksByAnimation[animation]
	if not track then
		track = animator:LoadAnimation(animation)
		track.Priority = HOLD_ANIMATION_PRIORITY
		track.Looped = true
		tracksByAnimation[animation] = track
	end

	return track
end

function BrainrotClient:Create(model: Model, slot: number, itemType: string)
	InventoryItemClient.Create(self, model, slot, itemType)
	self.BrainrotName = model and model.Name or nil
	self.HoldAnimation = createHoldAnimation(model, getBrainrotHoldConfig(self.Framework))
end

function BrainrotClient:SetModel(model: Model)
	InventoryItemClient.SetModel(self, model)
	self.BrainrotName = model and model.Name or nil
	self.HoldAnimation = createHoldAnimation(model, getBrainrotHoldConfig(self.Framework))
	self:RefreshHoldAnimation()
end

function BrainrotClient:SetEquipped(equipped: boolean)
	local wasEquipped = self.Equipped == true
	InventoryItemClient.SetEquipped(self, equipped)

	if wasEquipped ~= self.Equipped then
		self:RefreshHoldAnimation()
	end
end

function BrainrotClient:StopHoldAnimation()
	if self.HoldAnimationTrack then
		self.HoldAnimationTrack:Stop(0.15)
		self.HoldAnimationTrack = nil
	end
end

function BrainrotClient:PlayHoldAnimation()
	if self.HoldAnimationTrack and self.HoldAnimationTrack.IsPlaying then
		return
	end

	local animator = getAnimator(getCharacter(self.Model) or (Players.LocalPlayer and Players.LocalPlayer.Character))
	if not animator then
		return
	end

	local animation = self.HoldAnimation or createHoldAnimation(self.Model, getBrainrotHoldConfig(self.Framework))
	self.HoldAnimation = animation
	if not animation then
		if not missingAnimationWarned then
			missingAnimationWarned = true
			warn("[BrainrotClient] Missing holding animation. Add HoldBrainrot under ReplicatedStorage.Assets.Animations, or set HoldAnimationId on the brainrot model.")
		end
		return
	end

	self:StopHoldAnimation()
	local track = getHoldTrack(animator, animation)
	track:Play(0.15)
	self.HoldAnimationTrack = track
end

function BrainrotClient:RefreshHoldAnimation()
	if self.Equipped then
		self:PlayHoldAnimation()
	else
		self:StopHoldAnimation()
	end
end

function BrainrotClient:CleanUp()
	self:StopHoldAnimation()
end

return BrainrotClient
