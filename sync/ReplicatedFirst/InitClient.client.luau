--< Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--< Modules
local Worked, Result = pcall(function()
	require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("ClientLoader"))
end)

if not Worked then
	warn("🔴 Client Big Error:", Result)
	Players.LocalPlayer:Kick("🔴 Something went wrong while loading the game. Please rejoin.")
end
