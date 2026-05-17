--[[

░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

--< Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--< Modules
local FastSignal = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("FastSignal"))
local TweenByAlpha = require(script.Parent:WaitForChild("TweenByAlpha"))

--< Variables
local DebrisFolder = workspace:WaitForChild("Debris")

--< Constants
local DEFAULT_RANGE = 15
local RNG = Random.new()
local INFO = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--< Util Functions
local function BezierQuadratic(t: number, P0: Vector3, P1: Vector3, P2: Vector3): Vector3
	local u = 1 - t
	return u * u * P0 + 2 * u * t * P1 + t * t * P2
end

local module = {}
module.__index = module

--< Constructor

function module.new(OrbTemplate: BasePart, TagName: string?)
	local self = setmetatable({}, module)

	--< Private
	self._OrbTemplate = OrbTemplate
	self._TagName = TagName or "OrbPart"
	self._DropConnections = {}
	self._DropWithTargetConnections = {}
	self._DropObjects = {}
	self._DropWithTargetObjects = {}

	--< Public
	self.OnCollect = FastSignal.new()
	return self
end

--< Methods

function module:Drop(
	Amount: number?,
	Cframe: CFrame,
	LifeTime: number?,
	Range: number?,
	DropDelay: number?,
	Force: number?,
	XZIntRange: { number }?,
	YIntRange: { number }?
)
	assert(Cframe, `Cframe is NIL`)

	Range = Range or DEFAULT_RANGE
	LifeTime = LifeTime or 60

	local CreatedObjects: { BasePart } = {}

	for i = 1, Amount do
		task.spawn(function()
			local ClonedObject: BasePart = self._OrbTemplate:Clone()
			table.insert(CreatedObjects, ClonedObject)

			ClonedObject.Name = self._TagName
			ClonedObject.CFrame = Cframe
			ClonedObject.CanCollide = false

			local Attachment = Instance.new("Attachment", ClonedObject)

			local RandomX: number
			local RandomY: number
			local RandomZ: number

			if YIntRange then
				RandomY = RNG:NextInteger(YIntRange[1], YIntRange[2])
			else
				RandomY = RNG:NextInteger(35, 45)
			end

			if XZIntRange then
				RandomX = RNG:NextInteger(XZIntRange[1], XZIntRange[2])
				RandomZ = RNG:NextInteger(XZIntRange[1], XZIntRange[2])
			else
				RandomX = RNG:NextInteger(-20, 20)
				RandomZ = RNG:NextInteger(-20, 20)
			end

			local LinearVelocity = Instance.new("LinearVelocity", ClonedObject)
			LinearVelocity.Attachment0 = Attachment
			LinearVelocity.MaxForce = Force or 550
			LinearVelocity.VectorVelocity = Vector3.new(RandomX, RandomY, RandomZ)

			ClonedObject.Parent = DebrisFolder

			task.wait(0.2)

			Attachment:Destroy()
			LinearVelocity:Destroy()
			ClonedObject.CanCollide = true
			
		end)

		task.wait(DropDelay)
	end
	task.wait(0.1)
	

	local Connection: RBXScriptConnection

	task.delay(LifeTime, function()
		if Connection then
			Connection:Disconnect()
			Connection = nil
		end

		if CreatedObjects then
			for _, object in pairs(CreatedObjects) do
				object:Destroy()
			end
			CreatedObjects = nil
		end
	end)

	table.insert(self._DropObjects, CreatedObjects)

	local RangeSquared = Range * Range

	Connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		if not CreatedObjects or #CreatedObjects == 0 then
			Connection:Disconnect()
			Connection = nil
			CreatedObjects = nil
			return
		end

		local players = Players:GetPlayers()
		local playerCount = #players
		if playerCount == 0 then
			return
		end

		for i = #CreatedObjects, 1, -1 do
			local object = CreatedObjects[i]
			if not object or not object.Parent then
				table.remove(CreatedObjects, i)
				continue
			end

			local objectPos = object.Position

			for j = 1, playerCount do
				local player = players[j]
				local character = player.Character
				if not character then
					continue
				end

				local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
				if not humanoidRootPart then
					continue
				end

				local targetPos = humanoidRootPart.Position
				local delta = objectPos - targetPos
				local distanceSquared = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z

				if distanceSquared <= RangeSquared then
					table.remove(CreatedObjects, i)
					object.CanCollide = false

					local startPos = objectPos
					local initialSize = object.Size
					local previousPos = startPos
					local characterRef = character

					TweenByAlpha(INFO, function(Alpha: number, TotalProgress: number)
						local currentHumanoidRootPart = characterRef
							and characterRef:FindFirstChild("HumanoidRootPart") :: BasePart

						if not currentHumanoidRootPart then
							return
						end

						local currentEndPos = currentHumanoidRootPart.Position

						if Alpha >= 1 then
							object.CFrame = CFrame.lookAt(currentEndPos, currentEndPos + Vector3.new(0, 0, -1))
							object.Size = initialSize * 0.8
							return
						end

						local endDelta = startPos - currentEndPos
						local currentDistanceSquared = endDelta.X * endDelta.X
							+ endDelta.Y * endDelta.Y
							+ endDelta.Z * endDelta.Z
						local currentDistance = math.sqrt(currentDistanceSquared)
						local midPoint = (startPos + currentEndPos) * 0.5
						local heightOffset = math.max(8, currentDistance * 0.4)
						local controlPoint = midPoint + Vector3.new(0, heightOffset, 0)

						local curvePos = BezierQuadratic(Alpha, startPos, controlPoint, currentEndPos)

						local moveDelta = curvePos - previousPos
						local moveDeltaSquared = moveDelta.X * moveDelta.X
							+ moveDelta.Y * moveDelta.Y
							+ moveDelta.Z * moveDelta.Z
						local moveDirection = if moveDeltaSquared > 0.000001
							then moveDelta.Unit
							else (currentEndPos - startPos).Unit

						object.CFrame = CFrame.lookAt(curvePos, curvePos + moveDirection)

						local scale = 1 - (Alpha * 0.2)
						object.Size = initialSize * scale

						previousPos = curvePos
					end, function(PlaybackState: Enum.PlaybackState)
						if PlaybackState == Enum.PlaybackState.Completed then
							local finalHumanoidRootPart = characterRef
								and characterRef:FindFirstChild("HumanoidRootPart") :: BasePart

							if finalHumanoidRootPart then
								object.CFrame = CFrame.lookAt(
									finalHumanoidRootPart.Position,
									finalHumanoidRootPart.Position + Vector3.new(0, 0, -1)
								)
							end

							object:Destroy()
							self.OnCollect:Fire(player)
						elseif PlaybackState == Enum.PlaybackState.Cancelled then
							object:Destroy()
						end
					end)

					break
				end
			end
		end
	end)

	table.insert(self._DropConnections, Connection)
