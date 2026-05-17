-- Wiggle animation (from RichTextPlus)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

return {
	Letterwise = true,
	Attributes = { "amplitude", "speed", "time" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Connections = {}
		local amplitude = tonumber(Attributes.amplitude) or 5
		local speed = tonumber(Attributes.speed) or 3
		local time = tonumber(Attributes.time) or 2

		local initialPosition = Label.Position
		local elapsed = 0

		table.insert(
			Connections,
			RunService.RenderStepped:Connect(function()
				elapsed += RunService.RenderStepped:Wait()
				if elapsed > time then
					Label.Position = initialPosition
					return
				end

				local alpha = elapsed / time
				local currentAmplitude = amplitude * (1 - alpha)
				local offset = math.sin(elapsed * math.pi * 2 * speed) * currentAmplitude / 2

				Label.Position = initialPosition + UDim2.new(0, 0, 0, offset)
			end)
		)

		return Connections
	end,
}
