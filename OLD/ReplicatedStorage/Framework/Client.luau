--[[


░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

--< Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--< Modules
local ComponentManager = require(script.Parent:WaitForChild("Modules"):WaitForChild("ComponentManager"))

--< Variables
local ClientComponentsFolder = ReplicatedStorage:WaitForChild("Framework"):WaitForChild("Components")
local LocalPlayer = Players.LocalPlayer

return function()
	
	--< Manual Init Modules
	ComponentManager.InitComponent(script:FindFirstChild("_init"))
	task.wait()
	
	--< Auto Init Folder Modules
	ComponentManager.InitFolderComponents(ClientComponentsFolder)

	--< Start Client
	LocalPlayer:SetAttribute("_clientLoaded", true)
	print(`🔵 {script.Name} Components`)
	
end
