local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BaseComponent =
	require(ReplicatedStorage:WaitForChild("Shared").Components:FindFirstChild("BaseComponent", true) :: ModuleScript)
local Signal = require(ReplicatedStorage:WaitForChild("Shared").Packages:WaitForChild("Signal") :: ModuleScript)

local Menu = BaseComponent:Extend("Menu")

local DEFAULT_OPEN_TIME = 0.28
local DEFAULT_CLOSE_TIME = 0.18
local DEFAULT_BLUR_SIZE = 14
local DEFAULT_SCALE_CLOSED = 0.94

local function ensureBlur(): BlurEffect
	local blur = Lighting:FindFirstChild("UIBlur")
	if blur and blur:IsA("BlurEffect") then
		return blur
	end

	blur = Instance.new("BlurEffect")
	blur.Name = "UIBlur"
	blur.Size = 0
	blur.Parent = Lighting
	return blur
end

local function ensureUIScale(frame: GuiObject): UIScale
	local scale = frame:FindFirstChildOfClass("UIScale")
	if scale then
		return scale
	end

	scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = frame
	return scale
end

local function findMenuFrame(screenGui: ScreenGui, frameName: string?): GuiObject?
	if frameName and frameName ~= "" then
		local namedFrame = screenGui:FindFirstChild(frameName, true)
		if namedFrame and namedFrame:IsA("GuiObject") then
			return namedFrame
		end
	end

	for _, child in ipairs(screenGui:GetChildren()) do
		if child:IsA("GuiObject") and (child.Name:find("Frame") or child.Name:find("Holder")) then
			return child
		end
	end

	return nil
end

function Menu:GetMenuFrameName(): string?
	return nil
end

function Menu:GetMenuStyle()
	local style = self.Framework.Config and self.Framework.Config.Menu
	return if type(style) == "table" then style else {}
end

function Menu:Create(screenGui: ScreenGui)
	self.Name = screenGui.Name
	self.ScreenGui = screenGui
	self.Frame = findMenuFrame(screenGui, self:GetMenuFrameName())
	self._blur = ensureBlur()
	self._tweens = {}
	self._isOpen = false
	self._busy = false

	self.OnOpened = Signal.new()
	self.OnClosed = Signal.new()

	if self.Frame then
		self._openPosition = self.Frame.Position
		self._closedPosition = UDim2.new(self._openPosition.X.Scale, self._openPosition.X.Offset, 1.25, self._openPosition.Y.Offset)
		self._scale = ensureUIScale(self.Frame)
		self.Frame.Position = self._closedPosition
		self.Frame.Visible = true

		local closeButton = self.Frame:FindFirstChild("CloseButton", true)
		if closeButton and closeButton:IsA("GuiButton") then
			self.CloseButton = self.Framework.Components.Button:new(closeButton)
			self.CloseButton:SetOnClick(function()
				self:Close()
			end)
			self:AddChild(self.CloseButton)
		end
	else
		warn(("[Menu] Could not find menu frame for %s"):format(screenGui:GetFullName()))
	end

	self.ScreenGui.Enabled = false
	self:RegisterWithMenuController()
end

function Menu:RegisterWithMenuController()
	local ok, menuController = pcall(function()
		return self.Framework:GetController("MenuController")
	end)

	if ok and menuController and menuController.RegisterMenu then
		menuController:RegisterMenu(self)
	end
end

function Menu:_killTweens()
	for _, tween in ipairs(self._tweens) do
		pcall(function()
			tween:Cancel()
		end)
	end
	table.clear(self._tweens)
end

function Menu:_tween(instance: Instance, tweenInfo: TweenInfo, props)
	local tween = TweenService:Create(instance, tweenInfo, props)
	table.insert(self._tweens, tween)
	tween:Play()
	return tween
end

function Menu:IsOpen(): boolean
	return self._isOpen
end

function Menu:Open()
	if self._busy or self._isOpen or not self.Frame then
		return
	end

	local ok, menuController = pcall(function()
		return self.Framework:GetController("MenuController")
	end)
	if ok and menuController and menuController.CloseAllExcept then
		menuController:CloseAllExcept(self)
	end

	if self.RefreshBeforeOpen then
		self:RefreshBeforeOpen()
	end

	local style = self:GetMenuStyle()
	local openTime = tonumber(style.OpenTime) or DEFAULT_OPEN_TIME
	local blurSize = tonumber(style.BlurSize) or DEFAULT_BLUR_SIZE
	local scaleClosed = tonumber(style.ScaleClosed) or DEFAULT_SCALE_CLOSED

	self._busy = true
	self._isOpen = true
	self:_killTweens()

	self.ScreenGui.Enabled = true
	self.Frame.Position = self._closedPosition
	self._scale.Scale = scaleClosed

	local openInfo = TweenInfo.new(openTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local popInfo = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = self:_tween(self.Frame, openInfo, { Position = self._openPosition })
	self:_tween(self._scale, popInfo, { Scale = 1 })
	self:_tween(self._blur, openInfo, { Size = blurSize })

	tween.Completed:Once(function()
		self._busy = false
		self.OnOpened:Fire()
	end)
end

function Menu:Close()
	if self._busy or not self._isOpen or not self.Frame then
		return
	end

	local style = self:GetMenuStyle()
	local closeTime = tonumber(style.CloseTime) or DEFAULT_CLOSE_TIME
	local scaleClosed = tonumber(style.ScaleClosed) or DEFAULT_SCALE_CLOSED

	self._busy = true
	self._isOpen = false
	self:_killTweens()

	local closeInfo = TweenInfo.new(closeTime, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	local tween = self:_tween(self.Frame, closeInfo, { Position = self._closedPosition })
	self:_tween(self._scale, closeInfo, { Scale = scaleClosed })
	self:_tween(self._blur, closeInfo, { Size = 0 })

	tween.Completed:Once(function()
		self.ScreenGui.Enabled = false
		self._busy = false
		self.OnClosed:Fire()
	end)
end

function Menu:Toggle()
	if self:IsOpen() then
		self:Close()
	else
		self:Open()
	end
end

function Menu:CleanUp()
	self:_killTweens()
	if self._blur then
		self._blur.Size = 0
	end
	if self.ScreenGui then
		self.ScreenGui.Enabled = false
	end
	if self.OnOpened then
		self.OnOpened:DisconnectAll()
	end
	if self.OnClosed then
		self.OnClosed:DisconnectAll()
	end
	self.OnOpened = nil
	self.OnClosed = nil
end

return Menu
