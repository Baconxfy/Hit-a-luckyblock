--< Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--< Modules
local UiAnimations = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UiAnimations"))
local GuiController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("GuiController"))

--< Variables
local LocalPlayer = Players.LocalPlayer
local Guis = ReplicatedStorage:WaitForChild("Framework"):WaitForChild("Guis")

return function()
	
	GuiController:Init()
	GuiController:SetVariable("PlayerModule", require(LocalPlayer:WaitForChild("PlayerScripts").PlayerModule))
	
	GuiController:ReplicateGUIS(Guis, function(_: number, item: Instance) 
		if not item:IsA("ScreenGui") then return end

		GuiController:SetConstantGui(item, true)
		GuiController:RegisterGui(item)

		if item.Name == "HUD" then
			GuiController:SetDefaultGui(item)
		
		elseif item.Name == "Test" then
			
		
		else
			local frame = GuiController:SetMainFrame(item, nil, false)
			--ClientLibrary.GuiController:SetConstantGui(frame, true)
			
		end

	end)
	

	
end