end

function module:DropWithTarget(
	Target: { Player } | Player,
	AutoCollect: boolean?,
	Amount: number?,
	Cframe: CFrame,
	LifeTime: number?,
	Range: number?,
	DropDelay: number?,
	Force: number?,
	XZIntRange: { number }?,
	YIntRange: { number }?
)
	assert(Cframe, `Cframe is NIL`)

	Range = Range or DEFAULT_RANGE
	LifeTime = LifeTime or 60
	AutoCollect = AutoCollect or false

	local targetPlayers: { Player } = if typeof(Target) == "Instance" and Target:IsA("Player")
		then { Target }
		else Target

	local isSinglePlayer = typeof(Target) == "Instance" and Target:IsA("Player")
	local CreatedObjects: { BasePart } = {}

	for i = 1, Amount do
		task.spawn(function()
			local ClonedObject: BasePart = self._OrbTemplate:Clone()
			table.insert(CreatedObjects, ClonedObject)

			ClonedObject.Name = self._TagName
			ClonedObject.CFrame = Cframe
			ClonedObject.CanCollide = false

			local Attachment = Instance.new("Attachment", ClonedObject)

			local RandomX: number
			local RandomY: number
			local RandomZ: number

			if YIntRange then
				RandomY = RNG:NextInteger(YIntRange[1], YIntRange[2])
			else
				RandomY = RNG:NextInteger(35, 45)
			end

			if XZIntRange then
				RandomX = RNG:NextInteger(XZIntRange[1], XZIntRange[2])
				RandomZ = RNG:NextInteger(XZIntRange[1], XZIntRange[2])
			else
				RandomX = RNG:NextInteger(-20, 20)
				RandomZ = RNG:NextInteger(-20, 20)
			end

			local LinearVelocity = Instance.new("LinearVelocity", ClonedObject)
			LinearVelocity.Attachment0 = Attachment
			LinearVelocity.MaxForce = Force or 550
			LinearVelocity.VectorVelocity = Vector3.new(RandomX, RandomY, RandomZ)

			ClonedObject.Parent = DebrisFolder

			task.wait(0.2)

			Attachment:Destroy()
			LinearVelocity:Destroy()
			ClonedObject.CanCollide = true
			
		end)

		task.wait(DropDelay)
	end
	task.wait(0.1)

	local Connection: RBXScriptConnection

	local function collectAllOrbs(targetPlayer: Player)
		if not targetPlayer or not targetPlayer.Character then
			return
		end

		local humanoidRootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart
		if not humanoidRootPart then
			return
		end

		if not CreatedObjects or #CreatedObjects <= 0 then return end
		for i = #CreatedObjects, 1, -1 do
			local object = CreatedObjects[i]
			if object and object.Parent then
				table.remove(CreatedObjects, i)
				object.CanCollide = false

				local startPos = object.Position
				local initialSize = object.Size
				local previousPos = startPos
				local characterRef = targetPlayer.Character

				TweenByAlpha(INFO, function(Alpha: number, TotalProgress: number)
					local currentHumanoidRootPart = characterRef
						and characterRef:FindFirstChild("HumanoidRootPart") :: BasePart

					if not currentHumanoidRootPart then
						return
					end

					local currentEndPos = currentHumanoidRootPart.Position

					if Alpha >= 1 then
						object.CFrame = CFrame.lookAt(currentEndPos, currentEndPos + Vector3.new(0, 0, -1))
						object.Size = initialSize * 0.8
						return
					end

					local endDelta = startPos - currentEndPos
					local currentDistanceSquared = endDelta.X * endDelta.X
						+ endDelta.Y * endDelta.Y
						+ endDelta.Z * endDelta.Z
					local currentDistance = math.sqrt(currentDistanceSquared)
					local midPoint = (startPos + currentEndPos) * 0.5
					local heightOffset = math.max(8, currentDistance * 0.4)
					local controlPoint = midPoint + Vector3.new(0, heightOffset, 0)

					local curvePos = BezierQuadratic(Alpha, startPos, controlPoint, currentEndPos)

					local moveDelta = curvePos - previousPos
					local moveDeltaSquared = moveDelta.X * moveDelta.X
						+ moveDelta.Y * moveDelta.Y
						+ moveDelta.Z * moveDelta.Z
					local moveDirection = if moveDeltaSquared > 0.000001
						then moveDelta.Unit
						else (currentEndPos - startPos).Unit

					object.CFrame = CFrame.lookAt(curvePos, curvePos + moveDirection)

					local scale = 1 - (Alpha * 0.2)
					object.Size = initialSize * scale

					previousPos = curvePos
				end, function(PlaybackState: Enum.PlaybackState)
					if PlaybackState == Enum.PlaybackState.Completed then
						local finalHumanoidRootPart = characterRef
							and characterRef:FindFirstChild("HumanoidRootPart") :: BasePart

						if finalHumanoidRootPart then
							object.CFrame = CFrame.lookAt(
								finalHumanoidRootPart.Position,
								finalHumanoidRootPart.Position + Vector3.new(0, 0, -1)
							)
						end

						object:Destroy()
						self.OnCollect:Fire(targetPlayer)
					elseif PlaybackState == Enum.PlaybackState.Cancelled then
						object:Destroy()
					end
				end)
			end
		end
	end

	task.delay(LifeTime, function()
		if AutoCollect and isSinglePlayer then
			collectAllOrbs(Target :: Player)
		else
			if Connection then
				Connection:Disconnect()
				Connection = nil
			end

			if CreatedObjects then
				for _, object in pairs(CreatedObjects) do
					object:Destroy()
				end
				CreatedObjects = nil
			end
		end
	end)

	table.insert(self._DropWithTargetObjects, CreatedObjects)

	local RangeSquared = Range * Range

	Connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		if not CreatedObjects or #CreatedObjects == 0 then
			Connection:Disconnect()
			Connection = nil
			CreatedObjects = nil
			return
		end

		local targetPlayerCount = #targetPlayers
		if targetPlayerCount == 0 then
			return
		end

		for i = #CreatedObjects, 1, -1 do
			local object = CreatedObjects[i]
			if not object or not object.Parent then
				table.remove(CreatedObjects, i)
				continue
			end

			local objectPos = object.Position

			for j = 1, targetPlayerCount do
				local player = targetPlayers[j]
				local character = player.Character
				if not character then
					continue
				end

				local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
				if not humanoidRootPart then
					continue
				end

				local targetPos = humanoidRootPart.Position
				local delta = objectPos - targetPos
				local distanceSquared = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z

				if distanceSquared <= RangeSquared then
					table.remove(CreatedObjects, i)
					object.CanCollide = false

					local startPos = objectPos
					local initialSize = object.Size
					local previousPos = startPos
					local characterRef = character

					TweenByAlpha(INFO, function(Alpha: number, TotalProgress: number)
						local currentHumanoidRootPart = characterRef
							and characterRef:FindFirstChild("HumanoidRootPart") :: BasePart

						if not currentHumanoidRootPart then
							return
						end

						local currentEndPos = currentHumanoidRootPart.Position

						if Alpha >= 1 then
							object.CFrame = CFrame.lookAt(currentEndPos, currentEndPos + Vector3.new(0, 0, -1))
							object.Size = initialSize * 0.8
							return
						end

						local endDelta = startPos - currentEndPos
						local currentDistanceSquared = endDelta.X * endDelta.X
							+ endDelta.Y * endDelta.Y
							+ endDelta.Z * endDelta.Z
						local currentDistance = math.sqrt(currentDistanceSquared)
						local midPoint = (startPos + currentEndPos) * 0.5
						local heightOffset = math.max(8, currentDistance * 0.4)
						local controlPoint = midPoint + Vector3.new(0, heightOffset, 0)

						local curvePos = BezierQuadratic(Alpha, startPos, controlPoint, currentEndPos)

						local moveDelta = curvePos - previousPos
						local moveDeltaSquared = moveDelta.X * moveDelta.X
							+ moveDelta.Y * moveDelta.Y
							+ moveDelta.Z * moveDelta.Z
						local moveDirection = if moveDeltaSquared > 0.000001
							then moveDelta.Unit
							else (currentEndPos - startPos).Unit

						object.CFrame = CFrame.lookAt(curvePos, curvePos + moveDirection)

						local scale = 1 - (Alpha * 0.2)
						object.Size = initialSize * scale

						previousPos = curvePos
					end, function(PlaybackState: Enum.PlaybackState)
						if PlaybackState == Enum.PlaybackState.Completed then
							local finalHumanoidRootPart = characterRef
								and characterRef:FindFirstChild("HumanoidRootPart") :: BasePart

							if finalHumanoidRootPart then
								object.CFrame = CFrame.lookAt(
									finalHumanoidRootPart.Position,
									finalHumanoidRootPart.Position + Vector3.new(0, 0, -1)
								)
							end

							object:Destroy()
							self.OnCollect:Fire(player)
						elseif PlaybackState == Enum.PlaybackState.Cancelled then
							object:Destroy()
						end
					end)

					break
				end
			end
		end
	end)

	table.insert(self._DropWithTargetConnections, Connection)
end

function module:Destroy()
	for _, connection in pairs(self._DropConnections) do
		if connection then
			connection:Disconnect()
		end
	end

	for _, connection in pairs(self._DropWithTargetConnections) do
		if connection then
			connection:Disconnect()
		end
	end

	for _, objects in pairs(self._DropObjects) do
		if objects then
			for _, object in pairs(objects) do
				if object and object.Parent then
					object:Destroy()
				end
			end
		end
	end

	for _, objects in pairs(self._DropWithTargetObjects) do
		if objects then
			for _, object in pairs(objects) do
				if object and object.Parent then
					object:Destroy()
				end
			end
		end
	end

	if self.OnCollect and typeof(self.OnCollect) == "table" and self.OnCollect.Destroy then
		self.OnCollect:Destroy()
	end

	self._DropConnections = {}
	self._DropWithTargetConnections = {}
	self._DropObjects = {}
	self._DropWithTargetObjects = {}
end

return module
