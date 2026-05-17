--[[


░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

-- Services
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

-- Modules
local PromiseFindFirstChild = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("PromiseFindFirstChild"))

-- Constants
local MAINFRAME_STATUS_ATTRIBUTE_NAME = "_isVisible"
local OPEN_POSITION = UDim2.new(0.5, 0, 0.5, 0)
local CLOSE_POSITION = UDim2.new(0.5, 0, 1, 0)

local DEFAULT_FOV = 70
local GUI_FOV = 55

local BLUR_SIZE = 12 -- FIX: was 0, blur was never visibly applied
local BLUR_NAME = "Blur [GuiController]"

local NONEFFECT_ATTRIBUTE_NAME = "_noEffect"
local CONSTANT_ATTRIBUTE_NAME = "_constant"

local TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quint)

-- Variables
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CurrentCamera = workspace.CurrentCamera

-- Module
local module = {}

-- Private
module._initialized = nil
module._oldCameraMinDistance = nil

-- Public
module.BlurEffect = nil

module.MainFrames = {}
module.CurrentMainFrame = nil
module._CurrentMainFramePositions = {} -- { ["Open"]:UDim2?, ["Close"]:UDim2? }

module.DefaultGui = nil
module.CurrentGui = nil

module.Guis = {}
module.HidenGuis = {}
module.Variables = {}

-- LOCK: when _LockedGui is not nil, the controller enters "exclusive mode":
-- only that ScreenGui (and the MainFrames belonging to it) can be opened,
-- closed, or toggled. Any other attempt is a no-op until UnlockGui is called.
-- HideAll and HideGuis do NOT hide the LockedGui.
module._LockedGui = nil

-- Private Helpers

--[[
	Internal helper: ensures a UIScale exists on the frame without using the
	deprecated Instance.new("UIScale", parent) syntax.
]]
local function ensureUIScale(frame: Instance): UIScale
	local scale = frame:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = frame
	end
	return scale
end

--[[
	Internal helper: determines whether a frame/gui should apply camera/blur effects.

	The only attribute that disables effects is _noEffect. _constant is about
	the GuiController not touching the ScreenGui's Enabled flag — it has no
	bearing on effects. In particular, the typical pattern of a _constant
	ScreenGui containing an animated MainFrame must still trigger effects
	when the MainFrame opens.

	When called with a descendant (e.g. a MainFrame), the ancestor ScreenGui's
	_noEffect is also checked: marking the ScreenGui as _noEffect propagates
	to all of its MainFrames. A _noEffect MainFrame disables effects only for
	that specific frame.
]]
local function shouldApplyEffects(instance: Instance): boolean
	if instance:GetAttribute(NONEFFECT_ATTRIBUTE_NAME) then
		return false
	end

	-- If the instance is a MainFrame inside a ScreenGui, _noEffect on the
	-- ScreenGui propagates down. _constant is intentionally ignored here.
	if not instance:IsA("ScreenGui") then
		local screenGui = instance:FindFirstAncestorOfClass("ScreenGui")
		if screenGui and screenGui:GetAttribute(NONEFFECT_ATTRIBUTE_NAME) then
			return false
		end
	end

	return true
end

--[[
	Internal helper: applies the camera/blur/zoom state for an "effects on" or
	"effects off" target. Centralizes the logic so opening one GUI with effects
	and then opening another without effects correctly tears down the previous
	state, instead of leaving stale FOV/blur from the previous GUI.
]]
local function applyEffectsState(self, enabled: boolean)
	if enabled then
		if not self._oldCameraMinDistance then
			self._oldCameraMinDistance = LocalPlayer.CameraMinZoomDistance
			LocalPlayer.CameraMinZoomDistance = 2.5
		end
		TweenService:Create(CurrentCamera, TWEEN_INFO, { FieldOfView = GUI_FOV }):Play()
		if self.BlurEffect then
			TweenService:Create(self.BlurEffect, TWEEN_INFO, { Size = BLUR_SIZE }):Play()
		end
	else
		if self._oldCameraMinDistance then
			LocalPlayer.CameraMinZoomDistance = self._oldCameraMinDistance
			self._oldCameraMinDistance = nil
		end
		TweenService:Create(CurrentCamera, TWEEN_INFO, { FieldOfView = DEFAULT_FOV }):Play()
		if self.BlurEffect then
			TweenService:Create(self.BlurEffect, TWEEN_INFO, { Size = 0 }):Play()
		end
	end
