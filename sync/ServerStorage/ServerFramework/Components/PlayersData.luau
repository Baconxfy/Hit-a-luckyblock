local EzProfile = require(game:GetService("ServerStorage"):WaitForChild("ServerPackages"):WaitForChild("EzProfile"))
local MessageFunctions = require(script:WaitForChild("MessageFunctions"))

--< Init
return function()
	EzProfile:FillFolder(function(Player: Player, Profile, ProfileFolder: Folder) 
		warn(`[{script.Name}]: Fill the ProfileFolder with data HERE!`)
		warn(`You can use some Utils with EzProfile.Utils\n`)

		EzProfile.Utils.TableToFolder(Profile.Data, ProfileFolder)

	end)

	EzProfile:OnProfileSetup(function(Player: Player, Profile, ProfileFolder: Folder?) 
		
		Profile.OnSave:Connect(function() 
			warn(`[{script.Name}]: Save the ProfileFolder data HERE!`)
			warn(`You can use some Utils with EzProfile.Utils\n`)
			Profile.Data = EzProfile.Utils.FolderToTable(ProfileFolder)
		end)
			
			
		Profile:MessageHandler(function(message:{}, processed: () -> ()) 

			local Action = message.Action or message.action
			if not Action then
				warn(`[{Profile.Key} MessageHandler]: No "Action" in message:`,message)
				warn(`No "Action" in message => Message DISCARDED\n`)
				processed()
				return
			end

			local ActionFunction = MessageFunctions[Action]
			if not ActionFunction then
				warn(`[{Profile.Key} MessageHandler]: ActionFunction is nil, check the message:`,message)
				warn("Message NOT processed\n")
				return
			end

			local Work,Result = pcall(ActionFunction, Player, Profile, ProfileFolder)
			if not Work then
				warn(`[{Profile.Key} MessageHandler ERROR]`, Result)
				warn("Message NOT processed\n")
				return
			end

			processed()

		end)

	end)

	EzProfile:OnDataLoaded(function(Player: Player, Profile, ProfileFolder: Folder?) 
		
		Player:SetAttribute("DataLoaded", true)
		
		local CashVal :NumberValue = ProfileFolder:WaitForChild("Cash")
		
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		
		for _,v in pairs({CashVal}) do
			local cloneVal = v:Clone()
			cloneVal.Parent = leaderstats
			v.Changed:Connect(function(value: number) 
				cloneVal.Value = value	
			end)
		end
		
		leaderstats.Parent = Player
	end)
	
	EzProfile:Init()
end