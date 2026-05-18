local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local GuiController = {}

GuiController.PlayerGui = nil
GuiController.HUD = nil
GuiController.CurrentMainFrame = nil

GuiController._registeredGuis = {}
GuiController._constantGuis = {}
GuiController._nonEffectGuis = {}
GuiController._variables = {}

local DEFAULT_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function getPlayerGui()
	if GuiController.PlayerGui then
		return GuiController.PlayerGui
	end

	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	GuiController.PlayerGui = playerGui

	return playerGui
end

local function isGuiObject(instance)
	return instance and instance:IsA("GuiObject")
end

function GuiController:Init(hud, guis)
	self.PlayerGui = getPlayerGui()
	self.HUD = hud
	self.CurrentMainFrame = nil

	self._registeredGuis = self._registeredGuis or {}
	self._constantGuis = self._constantGuis or {}
	self._nonEffectGuis = self._nonEffectGuis or {}
	self._variables = self._variables or {}

	if hud then
		self:RegisterGui(hud)
	end

	for _, gui in ipairs(guis or {}) do
		self:RegisterGui(gui)
	end

	local playerModule = Players.LocalPlayer:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")

	if playerModule then
		self:SetVariable("PlayerModule", require(playerModule))
	end
end

function GuiController:RegisterGui(gui)
	if not gui then
		return
	end

	self._registeredGuis[gui] = true
end

function GuiController:SetConstantGui(gui, enabled)
	if not gui then
		return
	end

	self._constantGuis[gui] = enabled == true
end

function GuiController:SetNonEffectGui(gui, enabled)
	if not gui then
		return
	end

	self._nonEffectGuis[gui] = enabled == true
end

function GuiController:SetVariable(name, value)
	self._variables[name] = value
end

function GuiController:GetVariable(name)
	return self._variables[name]
end

function GuiController:GetGui(guiName)
	local playerGui = getPlayerGui()
	local gui = playerGui:FindFirstChild(guiName)

	if gui and gui:IsA("ScreenGui") then
		self:RegisterGui(gui)
		return gui
	end

	return nil
end

function GuiController:GetMainFrame(gui)
	if not gui then
		return nil
	end

	local directNames = {
		"Main",
		"MainFrame",
		"Frame",
		"Container",
		"Holder",
	}

	for _, name in ipairs(directNames) do
		local child = gui:FindFirstChild(name)

		if isGuiObject(child) then
			return child
		end
	end

	for _, child in ipairs(gui:GetChildren()) do
		if isGuiObject(child) then
			return child
		end
	end

	return nil
end

function GuiController:CloseMainFrame(frame)
	if not isGuiObject(frame) then
		return
	end

	frame.Visible = false

	if self.CurrentMainFrame == frame then
		self.CurrentMainFrame = nil
	end
end

function GuiController:OpenMainFrame(frame)
	if not isGuiObject(frame) then
		return
	end

	if self.CurrentMainFrame and self.CurrentMainFrame ~= frame then
		self:CloseMainFrame(self.CurrentMainFrame)
	end

	frame.Visible = true
	self.CurrentMainFrame = frame
end

function GuiController:ToggleMainFrame(frame, forceOpen)
	if not isGuiObject(frame) then
		return
	end

	if forceOpen == true then
		self:OpenMainFrame(frame)
		return
	end

	if forceOpen == false then
		self:CloseMainFrame(frame)
		return
	end

	if frame.Visible then
		self:CloseMainFrame(frame)
	else
		self:OpenMainFrame(frame)
	end
end

function GuiController:TweenGuiObject(guiObject, goal, tweenInfo)
	if not isGuiObject(guiObject) then
		return nil
	end

	local tween = TweenService:Create(guiObject, tweenInfo or DEFAULT_TWEEN_INFO, goal)
	tween:Play()

	return tween
end

return GuiController