end

--[[
	Internal helper: is there an active lock on the controller?
]]
local function isLockActive(self): boolean
	return self._LockedGui ~= nil and self._LockedGui.Parent ~= nil
end

--[[
	Internal helper: is the operation on `target` allowed under the current lock?

	- No active lock: always allowed.
	- Active lock: allowed if `target` is:
	    * the locked ScreenGui or one of its descendants, OR
	    * the DefaultGui (since closing the lockedGui falls back to default), OR
	    * nil — i.e. OpenGui() to return to the default, allowing the user to
	      "close" a non-constant lockedGui without unlocking.
	  Anything else: not allowed.
]]
local function isAllowedByLock(self, target: Instance?): boolean
	if not isLockActive(self) then return true end

	local locked = self._LockedGui
	if target == nil then return true end
	if target == locked then return true end
	if target == self.DefaultGui then return true end
	if target:IsDescendantOf(locked) then return true end
	return false
end

-- Private Methods

--[[
	Creates and displays a purchase prompt GUI with animated icon.
	Private method used internally by purchase prompt functions.

	@returns A cleanup function that closes and destroys the prompt GUI
]]
function module:_PromptPurchaseGui()
	local PromptPurchaseGui = script.PromptPurchase:Clone()
	PromptPurchaseGui.Enabled = false

	local OpenSound = PromptPurchaseGui:FindFirstChild("Open")

	local Frame = PromptPurchaseGui:FindFirstChild("Frame")
	local Image = Frame:FindFirstChild("Icon")
	local ImageUIScale = Image:FindFirstChild("UIScale") or (function()
		local s = Instance.new("UIScale")
		s.Parent = Image
		return s
	end)()

	-- FIX: Frame doesn't have a "Transparency" property; use BackgroundTransparency.
	-- Image (ImageLabel) has BackgroundTransparency and ImageTransparency.
	Frame.BackgroundTransparency = 1
	Image.BackgroundTransparency = 1
	Image.ImageTransparency = 1

	local IconSize = TweenService:Create(
		ImageUIScale,
		TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, true, 0),
		{ Scale = 1.5 }
	)
	local IconSpin = TweenService:Create(
		Image,
		TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out, -1, true, 0),
		{ Rotation = 360 }
	)

	if OpenSound then
		OpenSound:Play()
	end

	local LastCurrentGui = self.CurrentGui
	PromptPurchaseGui.Parent = PlayerGui
	self:OpenGui(PromptPurchaseGui)

	IconSpin:Play()
	IconSize:Play()

	-- FIX: correct tween of BackgroundTransparency / ImageTransparency
	TweenService:Create(Frame, TweenInfo.new(1, Enum.EasingStyle.Quint), { BackgroundTransparency = 0.3 }):Play()
	TweenService:Create(Image, TweenInfo.new(1, Enum.EasingStyle.Quint), { ImageTransparency = 0 }):Play()

	local function finish()
		IconSpin:Cancel()
		IconSize:Cancel()
		IconSpin:Destroy()
		IconSize:Destroy()
		self:OpenGui(LastCurrentGui)
		PromptPurchaseGui:Destroy()
	end

	return finish
end

-- Public Methods

function module:GetVariable(name:string) :any?
	assert(name, `Variable name is NIL`)
	return self.Variables[name]
end

function module:SetVariable(name:string, value:any?)
	assert(name, `Variable name is NIL`)
	self.Variables[name] = value
end

