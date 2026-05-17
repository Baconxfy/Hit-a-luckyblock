-- Swing animation (from RichTextPlus)
local RunService = game:GetService("RunService")

return {
	Letterwise = true,
	Attributes = { "amplitude", "speed", "time" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Connections = {}
		local amplitude = tonumber(Attributes.amplitude) or 30
		local speed = tonumber(Attributes.speed) or 2
		local time = tonumber(Attributes.time) or 2

		local elapsed = 0

		table.insert(
			Connections,
			RunService.RenderStepped:Connect(function()
				elapsed += RunService.RenderStepped:Wait()
				if elapsed > time then
					Label.Rotation = 0
					return
				end

				local alpha = elapsed / time
				local currentAmplitude = amplitude * (1 - alpha)
				Label.Rotation = math.sin(elapsed * math.pi * 2 * speed) * currentAmplitude
			end)
		)

		return Connections
	end,
}
