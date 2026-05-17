--[[

░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

return function(
	TweenInfo: TweenInfo,
	Callback: (Alpha: number, Passed: number) -> (),
	OnCompleteCallback: ((PlaybackState: Enum.PlaybackState) -> ())?
)
	-- Basic validation
	--if not TweenInfo or TweenInfo.Time <= 0 then
	--	error("Invalid TweenInfo: Time must be greater than 0", 2)
	--end

	local HeartbeatConnection: RBXScriptConnection?
	local StartTime: number = os.clock()
	local PausedTime: number = 0
	local IsPaused: boolean = false
	local IsComplete: boolean = false
	local CurrentIteration: number = 0

	-- Calculate total number of iterations
	local TotalIterations: number = TweenInfo.RepeatCount == -1 and math.huge or (TweenInfo.RepeatCount + 1)

	local function CalculateProgress(): number
		if IsPaused then
			return PausedTime
		end
		return os.clock() - StartTime - PausedTime
	end

	local function Update()
		if IsPaused or IsComplete then
			return
		end

		local ElapsedTime: number = CalculateProgress()

		-- Handle delay
		if ElapsedTime < TweenInfo.DelayTime then
			return
		end

		ElapsedTime = ElapsedTime - TweenInfo.DelayTime

		-- Calculate current iteration progress
		local IterationProgress: number = math.clamp(ElapsedTime / TweenInfo.Time, 0, 1)

		-- Determine if we're reversing
		if TweenInfo.Reverses and CurrentIteration % 2 == 1 then
			IterationProgress = 1 - IterationProgress
		end

		-- Calculate alpha with easing
		local Alpha: number = TweenService:GetValue(IterationProgress, TweenInfo.EasingStyle, TweenInfo.EasingDirection)

		-- Calculate total progress (0 to 1) considering all iterations
		local TotalProgress: number = (CurrentIteration + IterationProgress) / TotalIterations
		TotalProgress = math.clamp(TotalProgress, 0, 1)

		-- Execute callback
		Callback(Alpha, TotalProgress)

		-- Check if current iteration is complete
		if IterationProgress >= 1 then
			CurrentIteration = CurrentIteration + 1

			-- Check if all iterations are complete
			if CurrentIteration >= TotalIterations then
				IsComplete = true
				if HeartbeatConnection then
					HeartbeatConnection:Disconnect()
					HeartbeatConnection = nil
				end

				-- Call completion callback
				if OnCompleteCallback then
					task.spawn(OnCompleteCallback, Enum.PlaybackState.Completed)
				end
			else
				-- Reset for next iteration
				StartTime = os.clock()
				PausedTime = 0
			end
		end
	end

	HeartbeatConnection = RunService.Heartbeat:Connect(Update)

	local Controller = {
		Cancel = function(self)
			IsComplete = true
			if HeartbeatConnection then
				HeartbeatConnection:Disconnect()
				HeartbeatConnection = nil
			end
			if OnCompleteCallback then
				task.spawn(OnCompleteCallback, Enum.PlaybackState.Cancelled)
			end
		end,

		Pause = function(self)
			if not IsPaused and not IsComplete then
				IsPaused = true
				PausedTime = CalculateProgress()
			end
		end,

		Resume = function(self)
			if IsPaused and not IsComplete then
				IsPaused = false
				StartTime = os.clock() - PausedTime
				PausedTime = 0
			end
		end,

		IsPaused = function(self): boolean
			return IsPaused
		end,

		IsComplete = function(self): boolean
			return IsComplete
		end,

		GetProgress = function(self): number
			if IsComplete then
				return 1
			end
			local ElapsedTime: number = CalculateProgress() - TweenInfo.DelayTime
			if ElapsedTime < 0 then
				return 0
			end
			local IterationProgress: number = math.clamp(ElapsedTime / TweenInfo.Time, 0, 1)
			return (CurrentIteration + IterationProgress) / TotalIterations
		end,

		Disconnect = function(self)
			self:Cancel()
		end,
	}

	return Controller
end
