--[[

░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

---Utility functions for managing Sound objects in Roblox.
---Provides fade effects, sound creation, and cloning capabilities.
---Optimized for both client and server side usage.
local SoundUtils = {}

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Cache for tracking sound states and connections
local SoundData = {}

---Cleans up sound data when sound is destroyed
local function CleanupSoundData(Sound: Sound)
	if SoundData[Sound] then
		local Data = SoundData[Sound]
		if Data.FadeInConnection then
			Data.FadeInConnection:Disconnect()
		end
		if Data.FadeOutConnection then
			Data.FadeOutConnection:Disconnect()
		end
		if Data.EndedConnection then
			Data.EndedConnection:Disconnect()
		end
		if Data.FadeInTween then
			Data.FadeInTween:Cancel()
		end
		if Data.FadeOutTween then
			Data.FadeOutTween:Cancel()
		end
		SoundData[Sound] = nil
	end
end

---Fades in a sound by gradually increasing its volume from 0 to its original volume.
---@param Sound Sound The sound object to fade in
---@param Duration number? The duration of the fade in seconds (default: 1)
---@return Tween? The tween object if successful
local function FadeInSound(Sound: Sound, Duration: number?)
	if not Sound or not Sound.Parent then
		return nil
	end

	local FadeDuration = Duration or 1

	-- Get target volume from stored data or current volume
	local TargetVolume
	if SoundData[Sound] and SoundData[Sound].TargetVolume then
		TargetVolume = SoundData[Sound].TargetVolume
	else
		TargetVolume = Sound.Volume
		-- Store it for future use
		if not SoundData[Sound] then
			SoundData[Sound] = {}
		end
		SoundData[Sound].TargetVolume = TargetVolume
	end

	-- Cancel any existing fade operations
	if SoundData[Sound] then
		local Data = SoundData[Sound]
		if Data.FadeInTween then
			Data.FadeInTween:Cancel()
		end
		if Data.FadeOutTween then
			Data.FadeOutTween:Cancel()
		end
	end

	-- Always start fade in from 0
	Sound.Volume = 0

	local TweenInfo = TweenInfo.new(FadeDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.In)

	local Tween = TweenService:Create(Sound, TweenInfo, { Volume = TargetVolume })

	-- Store tween reference
	if not SoundData[Sound] then
		SoundData[Sound] = {}
		-- Cleanup on destroy
		Sound.AncestryChanged:Connect(function()
			if not Sound.Parent then
				CleanupSoundData(Sound)
			end
		end)
	end

	SoundData[Sound].FadeInTween = Tween
	SoundData[Sound].TargetVolume = TargetVolume

	Tween:Play()

	-- Clean up tween reference when complete
	Tween.Completed:Connect(function()
		if SoundData[Sound] then
			SoundData[Sound].FadeInTween = nil
		end
	end)

	return Tween
end

---Fades out a sound by gradually decreasing its volume to 0.
---@param Sound Sound The sound object to fade out
---@param Duration number? The duration of the fade in seconds (default: 1)
---@return Tween? The tween object if successful
local function FadeOutSound(Sound: Sound, Duration: number?)
	if not Sound or not Sound.Parent then
		return nil
	end

	local FadeDuration = Duration or 1
	local StartVolume = Sound.Volume

	-- Cancel any existing fade operations
	if SoundData[Sound] then
		local Data = SoundData[Sound]
		if Data.FadeInTween then
			Data.FadeInTween:Cancel()
		end
		if Data.FadeOutTween then
			Data.FadeOutTween:Cancel()
		end
	end

	local TweenInfo = TweenInfo.new(FadeDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

	local Tween = TweenService:Create(Sound, TweenInfo, { Volume = 0 })

	-- Store tween reference
	if not SoundData[Sound] then
		SoundData[Sound] = {}
		-- Cleanup on destroy
		Sound.AncestryChanged:Connect(function()
			if not Sound.Parent then
				CleanupSoundData(Sound)
			end
		end)
	end

	SoundData[Sound].FadeOutTween = Tween

	Tween:Play()

	-- Stop sound and clean up when fade completes
	Tween.Completed:Connect(function()
		if Sound and Sound.Parent then
			Sound:Stop()
		end
		if SoundData[Sound] then
			SoundData[Sound].FadeOutTween = nil
		end
	end)

	return Tween
end

---Clones a sound and parents it to the specified instance with optional properties and lifetime.
---@param Sound Sound The sound object to clone
---@param Instance Instance The instance to parent the cloned sound to
---@param Properties {[string]:any}? Optional properties to apply to the cloned sound
---@param LifeTime number? Optional lifetime in seconds before the sound is destroyed
---@return Sound The cloned sound object
local function CloneInInstance(
	Sound: Sound,
	Instance: Instance,
	Properties: { [string]: any }?,
	LifeTime: number?
): Sound
	local ClonedSound = Sound:Clone()

	if Properties then
		for Key, Value in pairs(Properties) do
			ClonedSound[Key] = Value
		end
	end

	ClonedSound.Parent = Instance

	if LifeTime then
		task.delay(LifeTime, function()
			if ClonedSound.Parent then
				ClonedSound:Destroy()
			end
		end)
	end

	return ClonedSound
end

---Creates a new sound in the specified instance from a SoundId, string URL, or asset ID.
---@param SoundId Sound|string|number The sound to clone, sound ID string, or asset ID number
---@param Instance Instance The instance to parent the sound to
---@param Properties {[string]:any}? Optional properties to apply to the sound
---@param LifeTime number? Optional lifetime in seconds before the sound is destroyed
---@return Sound The created sound object
local function CreateInPart(
	SoundId: Sound | string | number,
	Instance: Instance,
	Properties: { [string]: any }?,
	LifeTime: number?
): Sound
	local NewSound = Instance.new("Sound")

	if typeof(SoundId) == "Instance" and SoundId:IsA("Sound") then
		NewSound.SoundId = SoundId.SoundId
	elseif typeof(SoundId) == "string" then
		NewSound.SoundId = SoundId
	elseif typeof(SoundId) == "number" then
		NewSound.SoundId = "rbxassetid://" .. tostring(SoundId)
	end

	if Properties then
		for Key, Value in pairs(Properties) do
			NewSound[Key] = Value
		end
	end

	NewSound.Parent = Instance

	if LifeTime then
		task.delay(LifeTime, function()
			if NewSound.Parent then
				NewSound:Destroy()
			end
		end)
	end

	return NewSound
end

---Creates a connection that automatically fades in a sound when it starts playing.
---The fade happens automatically whenever the sound starts.
---@param Sound Sound The sound object to fade in
---@param Duration number? The duration of the fade in seconds (default: 1)
---@return RBXScriptConnection The connection that handles the fade in
local function FadeInConnection(Sound: Sound, Duration: number?): RBXScriptConnection
	local FadeDuration = Duration or 1

	-- Initialize sound data if needed
	if not SoundData[Sound] then
		SoundData[Sound] = {}
		-- Cleanup on destroy
		Sound.AncestryChanged:Connect(function()
			if not Sound.Parent then
				CleanupSoundData(Sound)
			end
		end)
	end

	-- Store target volume
	if not SoundData[Sound].TargetVolume then
		SoundData[Sound].TargetVolume = Sound.Volume
	end

	-- Disconnect existing connection if any
	if SoundData[Sound].FadeInConnection then
		SoundData[Sound].FadeInConnection:Disconnect()
	end

	-- Track previous playing state to detect when sound starts
	local WasPlaying = Sound.IsPlaying
	local HasFadedIn = false

	-- Create connection that monitors when sound starts playing
	local Connection = RunService.Heartbeat:Connect(function()
		if not Sound.Parent then
			return
		end

		local IsPlaying = Sound.IsPlaying

		-- Detect transition from not playing to playing
		if IsPlaying and not WasPlaying and not HasFadedIn then
			HasFadedIn = true
			FadeInSound(Sound, FadeDuration)
		end

		-- Reset flag when sound stops
		if not IsPlaying and WasPlaying then
			HasFadedIn = false
		end

		WasPlaying = IsPlaying
	end)

	SoundData[Sound].FadeInConnection = Connection

	-- Set volume to 0 if sound isn't playing yet (so it fades in when it starts)
	if not Sound.IsPlaying then
		Sound.Volume = 0
	else
		-- If already playing, fade in immediately
		HasFadedIn = true
		FadeInSound(Sound, FadeDuration)
	end

	return Connection
end

---Creates a connection that automatically fades out a sound when it's about to end.
---The fade happens automatically when the sound reaches near its end time.
---@param Sound Sound The sound object to fade out
---@param Duration number? The duration of the fade in seconds (default: 1)
---@param FadeStartOffset number? How many seconds before the end to start fading (default: same as Duration)
---@return RBXScriptConnection The connection that handles the fade out
local function FadeOutConnection(Sound: Sound, Duration: number?, FadeStartOffset: number?): RBXScriptConnection
	local FadeDuration = Duration or 1
	local StartOffset = FadeStartOffset or FadeDuration

	-- Initialize sound data if needed
	if not SoundData[Sound] then
		SoundData[Sound] = {}
		-- Cleanup on destroy
		Sound.AncestryChanged:Connect(function()
			if not Sound.Parent then
				CleanupSoundData(Sound)
			end
		end)
	end

	-- Disconnect existing connections if any
	if SoundData[Sound].FadeOutConnection then
		SoundData[Sound].FadeOutConnection:Disconnect()
	end
	if SoundData[Sound].EndedConnection then
		SoundData[Sound].EndedConnection:Disconnect()
	end

	-- Track if fade has started
	local HasStartedFade = false

	-- Create connection that monitors sound position and fades out near the end
	local Connection = RunService.Heartbeat:Connect(function()
		if not Sound.Parent or not Sound.IsPlaying then
			return
		end

		-- Wait for TimeLength to be available
		if Sound.TimeLength <= 0 then
			return
		end

		local TimeRemaining = Sound.TimeLength - Sound.TimePosition

		-- Start fade when we're close to the end
		if TimeRemaining <= StartOffset and not HasStartedFade then
			HasStartedFade = true
			FadeOutSound(Sound, FadeDuration)
		end

		-- Reset flag if sound loops or restarts
		if Sound.TimePosition < 0.1 then
			HasStartedFade = false
		end
	end)

	-- Also handle Ended event as backup
	local EndedConnection = Sound.Ended:Connect(function()
		HasStartedFade = false
		if Sound.Volume > 0 then
			Sound.Volume = 0
		end
	end)

	SoundData[Sound].FadeOutConnection = Connection
	SoundData[Sound].EndedConnection = EndedConnection

	return Connection
end

---Enables automatic fade in and fade out for a sound.
---Fade in happens when sound starts, fade out happens when sound is about to end.
---@param Sound Sound The sound object to enable auto-fade for
---@param FadeInDuration number? The duration of fade in in seconds (default: 1)
---@param FadeOutDuration number? The duration of fade out in seconds (default: 1)
---@param FadeOutStartOffset number? How many seconds before the end to start fading out (default: same as FadeOutDuration)
local function EnableAutoFade(
	Sound: Sound,
	FadeInDuration: number?,
	FadeOutDuration: number?,
	FadeOutStartOffset: number?
)
	FadeInConnection(Sound, FadeInDuration)
	FadeOutConnection(Sound, FadeOutDuration, FadeOutStartOffset)
end

---Disables automatic fade in and fade out for a sound.
---@param Sound Sound The sound object to disable auto-fade for
local function DisableAutoFade(Sound: Sound)
	CleanupSoundData(Sound)
end

-- Export functions
SoundUtils.FadeInSound = FadeInSound
SoundUtils.FadeOutSound = FadeOutSound
SoundUtils.CloneInInstance = CloneInInstance
SoundUtils.CreateInPart = CreateInPart
SoundUtils.FadeInConnection = FadeInConnection
SoundUtils.FadeOutConnection = FadeOutConnection
SoundUtils.EnableAutoFade = EnableAutoFade
SoundUtils.DisableAutoFade = DisableAutoFade

return SoundUtils
