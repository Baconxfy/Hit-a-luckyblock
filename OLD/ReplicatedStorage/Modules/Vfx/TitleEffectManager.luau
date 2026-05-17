local module = {}

function module.HorizontalEffect(gradient:UIGradient, step:number, limit:number)
	
	limit = limit or 1
	step = step or 0.01

	local Yval = gradient.Offset.Y
	local Xval = gradient.Offset.X

	if Xval >= limit then
		Xval = -limit
	elseif Xval <= -limit then
		Xval = limit
	end

	Xval += step

	gradient.Offset = Vector2.new(Xval, Yval)

	
end

function module.VerticalEffect(gradient:UIGradient, step:number, limit:number)
	limit = limit or 1
	step = step or 0.01
	
	local Yval = gradient.Offset.Y
	local Xval = gradient.Offset.X

	if Yval >= limit then
		Yval = -limit
	elseif Yval <= -limit then
		Yval = limit
	end


	Yval += step

	gradient.Offset = Vector2.new(Xval, Yval)
	
end

function module.DiagonalEffect(gradient:UIGradient, step:number, limit:number)
	limit = limit or 1
	step = step or 0.01
	
	local Yval = gradient.Offset.Y
	local Xval = gradient.Offset.X

	if Yval >= limit then
		Yval = -limit
	elseif Yval <= -limit then
		Yval = limit
	end

	if Xval >= limit then
		Xval = -limit
	elseif Xval <= -limit then
		Xval = limit
	end

	Xval += step
	Yval += step

	gradient.Offset = Vector2.new(Xval, Yval)

end

return module
