local Framework: any = require(game:GetService("ReplicatedStorage").Framework :: ModuleScript)

local MenuController = Framework:CreateController("MenuController")

function MenuController:Initialize()
	self.Menus = {}
	self.SideButtons = {}
	self.LocalPlayer = game.Players.LocalPlayer
	self.PlayerGui = self.LocalPlayer:WaitForChild("PlayerGui")
end

function MenuController:Start()
	self:BindSideButtons()
end

function MenuController:BindSideButtons()
	local sideButtonsGui = self.PlayerGui:FindFirstChild("SideButtonsGui")
	local mainHolder = sideButtonsGui and sideButtonsGui:FindFirstChild("MainHolder", true)
	if not mainHolder then
		return
	end

	for _, guiButton in ipairs(mainHolder:GetChildren()) do
		if guiButton:IsA("GuiButton") and not self.SideButtons[guiButton] then
			local button = Framework.Components.Button:new(guiButton)
			self.SideButtons[guiButton] = button
			self:AddChild(button)

			button:SetOnClick(function()
				local menu = self.Menus[guiButton.Name]
				if menu then
					menu:Open()
				end
			end)
		end
	end
end

function MenuController:RegisterMenu(menuComponent)
	if not menuComponent or not menuComponent.Name then
		return
	end
	self.Menus[menuComponent.Name] = menuComponent
end

function MenuController:GetMenu(name: string)
	return self.Menus[name]
end

function MenuController:Open(name: string)
	local menu = self:GetMenu(name)
	if menu then
		menu:Open()
	end
end

function MenuController:Close(name: string)
	local menu = self:GetMenu(name)
	if menu then
		menu:Close()
	end
end

function MenuController:Toggle(name: string)
	local menu = self:GetMenu(name)
	if menu then
		menu:Toggle()
	end
end

function MenuController:CloseAllExcept(menuComponent)
	for _, menu in pairs(self.Menus) do
		if menu ~= menuComponent and (menu._isOpen or menu._busy) then
			menu:Close()
		end
	end
end

function MenuController:IsAnyMenuOpen(): boolean
	for _, menu in pairs(self.Menus) do
		if menu and (menu._isOpen or menu._busy) then
			return true
		end
	end
	return false
end

function MenuController:ShowSideButtons()
	for _, button in pairs(self.SideButtons) do
		if button.Gui then
			button.Gui.Visible = true
		end
	end
end

function MenuController:HideSideButtons()
	for _, button in pairs(self.SideButtons) do
		if button.Gui then
			button.Gui.Visible = false
		end
	end
end

return MenuController
