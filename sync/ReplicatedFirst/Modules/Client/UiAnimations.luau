--[[


░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

-- Services
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Modules
local Janitor = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Janitor"))
local Threads = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Threads"))
local TweenByAlpha = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("TweenByAlpha"))

-- Variables
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Constants
local RNG = Random.new()

local scales = {
	0.1,
	0.2,
	0.3,
	0.4,
	0.5,
	0.6,
	0.7,
	0.8,
}

-- Module
local module = {}

-- Private State
module.JumpingState = {}
module.IsShaking = {}
module.Pulsed = {}
module.Active = {}

--[[
	================================================================================
	BASIC ANIMATION FUNCTIONS
	================================================================================
]]

--[[
	Creates a flying animation effect for a GuiObject.
	The object moves up and down smoothly while rotating slightly.
	
	@param Object: GuiObject - The GuiObject to animate
	@param speed: number? - Animation speed multiplier (default: 1)
	@returns function - A cleanup function that stops the animation and resets the object's position and rotation
]]
module.Flying = function(Object: GuiObject, speed: number)
	if not speed then
		speed = 1
	end

	local InitPos = Object.Position
	local connect: RBXScriptConnection

	connect = RunService.Heartbeat:Connect(function(deltaTime: number)
		if Object:GetAttribute("hiden") then
			return
		end

		local formula = tick() * 5 * speed
		local cos, sin = math.cos(formula), math.sin(formula)

		Object.Position = InitPos + UDim2.fromScale(0, sin / 50)
		Object.Rotation = cos * 5
	end)

	return function()
		connect:Disconnect()
		Object.Position = InitPos
		Object.Rotation = 0
	end
end

--[[
	Creates a dancing animation effect for a GuiObject.
	The object bounces vertically while rotating rhythmically.
	
	@param Object: GuiObject - The GuiObject to animate
	@returns function - A cleanup function that stops the animation and resets the object's position and rotation
]]
module.Dancing = function(Object: GuiObject)
	local InitPos = Object.Position
	local connect: RBXScriptConnection

	connect = RunService.RenderStepped:Connect(function(deltaTime: number)
		local formula = tick() * 15
		local cos, sin = math.cos(formula / 5), math.sin(formula)

		Object.Position = InitPos + UDim2.fromScale(0, sin / 100)
		Object.Rotation = cos * 12
	end)

	return function()
		connect:Disconnect()
		Object.Position = InitPos
		Object.Rotation = 0
	end
end

--[[
	Creates a continuous rotation animation for a GuiObject.
	The object rotates smoothly at a constant speed.
	
	@param Object: GuiObject - The GuiObject to animate
	@returns function - A cleanup function that stops the animation and resets the object's rotation
]]
module.Rotation = function(Object: GuiObject)
	local connect: RBXScriptConnection
	local angles = 0

	connect = RunService.RenderStepped:Connect(function(deltaTime: number)
		angles += 45 * deltaTime
		Object.Rotation = angles

		if angles >= 360 then
			angles = 0
		end
	end)

	return function()
		connect:Disconnect()
		Object.Rotation = 0
	end
end

--[[
	Creates a shaking animation for a GuiObject.
	The object shakes with decreasing intensity over time.
	Prevents multiple simultaneous animations on the same object.
	
	@param Object: GuiObject - The GuiObject to animate
]]
module.Shaking = function(Object: GuiObject)
	if module.IsShaking[Object] then
		return
	end

	module.IsShaking[Object] = true

	local initPos = Object.Position

	TweenByAlpha(TweenInfo.new(1, Enum.EasingStyle.Linear), function(alpha: number, Passed: number)
		local formula = tick() * 25
		local cos, sin = math.cos(formula), math.sin(formula)
		local lerpValue = 1 - alpha

		Object.Position = initPos + UDim2.fromScale(0, (sin / 50) * lerpValue)
		Object.Rotation = (cos * 5) * lerpValue

		if Passed == 1 then
			module.IsShaking[Object] = nil
		end
	end)
end

--[[
	Creates a jumping and shaking animation for a GuiObject.
	The object jumps upward while shaking, then returns to its original position.
	Prevents multiple simultaneous animations on the same object.
	
	@param Object: GuiObject - The GuiObject to animate
	@param strength: number? - Animation strength multiplier (default: 1)
]]
module.JumpAndShake = function(Object: GuiObject, strength: number)
	if module.JumpingState[Object] then
		return
	end

	if not strength then
		strength = 1
	end

	local InitPos = Object.Position
	module.JumpingState[Object] = true

	TweenByAlpha(
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		function(alpha: number, Passed: number)
			local lerp2d = (1 - alpha)
			local up = InitPos - UDim2.fromScale(0, 0.25 * alpha)

			Object.Rotation = (math.cos(tick() * 25) * 15 * strength) * lerp2d
			Object.Position = up

			if Passed == 1 then
				local returnTween =
					TweenService:Create(Object, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.InOut), {
						Position = InitPos,
					})

				returnTween:Play()

				returnTween.Completed:Once(function(playbackState: Enum.PlaybackState)
					module.JumpingState[Object] = nil
				end)
			end
		end
	)
