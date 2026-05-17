local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotIdle = {}

local DEFAULT_IDLE_FOLDER_PATH = { "Assets", "Animations", "Brainrots", "Idle" }
local TRACKS_BY_MODEL = setmetatable({}, { __mode = "k" })

local function normalizeName(value: any): string
	return tostring(value or ""):lower():gsub("%W", "")
end

local function getIdleFolder(): Instance?
	local current: Instance? = ReplicatedStorage
	for _, name in ipairs(DEFAULT_IDLE_FOLDER_PATH) do
		current = current and current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

local function getBrainrotConfig(framework, brainrotId: string?)
	local configs = framework and framework.Config and framework.Config.Brainrots
	if type(configs) ~= "table" or type(brainrotId) ~= "string" then
		return nil
	end
	return configs[brainrotId]
end

local function addCandidate(candidates: { string }, value: any)
	if type(value) ~= "string" or value == "" then
		return
	end
	if not table.find(candidates, value) then
		table.insert(candidates, value)
	end
end

local function getAnimationCandidates(framework, model: Model, info): { string }
	local candidates = {}
	local brainrotId = type(info) == "table" and info.BrainrotId or nil
	local modelName = model.Name

	addCandidate(candidates, brainrotId)
	addCandidate(candidates, type(info) == "table" and info.ModelName or nil)
	addCandidate(candidates, modelName)

	local config = getBrainrotConfig(framework, if type(brainrotId) == "string" then brainrotId else modelName)
	if type(config) == "table" then
		addCandidate(candidates, config.ModelName)
	end

	config = getBrainrotConfig(framework, modelName)
	if type(config) == "table" then
		addCandidate(candidates, config.ModelName)
	end

	return candidates
end

local function findIdleAnimation(framework, model: Model, info): Animation?
	local idleFolder = getIdleFolder()
	if not idleFolder then
		return nil
	end

	for _, name in ipairs(getAnimationCandidates(framework, model, info)) do
		local exact = idleFolder:FindFirstChild(name)
		if exact and exact:IsA("Animation") then
			return exact
		end
	end

	local wanted = {}
	for _, name in ipairs(getAnimationCandidates(framework, model, info)) do
		wanted[normalizeName(name)] = true
	end

	for _, child in ipairs(idleFolder:GetChildren()) do
		if child:IsA("Animation") and wanted[normalizeName(child.Name)] then
			return child
		end
	end

	return nil
end

local function getAnimator(model: Model): Animator?
	local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		return animator
	end

	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "BrainrotAnimationController"
		controller.Parent = model
	end

	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end
	return animator
end

function BrainrotIdle.Stop(model: Model?)
	local state = model and TRACKS_BY_MODEL[model]
	if not state then
		return
	end

	TRACKS_BY_MODEL[model] = nil
	if state.DestroyingConnection then
		state.DestroyingConnection:Disconnect()
	end
	if state.Track then
		pcall(function()
			state.Track:Stop(0.15)
			state.Track:Destroy()
		end)
	end
end

function BrainrotIdle.Play(model: Model?, framework, info): AnimationTrack?
	if not model or not model:IsA("Model") then
		return nil
	end

	local animation = findIdleAnimation(framework, model, info)
	if not animation then
		BrainrotIdle.Stop(model)
		return nil
	end

	local current = TRACKS_BY_MODEL[model]
	if current and current.Animation == animation and current.Track and current.Track.IsPlaying then
		return current.Track
	end

	BrainrotIdle.Stop(model)

	local animator = getAnimator(model)
	if not animator then
		return nil
	end

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return nil
	end

	track.Looped = true
	track.Priority = Enum.AnimationPriority.Idle
	track:Play(0.15)

	TRACKS_BY_MODEL[model] = {
		Animation = animation,
		Track = track,
		DestroyingConnection = model.Destroying:Connect(function()
			BrainrotIdle.Stop(model)
		end),
	}

	return track
end

return BrainrotIdle
