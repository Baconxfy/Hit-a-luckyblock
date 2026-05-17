local GuiController = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("GuiController"))
local GuiLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("GuiLibrary"))


return function()
	
	local HUDGui :ScreenGui = GuiController:GetGui("HUD")
	local LeftButtons :Frame = HUDGui:WaitForChild("LeftButtons")

	--for _, buttonName :string in pairs({"Index", "Shop", "Rebirth"}) do
	--	local button :ImageButton = LeftButtons:WaitForChild(buttonName)
	--	GuiLibrary.Button.Hover(button)
	--	GuiLibrary.Button.OnClick(button, function(inputObj: InputObject, clickCount: number) 
	--		GuiController:ToggleMainFrame(GuiController:GetMainFrame(GuiController:GetGui(button.Name)))
	--	end)
	--end
	
	
	
end