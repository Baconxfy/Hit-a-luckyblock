local Players = game:GetService("Players")
local test = require(game:GetService("ServerStorage"):WaitForChild("ServerFramework"):WaitForChild("Modules"):WaitForChild("test"))


return function()
	
	Players.PlayerAdded:Connect(function(player: Player) 
		player.CharacterAdded:Connect(function(character: Model) 
			task.wait(5)
			test.AttachLuckyBlock(character)
			task.wait()
			local holdtrack = test.GetHoldTrack(character)
			holdtrack:Play()
			task.wait(7)
			holdtrack:Stop()
			holdtrack:Destroy()
			test.AttachBat(character)
			task.wait(.1)
			local hitTrack = test.GetHitTrack(character)
			hitTrack.Looped = true
			hitTrack:Play()
			hitTrack:GetMarkerReachedSignal("Hit"):Connect(function(...) 
				print("HIT!!!")	
			end)
			
		end)	
		
	end)
	
end