end

--[[
	Creates a jumping and rotation animation for a GuiObject.
	The object jumps upward while rotating 360 degrees, then returns to its original position.
	
	@param object: GuiObject - The GuiObject to animate
]]
module.JumpAndRotation = function(object: GuiObject)
	local InitPos = object:GetAttribute("pos")
	if not InitPos then
		object:SetAttribute("pos", object.Position)
		InitPos = object.Position
	end

	local tween = TweenService:Create(object, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {
		Position = InitPos - UDim2.fromScale(0, 0.3),
	})

	local rotation = TweenService:Create(object, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Rotation = 360,
	})

	tween:Play()
	rotation:Play()

	tween.Completed:Once(function(playbackState: Enum.PlaybackState)
		TweenService:Create(object, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = InitPos,
		}):Play()
	end)

	rotation.Completed:Once(function(playbackState: Enum.PlaybackState)
		if playbackState == Enum.PlaybackState.Completed then
			object.Rotation = 0
		end
	end)
end

--[[
	Creates a 2D GUI shaking animation with decreasing intensity.
	Prevents multiple simultaneous animations on the same object.
	
	@param Gui: GuiObject - The GuiObject to animate
]]
module.Gui2d = function(Gui: GuiObject)
	local InitPos = Gui.Position

	if module.IsShaking[Gui] then
		return
	end

	module.IsShaking[Gui] = true

	TweenByAlpha(TweenInfo.new(1), function(alpha: number, Passed: number)
		local lerp2d = (1 - alpha)
		Gui.Rotation = (math.cos(tick() * 25) * 15) * lerp2d
		Gui.Position = InitPos + UDim2.fromScale(0, (math.sin(tick() * 25) / 10) * lerp2d)

		if Passed == 1 then
			module.IsShaking[Gui] = nil
		end
	end)
end

--[[
	================================================================================
	SCALE AND TRANSFORM FUNCTIONS
	================================================================================
]]

--[[
	Animates a GuiObject's UIScale from a larger scale to a smaller scale.
	Creates a UIScale if one doesn't exist.
	
	@param Object: GuiObject - The GuiObject to animate
	@param scale: number? - Target scale (default: 1)
	@param FromScale: number? - Starting scale (default: 3)
]]
module.FromBiggerToOne = function(Object: GuiObject, scale: number, FromScale: number)
	local UIScale = Object:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", Object)
	Object.UIScale.Scale = FromScale or 3

	local tween = TweenService:Create(Object.UIScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
		Scale = scale or 1,
	})

	tween:Play()
end