--[[
	Sets the constant attribute on a GUI instance.
	A constant GUI remains visible and does not hide when other GUIs are opened.

	@param instance: Instance - The Instance to set the constant attribute on
	@param value: boolean? - Whether the GUI should be constant (default: true)
]]
function module:SetConstantGui(instance: Instance, value: boolean?)
	if value == nil then value = true end
	instance:SetAttribute(CONSTANT_ATTRIBUTE_NAME, value)
end

--[[
	Sets the no-effect attribute on a GUI instance.
	A no-effect GUI will not apply camera blur or FOV changes when opened.

	@param instance: Instance - The Instance to set the no-effect attribute on
	@param value: boolean? - Whether the GUI should have no effects (default: true)
]]
function module:SetNonEffectGui(instance: Instance, value: boolean?)
	if value == nil then value = true end
	instance:SetAttribute(NONEFFECT_ATTRIBUTE_NAME, value)
end

--[[
	Sets up a popup animation effect for a GUI.
	When the GUI is enabled/disabled, the main frame animates with scale and position tweening.
	Returns a connection that can be disconnected to stop the effect.
]]
function module:SetPopUpGuiEffect(
	Gui: ScreenGui,
	MainFrame: Frame | ImageLabel?,
	OpenPosition: UDim2?,
	ClosePosition: UDim2?,
	OnGuiEnabled: () -> ()?,
	OnGuiDisabled: () -> ()?
): RBXScriptConnection
	assert(Gui, `ScreenGui is nil`)

	MainFrame = MainFrame or Gui:FindFirstChildOfClass("Frame") or Gui:FindFirstChildOfClass("ImageLabel")
	assert(MainFrame, `MainFrame is nil`)

	local UIScale = ensureUIScale(MainFrame)
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)

	OpenPosition = OpenPosition or OPEN_POSITION
	ClosePosition = ClosePosition or CLOSE_POSITION

	local function Setup()
		if Gui.Enabled then
			UIScale.Scale = 0
			MainFrame.Position = ClosePosition

			MainFrame:TweenPosition(OpenPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.3, true)
			TweenService:Create(UIScale, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { Scale = 1 }):Play()

			if OnGuiEnabled then
				OnGuiEnabled()
			end
		else
			if OnGuiDisabled then
				OnGuiDisabled()
			end
		end
	end

	task.spawn(Setup)
	return Gui:GetPropertyChangedSignal("Enabled"):Connect(Setup)
end

--[[
	Registers a main frame for a GUI and optionally sets its initial state.
]]
function module:SetMainFrame(
	Gui: ScreenGui,
	MainFrame: Frame | ImageLabel?,
	IsVisible: boolean?,
	OpenPosition: UDim2?,
	ClosePosition: UDim2?
): Frame | ImageLabel?
	assert(Gui, `Gui is nil`)
	MainFrame = MainFrame or Gui:FindFirstChildOfClass("Frame") or Gui:FindFirstChildOfClass("ImageLabel")
	self.MainFrames[Gui] = MainFrame

	if IsVisible then
		-- FIX: register the frame as CurrentMainFrame and store its positions
		-- so that a subsequent ToggleMainFrame can close it correctly.
		if MainFrame and not MainFrame:GetAttribute(CONSTANT_ATTRIBUTE_NAME) then
			if self.CurrentMainFrame and self.CurrentMainFrame ~= MainFrame then
				self:CloseMainFrame(self.CurrentMainFrame, self._CurrentMainFramePositions.Close)
			end
			self.CurrentMainFrame = MainFrame
			self._CurrentMainFramePositions = {
				Open = OpenPosition,
				Close = ClosePosition,
			}
		end
		self:OpenMainFrame(MainFrame, OpenPosition)
	else
		self:CloseMainFrame(MainFrame, ClosePosition)
	end

	return MainFrame
end

function module:GetMainFrame(Gui: ScreenGui): GuiObject?
	assert(Gui, `Gui is nil`)
	return self.MainFrames[Gui]
