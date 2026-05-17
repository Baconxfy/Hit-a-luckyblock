--[[


░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

--< Services
local ServerStorage = game:GetService("ServerStorage")

--< Modules
local ComponentManager = require(game:GetService("ReplicatedStorage"):WaitForChild("Framework"):WaitForChild("Modules"):WaitForChild("ComponentManager"))

--< Variables
local ServerComponentsFolder = ServerStorage.ServerFramework.Components

task.wait()
return function()
	--< Manual Init Modules


	--< Auto Init Folder Modules
	ComponentManager.InitFolderComponents(ServerComponentsFolder)

	--< Start Client
	workspace:SetAttribute("_serverLoaded", true)
	print(`🟢 {script.Name} Components`)


end