--[[
	Creates a fade out animation effect by cloning the object and animating it.
	The cloned object expands and fades out behind the original.
	Requires that the parent does not have a UIGridLayout.
	
	@param Object: GuiObject - The GuiObject to create the fade out effect for
	@param Color: Color3? - Optional color for the fade effect (default: uses object's BackgroundColor3)
]]
module.FadeOut = function(Object: GuiObject, Color: Color3)
	assert(Object.Parent:FindFirstChildOfClass("UIGridLayout") == nil)

	local isFrame = Object:IsA("Frame")
	local isImage = Object:IsA("ImageLabel") or Object:IsA("ImageButton")

	local newObject = Instance.new(isFrame and "Frame" or "ImageLabel")
	local goal = {
		Size = Object.Size + UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	}
	newObject.BackgroundTransparency = isFrame and 0.25 or 1

	if isFrame then
		newObject.BackgroundColor3 = Color or Object.BackgroundColor3
	else
		newObject.Image = Object.Image
		newObject.ScaleType = Enum.ScaleType.Fit

		goal.ImageTransparency = 1
	end

	if Object:FindFirstChildOfClass("UIAspectRatioConstraint") then
		Object:FindFirstChildOfClass("UIAspectRatioConstraint"):Clone().Parent = newObject
	end

	newObject.AnchorPoint = Object.AnchorPoint
	newObject.Position = Object.Position
	newObject.ZIndex = -1
	newObject.Size = Object.Size
	newObject.Parent = Object.Parent

	local tween = TweenService:Create(newObject, TweenInfo.new(0.5), goal)

	tween:Play()

	tween.Completed:Once(function(playbackState: Enum.PlaybackState)
		newObject:Destroy()
	end)
end

--[[
	================================================================================
	SELECTION AND INDICATOR FUNCTIONS
	================================================================================
]]

--[[
	Creates a rotating selection indicator on a button.
	The indicator continuously rotates around the button.
	
	@param Button: ImageButton - The ImageButton to attach the selection indicator to
	@param Size: UDim2? - Optional size for the indicator (default: UDim2.fromScale(1, 1))
	@param Color: Color3? - Optional color for the indicator (default: Color3.fromRGB(84, 84, 84))
	@returns function - A cleanup function that stops the animation and removes the indicator
]]
module.Selected = function(Button: ImageButton, Size: UDim2, Color: Color3)
	local selectedImage = Instance.new("ImageLabel")
	local canvas = Instance.new("CanvasGroup")
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromScale(1, 1)
	selectedImage.AnchorPoint = Vector2.new(0.5, 0.5)
	selectedImage.BackgroundTransparency = 1
	selectedImage.Image = "rbxassetid://6591760796"
	selectedImage.ImageColor3 = Color or Color3.fromRGB(84, 84, 84)
	selectedImage.ZIndex = -10
	selectedImage.Size = Size or UDim2.fromScale(1, 1)
	selectedImage.ScaleType = Enum.ScaleType.Fit
	selectedImage.Position = UDim2.fromScale(0.5, 0.5)

	selectedImage.Parent = canvas
	canvas.Parent = Button

	local connect = RunService.Heartbeat:Connect(function(deltaTime: number)
		selectedImage.Rotation += math.clamp(45 * deltaTime, 0, 360)
		if selectedImage.Rotation >= 360 then
			selectedImage.Rotation = 0
		end
	end)

	return function()
		connect:Disconnect()
		canvas:Destroy()
	end
end

--[[
	Creates or removes a green checkmark on the specified GuiObject.
	When shown, the checkmark animates with a scale effect.
	
	@param Object: GuiObject - The GuiObject to attach the checkmark to
	@param Value: boolean - Whether to show (true) or hide (false) the checkmark
	@param AnchorPoint: Vector2? - Optional anchor point for the checkmark
	@param Scale: number? - Target scale for the checkmark animation
	@param Properties: {[string]: any}? - Optional table of properties to apply to the checkmark
]]
module.CreateGreenTick = function(
	Object: GuiObject,
	Value: boolean,
	AnchorPoint: Vector2,
	Scale: number,
	Properties: {}
)
	Properties = Properties or {}
	local isFind: ImageLabel? = Object:FindFirstChild("GreenCheckMark")

	if Value then
		if not isFind then
			isFind = script.GreenCheckMark:Clone() :: ImageLabel
			for p, v in Properties do
				isFind[p] = v
			end
			isFind.Parent = Object
		end

		if AnchorPoint then
			isFind.AnchorPoint = AnchorPoint
		end

		module.FromBiggerToOne(isFind, Scale)
		return
	end

	if isFind then
		isFind:Destroy()
	end
end

--[[
	================================================================================
	PARTICLE AND EFFECT FUNCTIONS
	================================================================================
]]

--[[
	Creates a falling scale animation effect using a template object.
	Objects fall from the top and scale down while rotating and fading.
	Uses scale-based positioning (UDim2.fromScale).
	
	@param howMuch: number? - Number of objects to spawn (default: 25)
	@param template: Instance - The template object to clone for the animation
	@param Parent: Instance - The parent container for the animated objects
	@param dropPer: number? - Delay between each object spawn (default: 0.02)
	@param groupTime: number? - Delay between each row group (default: 0)
]]
module.FallingScaleAnim = function(
	howMuch: number,
	template: Instance,
	Parent: Instance,
	dropPer: number,
	groupTime: number
)
	if not howMuch then
		howMuch = 25
	end

	local Rows = math.ceil(howMuch / 25)
	local perRow = howMuch / Rows

	local function spawnTemp(randomX: number, currentRow: number, num: number)
		local new = template:Clone()
		local t = math.random(3, 5)
		local PositionTween =
			TweenService:Create(new, TweenInfo.new(t, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(randomX, 1),
			})

		local div = math.random(1, 2) / currentRow

		new.Size = new.Size - UDim2.fromOffset(div + num, div + num)

		new.AnchorPoint = Vector2.new(1, 0)
		new.Position = UDim2.fromScale(randomX, -0.5)
		new.Visible = true
		new.Parent = Parent

		PositionTween:Play()

		local iconObject = new:FindFirstChild("Icon") or new
		TweenService:Create(iconObject, TweenInfo.new(t, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Rotation = math.random(-360, 360),
			ImageTransparency = 1,
		}):Play()

		PositionTween.Completed:Once(function(playbackState: Enum.PlaybackState)
			new:Destroy()
		end)
	end

	for currentRow = 1, Rows do
		for i = 1, perRow do
			local randomX = RNG:NextInteger(0, 100) / 100

			task.spawn(spawnTemp, randomX, currentRow, i)
			task.wait(dropPer or 0.02)
		end

		task.wait(groupTime or 0)
	end
end

--[[
	Creates a falling animation effect using absolute positioning.
	Objects fall from the top using pixel-based coordinates.
	
	@param howMuch: number? - Number of objects to spawn (default: 25)
	@param template: Instance - The template object to clone for the animation
	@param Parent: Instance - The parent container for the animated objects
	@param dropPer: number? - Delay between each object spawn (default: 0.02)
	@param groupTime: number? - Delay between each row group (default: 0)
]]
module.FallingAnim = function(howMuch: number, template: Instance, Parent: Instance, dropPer: number, groupTime: number)
	if not howMuch then
		howMuch = 25
	end

	local absSize = Parent.AbsoluteSize

	local Rows = math.ceil(howMuch / 25)
	local perRow = howMuch / Rows

	if absSize.X <= 400 then
		absSize = Vector2.new(absSize.X * 3, absSize.Y)
	end

	local function spawnTemp(randomX: number, currentRow: number, num: number)
		local new = template:Clone()
		local t = math.random(3, 5)
		local PositionTween =
			TweenService:Create(new, TweenInfo.new(t, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(randomX, absSize.Y + absSize.Y / 5),
			})

		local div = math.random(1, 2) / currentRow

		new.Size = new.Size - UDim2.fromOffset(div + num, div + num)

		new.AnchorPoint = Vector2.new(1, 0)
		new.Position = UDim2.fromOffset(randomX, -25)
		new.Visible = true
		new.Parent = Parent

		PositionTween:Play()

		local iconObject = new:FindFirstChild("Icon") or new
		TweenService:Create(iconObject, TweenInfo.new(t, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Rotation = math.random(-360, 360),
			ImageTransparency = 1,
		}):Play()

		PositionTween.Completed:Once(function(playbackState: Enum.PlaybackState)
			new:Destroy()
		end)
	end

	for currentRow = 1, Rows do
		for i = 1, perRow do
			local randomX = RNG:NextInteger(0, absSize.X)

			task.spawn(spawnTemp, randomX, currentRow, i)
			task.wait(dropPer or 0.02)
		end

		task.wait(groupTime or 0)
	end
end

--[[
	Creates a confetti animation effect from the top of the screen.
	Uses a script.Confetti template and applies random colors.
	
	@param howMuch: number? - Number of confetti pieces to spawn (default: 25)
	@param textureId: string? - Optional texture ID (currently unused, default: "0")
	@param parent: ScreenGui? - The ScreenGui parent for the confetti
]]
module.TopConfetti = function(howMuch: number, textureId: string, parent: ScreenGui)
	if not howMuch then
		howMuch = 25
	end
	if not textureId then
		textureId = "0"
	end

	local Parent: ScreenGui = parent
	local absSize = Parent.AbsoluteSize

	local Rows = math.ceil(howMuch / 25)
	local perRow = howMuch / Rows

	local function spawnTemp(randomX: number, currentRow: number, num: number)
		local new = script.Confetti:Clone()
		local PositionTween = TweenService:Create(
			new,
			TweenInfo.new(math.random(3, 5), Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
			{
				Position = UDim2.fromOffset(randomX, absSize.Y + absSize.Y / 5),
				Rotation = math.random(-360, 360),
				Size = UDim2.new(),
			}
		)
		local div = math.random(1, 2) / currentRow

		new.Size = new.Size - UDim2.fromOffset(div + num, div + num)
		new.BackgroundColor3 = Color3.fromHSV(tick() / 1 % 1, 1, 1)
		new.AnchorPoint = Vector2.new(1, 0)
		new.Position = UDim2.fromOffset(randomX, -25)

		new.Parent = Parent

		PositionTween:Play()

		PositionTween.Completed:Once(function(playbackState: Enum.PlaybackState)
			new:Destroy()
		end)
	end

	for currentRow = 1, Rows do
		for i = 1, perRow do
			local randomX = RNG:NextInteger(0, absSize.X)

			task.spawn(spawnTemp, randomX, currentRow, i)
			task.wait(0.02)
		end

		task.wait()
	end
end

--[[
	Creates a continuous star animation effect.
	Stars spawn at random positions and animate in and out.
	
	@param holder: GuiObject - The GuiObject container for the stars
	@param t: number? - Delay between each star spawn (default: 1)
	@returns function - A cleanup function that stops the star animation
]]
module.Stars = function(holder: GuiObject, t: number)
	local cancelThread = Threads.newThread(function()
		while true do
			local newStar = script.Stars:Clone()
			local xscale, yscale = scales[math.random(1, #scales)], scales[math.random(1, #scales)]
			local tw = TweenService:Create(
				newStar.UIScale,
				TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0, true),
				{
					Scale = 1,
				}
			)
			newStar.Name = "s_a"
			newStar.Parent = holder
			newStar.Position = UDim2.fromScale(xscale, yscale)

			tw:Play()

			tw.Completed:Once(function(playbackState: Enum.PlaybackState)
				newStar:Destroy()
				tw:Cancel()
			end)

			task.wait(t or 1)
		end
	end)

	local connect
	connect = holder:GetPropertyChangedSignal("Parent"):Connect(function()
		if holder.Parent ~= nil then
			return
		end

		connect:Disconnect()
		cancelThread()
	end)

	return function()
		connect:Disconnect()
		cancelThread()
	end
end

--[[
	================================================================================
	UI EFFECT FUNCTIONS
	================================================================================
]]

--[[
	Creates a pulse animation effect at a specified position.
	The pulse expands and fades out.
	Prevents multiple simultaneous pulses on the same object.
	
	@param Object: GuiObject - The GuiObject to create the pulse effect on
	@param pos: UDim2? - Optional position for the pulse (default: uses script.RedPulse position)
]]
module.Pulse = function(Object: GuiObject, pos: UDim2)
	if module.Pulsed[Object] then
		return
	end

	module.Pulsed[Object] = true

	local newPulse = script.RedPulse:Clone()
	local tween = TweenService:Create(newPulse, TweenInfo.new(0.4, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(2, 2),
		ImageTransparency = 1,
	})

	newPulse.Position = pos or newPulse.Position
	newPulse.Parent = Object

	tween:Play()

	tween.Completed:Once(function(playbackState: Enum.PlaybackState)
		newPulse:Destroy()
	end)

	module.Pulsed[Object] = nil
end

--[[
	Creates an animated arrow that points between two positions.
	The arrow moves back and forth between FromPos and ToPos, and pulses at the target location.
	
	@param Object: GuiObject - The GuiObject arrow to animate
	@param FromPos: UDim2 - The starting position for the arrow
	@param ToPos: UDim2 - The target position for the arrow
	@param PulseAt: GuiObject? - Optional GuiObject to pulse at (default: Object)
	@param PulsePos: UDim2? - Optional position for the pulse effect
	@returns function - A cleanup function that stops the arrow animation
]]
module.PointArrow2 = function(Object: GuiObject, FromPos: UDim2, ToPos: UDim2, PulseAt: GuiObject, PulsePos: UDim2)
	local cancelThread = Threads.newThread(function()
		Object.Visible = true

		while task.wait() do
			local tween = TweenService:Create(Object, TweenInfo.new(1, Enum.EasingStyle.Linear), {
				Position = ToPos,
			})

			local tween2 = TweenService:Create(Object, TweenInfo.new(1, Enum.EasingStyle.Linear), {
				Position = FromPos,
			})

			tween:Play()
			tween.Completed:Wait()

			tween2:Play()
			tween2.Completed:Wait()

			if Object.Visible then
				module.Pulse(PulseAt or Object, PulsePos)
			end
		end
	end)

	return function()
		Object.Visible = false
		cancelThread()
	end
end

--[[
	Creates an animated arrow that pulses in place using scale animation.
	The arrow scales up and down repeatedly, and pulses at a specified location.
	
	@param Object: GuiObject - The GuiObject arrow to animate
	@param PulseAt: GuiObject? - Optional GuiObject to pulse at (default: Object)
	@param PulsePos: UDim2? - Optional position for the pulse effect
	@returns function - A cleanup function that stops the arrow animation
]]
module.PointArrow = function(Object: GuiObject, PulseAt: GuiObject, PulsePos: UDim2)
	local scaler = Object:FindFirstChildOfClass("UIScale")

	local cancelThread = Threads.newThread(function()
		Object.Visible = true

		while task.wait() do
			scaler.Scale = 1.5

			local tween = TweenService:Create(scaler, TweenInfo.new(0.6, Enum.EasingStyle.Back), {
				Scale = 0.75,
			})

			tween:Play()

			tween.Completed:Wait()

			module.Pulse(PulseAt or Object, PulsePos)

			task.wait(0.1)
		end
	end)

	return function()
		Object.Visible = false
		cancelThread()
	end
end

--[[
	================================================================================
	COLOR EFFECT FUNCTIONS
	================================================================================
]]

--[[
	Creates a rainbow color effect callback function.
	Continuously generates color values based on time and multipliers.
	
	@param Multipliers: {number} | number - Table of multiplier values or a single multiplier number
	@param _fn: ({number}) -> () - Callback function that receives color values array
	@returns function - A cleanup function that stops the rainbow effect
]]
module.Rainbow = function(Multipliers:{number}|number, _fn:(a0: { number })->())
	if typeof(Multipliers) ~= "table" then
		Multipliers = { Multipliers }
	end

	local connect = RunService.RenderStepped:Connect(function(deltaTime: number)
		local colors = {}

		for _, t in Multipliers do
			table.insert(colors, tick() % t / t)
		end

		_fn(colors)
	end)

	return function()
		connect:Disconnect()
	end
end

--[[
	Applies a rainbow color effect to a TextLabel.
	The text color continuously cycles through rainbow colors.
	Automatically cleans up when the label is destroyed.
	
	@param label: TextLabel - The TextLabel to apply the rainbow effect to
]]
module.RainbowText = function(label: TextLabel)
	local _janitor = Janitor.new()
	local effect = module.Rainbow(5, function(a0: { number })
		label.TextColor3 = Color3.fromHSV(a0[1], 1, 1)
	end)

	_janitor:Add(label.Destroying:Once(function()
		effect()
		_janitor:Destroy()
	end))
end

--[[
	================================================================================
	MODEL ANIMATION FUNCTIONS
	================================================================================
]]

--[[
	Creates a bouncing animation effect for a Model.
	The model bounces and shakes with decreasing intensity over time.
	Prevents multiple simultaneous animations on the same model.
	
	@param Model: Model - The Model to animate
	@param Duration: number - Duration of the animation in seconds
	@param Strength: number - Strength multiplier for the animation
	@param callback: (() -> ())? - Optional callback function to execute when animation completes
]]
module.Model = function(Model: Model, Duration: number, Strength: number, callback:()->())
	if module.Active[Model] then
		module.Active[Model].Started = os.clock()
		return
	else
		module.Active[Model] = {
			Started = os.clock(),
		}
	end

	local connect: RBXScriptConnection
	local InitCF: CFrame

	if Model and not Model:GetAttribute("InitCF") then
		if Model.PrimaryPart then
			Model:SetAttribute("InitCF", Model.PrimaryPart.CFrame)
		end
	end

	InitCF = Model:GetAttribute("InitCF") :: CFrame

	if not Model.PrimaryPart then
		return
	end

	connect = RunService.RenderStepped:Connect(function(deltaTime: number)
		local passed = math.clamp((os.clock() - module.Active[Model].Started) / Duration, 0, 1)
		local formula = (tick() * math.pi) * 10
		local sin, cos = math.sin(formula) * Strength, math.cos(formula) * Strength
		local lerpValue = 1 - passed

		Model.PrimaryPart.CFrame = InitCF:Lerp(
			InitCF * CFrame.new(0, sin / 10, 0) * CFrame.Angles(math.rad(cos), 0, math.rad(sin * 2)),
			lerpValue
		)

		if passed == 1 then
			connect:Disconnect()
			module.Active[Model] = nil
			if callback then
				callback()
			end
		end
	end)
end

--[[
	Creates a ripple effect animation on a GuiButton when triggered.
	The ripple expands from the mouse click position and fades out.
	The circle grows from the click point and automatically cleans itself up.
	
	@param Button: GuiButton - The button to apply the ripple effect to (must be a GuiButton type)
	@param RippleColor: Color3? - Optional color for the ripple circle (default: white Color3.fromRGB(255, 255, 255))
	@param TweenTime: number? - Duration in seconds for the ripple animation (default: 0.25)
]]
module.RippleEffect = function(Button: GuiButton, RippleColor: Color3?, TweenTime: number?)
	RippleColor = RippleColor or Color3.fromRGB(255, 255, 255)
	TweenTime = TweenTime or 0.25

	local x = Mouse.X
	local y = Mouse.Y

	Button.ClipsDescendants = true

	local circle = Instance.new("Frame")
	circle.Name = "RippleCircle"
	circle.BackgroundColor3 = RippleColor
	circle.BackgroundTransparency = 0.45
	circle.BorderSizePixel = 0
	circle.Size = UDim2.new(0, 0, 0, 0)

	local newX = x - Button.AbsolutePosition.X
	local newY = y - Button.AbsolutePosition.Y
	circle.Position = UDim2.new(0, newX, 0, newY)

	local corner = Instance.new("UICorner", circle)
	corner.CornerRadius = UDim.new(1, 0)

	circle.Parent = Button

	local size = math.max(Button.AbsoluteSize.X, Button.AbsoluteSize.Y) * 2.5

	local sizeTween =
		TweenService:Create(circle, TweenInfo.new(TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, size, 0, size),
			Position = UDim2.new(0, newX - size / 2, 0, newY - size / 2),
		})

	local fadeTween = TweenService:Create(circle, TweenInfo.new(TweenTime * 0.8, Enum.EasingStyle.Linear), {
		BackgroundTransparency = 1,
	})

	sizeTween:Play()
	fadeTween:Play()

	fadeTween.Completed:Once(function()
		circle:Destroy()
		fadeTween:Destroy()
	end)
end

--[[
	Creates an animated shine effect that sweeps across a GuiObject with stroke.
	The shine effect uses a gradient that moves from left to right in a continuous loop.
	
	@param GuiObject: GuiObject - The GuiObject to apply the shine effect to
	@param Color: Color3 | ColorSequence? - Optional color or color sequence for the shine gradient (default: uses existing gradient colors)
	@param TweenTime: number? - Duration in seconds for one complete shine cycle (default: 1)
	@returns {} - Some variables and cleanup
]]
module.ShineEffect = function(
	GuiObject: GuiObject,
	Color: Color3 | ColorSequence?,
	Rotation: number?,
	TweenTime: number?,
	DelayTime: number?
): { Tween: typeof(TweenService:Create()), CanvasGroup: CanvasGroup, Destroy: () -> () }
	assert(GuiObject, `GuiObject is nil`)

	local NewCanvas = script.ShineCanvasGroup:Clone()

	local HasCorner = GuiObject:FindFirstChildOfClass("UICorner")
	if HasCorner then
		HasCorner = HasCorner:Clone()
		HasCorner.Parent = NewCanvas
	end

	local Shine = NewCanvas.Shine
	local ShineGradient = Shine:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", Shine)

	local Stroke = NewCanvas:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", NewCanvas)
	local StrokeGradient = Stroke:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", Stroke)

	Stroke.Transparency = 0.45
	Stroke.Color = Color3.fromRGB(255, 255, 255)
	Stroke.Thickness = 2

	if Rotation then
		ShineGradient.Rotation = Rotation
		StrokeGradient.Rotation = Rotation
	end

	if Color then
		if typeof(Color) == "Color3" then
			ShineGradient.Color = ColorSequence.new(Color)
			StrokeGradient.Color = ColorSequence.new(Color)
		else
			ShineGradient.Color = Color
			StrokeGradient.Color = Color
		end
	end

	Shine.Position = UDim2.fromScale(-1, 0.5)
	DelayTime = DelayTime or 0
	local Info =
		TweenInfo.new(TweenTime or 1, Enum.EasingStyle.Circular, Enum.EasingDirection.In, -10, false, DelayTime)

	local Tween = TweenService:Create(Shine, Info, { Position = UDim2.fromScale(2, 0.5) })
	Tween:Play()

	NewCanvas.Visible = true
	NewCanvas.ZIndex = 999999999
	NewCanvas.Parent = GuiObject

	return {
		Tween = Tween,
		CanvasGroup = NewCanvas,

		Destroy = function()
			Tween:Destroy()
			NewCanvas:Destroy()
		end,
	}
end

--[[
	Creates an animated shine effect that sweeps across a GuiObject with NO stroke.
	The shine effect uses a gradient that moves from left to right in a continuous loop.
	
	@param GuiObject: GuiObject - The GuiObject to apply the shine effect to
	@param Color: Color3 | ColorSequence? - Optional color or color sequence for the shine gradient (default: uses existing gradient colors)
	@param TweenTime: number? - Duration in seconds for one complete shine cycle (default: 1)
	@returns {} - Some variables and cleanup
]]
module.ShineEffectNoStroke = function(
	GuiObject: GuiObject,
	Color: Color3 | ColorSequence?,
	Rotation: number?,
	TweenTime: number?,
	DelayTime: number?
): { Tween: typeof(TweenService:Create()), CanvasGroup: CanvasGroup, Destroy: (
	) -> () }
	assert(GuiObject, `GuiObject is nil`)

	local NewCanvas = script.ShineCanvasGroup:Clone()
	local HasCorner = GuiObject:FindFirstChildOfClass("UICorner")
	if HasCorner then
		HasCorner = HasCorner:Clone()
		HasCorner.Parent = NewCanvas
	end

	local Shine = NewCanvas.Shine
	local ShineGradient = Shine:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", Shine)

	if Rotation then
		ShineGradient.Rotation = Rotation
	end

	if Color then
		if typeof(Color) == "Color3" then
			ShineGradient.Color = ColorSequence.new(Color)
		else
			ShineGradient.Color = Color
		end
	end

	Shine.Position = UDim2.fromScale(-1, 0.5)
	DelayTime = DelayTime or 0
	local Info =
		TweenInfo.new(TweenTime or 1, Enum.EasingStyle.Circular, Enum.EasingDirection.In, -10, false, DelayTime)

	local Tween = TweenService:Create(Shine, Info, { Position = UDim2.fromScale(2, 0.5) })
	Tween:Play()

	NewCanvas.Visible = true
	NewCanvas.ZIndex = 999999999
	NewCanvas.Parent = GuiObject

	return {
		Tween = Tween,
		CanvasGroup = NewCanvas,

		Destroy = function()
			Tween:Destroy()
			NewCanvas:Destroy()
		end,
	}
end

return module