end

function module:MainFrameIsVisible(MainFrame: Frame | ImageLabel?) :boolean?
	assert(MainFrame, `MainFrame is nil`)
	return MainFrame:GetAttribute(MAINFRAME_STATUS_ATTRIBUTE_NAME)
end

--[[
	Closes a main frame with animation.
	Resets FOV/blur to defaults if this frame was applying effects.
]]
function module:CloseMainFrame(MainFrame: Frame | ImageLabel?, ClosePosition: UDim2?)
	assert(self._initialized, `{script.Name} is not initialized`)
	if not MainFrame then return end

	-- Exclusive LOCK: only the MainFrame belonging to the locked ScreenGui
	-- can be closed while the lock is active.
	if not isAllowedByLock(self, MainFrame) then return end

	local UIScale = ensureUIScale(MainFrame)

	-- Only tear down camera/blur if this frame was actually applying them.
	-- A frame doesn't apply effects when it (or its ancestor ScreenGui) has
	-- _noEffect; in that case we must not reset to defaults, as that would
	-- disturb other GUIs that DO have effects active.
	if shouldApplyEffects(MainFrame) then
		applyEffectsState(self, false)
	end

	MainFrame:TweenPosition(ClosePosition or CLOSE_POSITION, Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.3, true)
	TweenService:Create(UIScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 0 }):Play()
	MainFrame:SetAttribute(MAINFRAME_STATUS_ATTRIBUTE_NAME, false)
end

--[[
	Opens a main frame with animation.
	Applies camera/blur effects unless the frame (or its ancestor ScreenGui)
	is marked _noEffect.
]]
function module:OpenMainFrame(MainFrame: Frame | ImageLabel?, OpenPosition: UDim2?)
	assert(self._initialized, `{script.Name} is not initialized`)
	if not MainFrame then return end

	-- Exclusive LOCK: only the MainFrame belonging to the locked ScreenGui
	-- can be opened while the lock is active.
	if not isAllowedByLock(self, MainFrame) then return end

	local UIScale = ensureUIScale(MainFrame)

	-- FIX: explicit two-branch state. Opening a _noEffect frame must also
	-- tear down any leftover effects from a previously open frame; otherwise
	-- the new frame appears "with effect" because FOV/blur weren't reset.
	if shouldApplyEffects(MainFrame) then
		applyEffectsState(self, true)
	else
		applyEffectsState(self, false)
	end

	MainFrame:TweenPosition(OpenPosition or OPEN_POSITION, Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.3, true)
	TweenService:Create(UIScale, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { Scale = 1 }):Play()
	MainFrame:SetAttribute(MAINFRAME_STATUS_ATTRIBUTE_NAME, true)
end

--[[
	Toggles the visibility of a main frame.
]]
function module:ToggleMainFrame(MainFrame: Frame | ImageLabel?, OpenPosition: UDim2?, ClosePosition: UDim2?)
	assert(self._initialized, `{script.Name} is not initialized`)

	MainFrame = MainFrame or self.CurrentMainFrame
	if not MainFrame then
		return
	end

	-- Exclusive LOCK: only the MainFrame of the locked ScreenGui can be toggled.
	if not isAllowedByLock(self, MainFrame) then return end

	if MainFrame:GetAttribute(CONSTANT_ATTRIBUTE_NAME) then
		if MainFrame:GetAttribute(MAINFRAME_STATUS_ATTRIBUTE_NAME) then
			self:CloseMainFrame(MainFrame, ClosePosition)
		else
			self:OpenMainFrame(MainFrame, OpenPosition)
		end
	else
		local CurrentMainFrame = self.CurrentMainFrame
		local CurrentMainFramePositions = self._CurrentMainFramePositions

		if CurrentMainFrame == MainFrame then
			self:CloseMainFrame(MainFrame, ClosePosition or CurrentMainFramePositions.Close)
			self.CurrentMainFrame = nil
			self._CurrentMainFramePositions = {}
		else
			if CurrentMainFrame then
				self:CloseMainFrame(CurrentMainFrame, CurrentMainFramePositions.Close)
			end

			-- FIX: always store the new frame's positions, not only when non-nil.
			-- Previously, calling Toggle(A, posOpen, posClose) followed by Toggle(B)
			-- would not clear A's positions, and B would close using A's close position.
			self._CurrentMainFramePositions = {
				Open = OpenPosition,
				Close = ClosePosition,
			}

			self:OpenMainFrame(MainFrame, OpenPosition)
			self.CurrentMainFrame = MainFrame
		end
	end
