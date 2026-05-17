-- Spin animation (from RichTextPlus)
local RunService = game:GetService("RunService")

return {
	Letterwise = true,
	Attributes = { "speed", "time" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Connections = {}
		local speed = tonumber(Attributes.speed) or 1
		local time = tonumber(Attributes.time) or 1.5

		local initialPosition = Label.Position
		local initialAnchorPoint = Label.AnchorPoint
		local initialSize = Label.AbsoluteSize

		Label.AnchorPoint = Vector2.new(0.5, 0.5)
		Label.Position = initialPosition + UDim2.new(0, initialSize.X / 2, 0, initialSize.Y / 2)

		local elapsed = 0

		table.insert(
			Connections,
			RunService.RenderStepped:Connect(function()
				elapsed += RunService.RenderStepped:Wait()
				if elapsed > time then
					Label.Rotation = 0
					Label.AnchorPoint = initialAnchorPoint
					Label.Position = initialPosition
					return
				end

				Label.Rotation = (elapsed * speed * 360) % 360
			end)
		)

		return Connections
	end,
}