end

--[[
	Replicates all ScreenGui instances from a container into PlayerGui.
]]
function module:ReplicateGUIS(
	GuiContainer: Instance | Folder,
	Calllback: (index: number, item: Instance) -> ()?
): { ScreenGui }
	local guis = {}
	for i, v in pairs(GuiContainer:GetChildren()) do
		local clone = v:Clone()
		clone.Parent = PlayerGui
		-- FIX: insert into the table; previously this always returned {}
		table.insert(guis, clone)
		if Calllback then
			task.spawn(Calllback, i, clone)
		end
	end
	return guis
end

--[[
	Registers a new ScreenGui to the GuiController.
]]
function module:RegisterGui(v: ScreenGui, disableResetOnSpawn: boolean?)
	-- FIX: unified logic with no duplicated code. Determines the key (with a
	-- numeric suffix if there's a name collision), then sets Enabled once.
	local key = v.Name
	if self.Guis[key] and self.Guis[key] ~= v then
		local num = 0
		repeat
			num += 1
		until not self.Guis[`{v.Name}_{num}`]
		key = `{v.Name}_{num}`
	end

	self.Guis[key] = v

	if v:GetAttribute(CONSTANT_ATTRIBUTE_NAME) then
		v.Enabled = true
	else
		v.Enabled = false
	end

	if disableResetOnSpawn then
		v.ResetOnSpawn = false
	end
end

function module:SetDefaultGui(DefaultGui: ScreenGui)
	if self.CurrentGui == self.DefaultGui then
		self.DefaultGui = DefaultGui
		self:OpenGui()
	else
		self.DefaultGui = DefaultGui
	end
end

--[[
	Initializes the GuiController module.
]]
function module:Init(DefaultGui: ScreenGui, Guis: { ScreenGui })
	assert(not self._initialized, `{script.Name} already initialized`)
	self._initialized = true

	local BlurEffect: BlurEffect = Lighting:FindFirstChild(BLUR_NAME)
	if not BlurEffect then
		BlurEffect = Instance.new("BlurEffect")
		BlurEffect.Name = BLUR_NAME
		BlurEffect.Parent = Lighting
	end
	BlurEffect.Enabled = true
	BlurEffect.Size = 0

	self.BlurEffect = BlurEffect

	if DefaultGui then
		self:RegisterGui(DefaultGui)
		self.DefaultGui = DefaultGui
	end

	if Guis then
		for _, v: Instance in pairs(Guis) do
			if v == self.DefaultGui then
				continue
			end
			self:RegisterGui(v)
		end
	end

	self:OpenGui()
end

function module:PromptGamepass(
	GamePassId: number,
	EndCallback: ((player: Player, gamePassId: number, wasPurchased: boolean) -> ())?
)
	local DestroyGui = self:_PromptPurchaseGui()
	MarketplaceService.PromptGamePassPurchaseFinished:Once(function(player, gamePassId, wasPurchased: boolean)
		DestroyGui()
		if EndCallback then
			EndCallback(player, gamePassId, wasPurchased)
		end
	end)
	MarketplaceService:PromptGamePassPurchase(LocalPlayer, GamePassId)
end

function module:PromptDevProduct(
	ProductId: number,
	EndCallback: ((userId: number, productId: number, isPurchased: boolean) -> ())?
)
	local DestroyGui = self:_PromptPurchaseGui()
	MarketplaceService.PromptProductPurchaseFinished:Once(
		function(userId: number, productId: number, isPurchased: boolean)
			DestroyGui()
			if EndCallback then
				EndCallback(userId, productId, isPurchased)
			end
		end
	)
	MarketplaceService:PromptProductPurchase(LocalPlayer, ProductId)
end

function module:PromptRobloxSubscription(EndCallback: ((isPremium: boolean) -> ())?)
	local DestroyGui = self:_PromptPurchaseGui()
	MarketplaceService.PromptPremiumPurchaseFinished:Once(function(...)
		DestroyGui()
		if EndCallback then
			EndCallback(LocalPlayer.MembershipType == Enum.MembershipType.Premium)
		end
	end)
	MarketplaceService:PromptRobloxSubscriptionPurchase(LocalPlayer)
end

-- FIX: the first definition of PromptSubscription was broken:
--   * it called MarketplaceService:pro(...) (typo, doesn't exist)
--   * it listened to PromptPremiumPurchaseFinished instead of PromptSubscriptionPurchaseFinished
-- Removed. Only the correct implementation remains.
function module:PromptSubscription(
	SubscriptionId: string,
	EndCallback: ((user: Player, subscriptionId: string, didTryPurchasing: boolean) -> ())?
)
	local DestroyGui = self:_PromptPurchaseGui()
	MarketplaceService.PromptSubscriptionPurchaseFinished:Once(
		function(user: Player, subscriptionId: string, didTryPurchasing: boolean)
			DestroyGui()
			if EndCallback then
				EndCallback(user, subscriptionId, didTryPurchasing)
			end
		end
	)
	MarketplaceService:PromptSubscriptionPurchase(LocalPlayer, SubscriptionId)
end

function module:GetGui(GuiName: string?, TimeOut: number?): ScreenGui?
	if not GuiName then
		return self.DefaultGui
	end
	TimeOut = TimeOut or 30
	return self.Guis[GuiName] or PromiseFindFirstChild(PlayerGui, GuiName, TimeOut)
end

--[[
	Opens a GUI and applies camera/blur effects.
]]
function module:OpenGui(Gui: ScreenGui?)
	assert(self._initialized, `{script.Name} is not initialized`)

	local DefaultScreenGui: ScreenGui = self.DefaultGui
	local CurrentScreenGui: ScreenGui = self.CurrentGui

	-- FIX: if OpenGui(currentGui) is called while it's already open, don't close
	-- it nor swap to the default. Just no-op.
	if Gui and Gui == CurrentScreenGui then
		return
	end

	-- Exclusive LOCK: when a lock is active, only the LockedGui can be operated on.
	-- - OpenGui(otherGui)  -> no-op
	-- - OpenGui()          -> no-op (we don't return to default while locked)
	-- - OpenGui(lockedGui) -> allowed (in practice, it's already CurrentGui and returns above)
	if not isAllowedByLock(self, Gui) then
		return
	end

	if (not Gui) or (DefaultScreenGui == Gui) then
		-- Returning to default: always tear down effects.
		applyEffectsState(self, false)

		if CurrentScreenGui and not CurrentScreenGui:GetAttribute(CONSTANT_ATTRIBUTE_NAME) then
			CurrentScreenGui.Enabled = false
		end

		self.CurrentGui = DefaultScreenGui
		if DefaultScreenGui then
			DefaultScreenGui.Enabled = true
		end
	else
		-- FIX: explicit two-branch state. Opening a _noEffect GUI when a previous
		-- GUI applied effects must tear down those effects; otherwise the new GUI
		-- appears "with effect" because FOV/blur weren't reset.
		if shouldApplyEffects(Gui) then
			applyEffectsState(self, true)
		else
			applyEffectsState(self, false)
		end

		if CurrentScreenGui and not CurrentScreenGui:GetAttribute(CONSTANT_ATTRIBUTE_NAME) then
			CurrentScreenGui.Enabled = false
		end

		self.CurrentGui = Gui
		Gui.Enabled = true
	end
end

--[[
	Locks a ScreenGui (or the ScreenGui of a MainFrame) in EXCLUSIVE mode.

	Two scenarios depending on whether the locked ScreenGui is _constant:

	(A) The locked ScreenGui is _constant (typical "ScreenGui-with-MainFrame"
	    pattern: the ScreenGui stays always-on; the MainFrame inside it has
	    the open/close animation):
	      * The CurrentGui is NOT changed. The dev controls _constant Guis'
	        Enabled flag directly; the controller doesn't open/close them.
	      * If the CurrentMainFrame belongs to the locked ScreenGui, it is
	        left alone (user keeps their state). Otherwise it's closed.

	(B) The locked ScreenGui is NOT _constant (the ScreenGui itself is what
	    opens/closes):
	      * The CurrentGui becomes the locked ScreenGui (via OpenGui).
	      * The previous CurrentGui (if any, and not _constant) is hidden by
	        OpenGui's normal flow.
	      * If a CurrentMainFrame was open and isn't a descendant of the
	        locked ScreenGui, it's closed.

	While a lock is active:
	  * Only the locked ScreenGui and its descendants (inner MainFrames) can
	    be opened, closed or toggled. The DefaultGui is also reachable via
	    OpenGui()/OpenGui(DefaultGui) — closing the lockedGui falls back to
	    the default.
	  * Any attempt to open another ScreenGui or MainFrame is a no-op.
	  * HideAll and HideGuis do not hide the locked GUI.
	  * Only ONE LockedGui at a time. Calling LockGui on a different one
	    while a lock is active automatically releases the previous one.

	`instance` can be a ScreenGui or a descendant Frame/ImageLabel: if it's a
	descendant, its ancestor ScreenGui is the one being locked.

	@param instance: ScreenGui | Frame | ImageLabel
]]
function module:LockGui(instance: Instance)
	assert(self._initialized, `{script.Name} is not initialized`)
	assert(instance, `instance is nil`)

	-- Resolve to the ancestor ScreenGui if we were given a descendant.
	local screenGui: ScreenGui? = nil
	if instance:IsA("ScreenGui") then
		screenGui = instance
	else
		screenGui = instance:FindFirstAncestorOfClass("ScreenGui")
	end
	assert(screenGui, `instance must be a ScreenGui or a descendant of one`)

	-- If there's already a different active lock, release it first so the
	-- OpenGui/CloseMainFrame calls below aren't rejected by isAllowedByLock.
	if self._LockedGui and self._LockedGui ~= screenGui then
		self._LockedGui = nil
	end

	-- 1) Handle the CurrentMainFrame:
	--    - if it belongs to the GUI being locked, leave it (user state).
	--    - otherwise, close it via CloseMainFrame.
	local CurrentMainFrame = self.CurrentMainFrame
	if CurrentMainFrame and not CurrentMainFrame:IsDescendantOf(screenGui) then
		self:CloseMainFrame(CurrentMainFrame, self._CurrentMainFramePositions.Close)
		self.CurrentMainFrame = nil
		self._CurrentMainFramePositions = {}
	end

	-- 2) Handle the CurrentGui:
	--    - if the lockedGui is NOT _constant, it should become the new
	--      CurrentGui. OpenGui takes care of swapping the previous one.
	--    - if the lockedGui IS _constant, the GuiController never owns its
	--      Enabled flag; it's "always visible" by the dev's choice. We don't
	--      touch CurrentGui in this case — whatever is showing keeps showing.
	if not screenGui:GetAttribute(CONSTANT_ATTRIBUTE_NAME) then
		if self.CurrentGui ~= screenGui then
			self:OpenGui(screenGui)
		end
	end

	self._LockedGui = screenGui
end

--[[
	Unlocks the currently locked ScreenGui and releases "exclusive mode".

	The `instance` argument is optional and only used as a guard: if you pass
	an instance that doesn't match the current LockedGui, nothing happens.
	Called without an argument, the lock is released unconditionally.

	@param instance: (ScreenGui | Frame | ImageLabel)? - optional, for validation.
]]
function module:UnlockGui(instance: Instance?)
	assert(self._initialized, `{script.Name} is not initialized`)

	if instance then
		local screenGui: ScreenGui? = instance:IsA("ScreenGui")
			and instance
			or instance:FindFirstAncestorOfClass("ScreenGui")
		if screenGui ~= self._LockedGui then
			return
		end
	end

	self._LockedGui = nil
end

--[[
	Returns the currently locked ScreenGui, or nil if no lock is active.
	If an instance is passed, returns true/false indicating whether that
	instance (or its ancestor ScreenGui) is the currently locked one.

	@param instance: Instance? - optional
	@returns ScreenGui | boolean | nil
]]
function module:IsLocked(instance: Instance?): any
	if not instance then
		return self._LockedGui
	end
	if not self._LockedGui then return false end

	local screenGui: ScreenGui? = instance:IsA("ScreenGui")
		and instance
		or instance:FindFirstAncestorOfClass("ScreenGui")
	return screenGui == self._LockedGui
end

--[[
	Hides ALL of the player's ScreenGuis regardless of attributes
	(including those marked _constant), with the ONLY exception being
	the LockedGui (if a lock is active, it isn't hidden).

	Iterates over both the registered GUIs and any ScreenGui present in
	PlayerGui (useful for hiding UI not registered in the controller).

	Hidden GUIs are stored in HidenGuis so they can be restored with
	ShowHidenGuis.
]]
function module:HideAll()
	local locked = self._LockedGui
	local seen = {}

	local function tryHide(Gui: Instance)
		if seen[Gui] then return end
		seen[Gui] = true

		if not Gui:IsA("ScreenGui") then return end
		if not Gui.Enabled then return end
		-- LOCK: the LockedGui is never hidden.
		if Gui == locked then return end

		Gui.Enabled = false
		table.insert(self.HidenGuis, Gui)
	end

	for _, Gui in pairs(self.Guis) do
		tryHide(Gui)
	end

	for _, Gui in ipairs(PlayerGui:GetChildren()) do
		tryHide(Gui)
	end
end

--[[
	Hides a list of GUIs and stores them for later restoration.
	Constant GUIs and the LockedGui are ignored.
]]
function module:HideGuis(GuiList: { ScreenGui }?)
	GuiList = GuiList or self.Guis
	local locked = self._LockedGui
	for _, Gui: ScreenGui in pairs(GuiList) do
		if not Gui:IsA("ScreenGui") or not Gui.Enabled then
			continue
		end
		-- FIX: do not hide GUIs marked as constant.
		if Gui:GetAttribute(CONSTANT_ATTRIBUTE_NAME) then
			continue
		end
		-- LOCK: the LockedGui is never hidden.
		if Gui == locked then
			continue
		end
		Gui.Enabled = false
		table.insert(self.HidenGuis, Gui)
	end
end

function module:ShowHidenGuis()
	local locked = self._LockedGui
	for _, Gui: ScreenGui in pairs(self.HidenGuis) do
		if Gui and Gui.Parent then
			-- LOCK: while a lock is active, we don't re-enable the other GUIs;
			-- they remain in the list for the next ShowHidenGuis after unlocking.
			-- Exception: the LockedGui itself is restored.
			if locked and Gui ~= locked then
				continue
			end
			Gui.Enabled = true
		end
	end

	if locked then
		-- Keep only the ones that were NOT restored, for a future ShowHidenGuis.
		local remaining = {}
		for _, Gui in pairs(self.HidenGuis) do
			if Gui ~= locked then
				table.insert(remaining, Gui)
			end
		end
		self.HidenGuis = remaining
	else
		self.HidenGuis = {}
	end
end

return module