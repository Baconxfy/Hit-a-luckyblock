local FormatUtil = {}

local SUFFIXES = {
	{ 1e15, "Qa" },
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
	{ 1e3, "K" },
}

local function cleanDecimalString(text: string): string
	text = text:gsub("%.0+$", "")
	text = text:gsub("(%..-)0+$", "%1")
	return text
end

function FormatUtil.FormatNumberWithCommas(value: number | string): string
	local numberValue = tonumber(value) or 0
	local sign = ""

	if numberValue < 0 then
		sign = "-"
		numberValue = math.abs(numberValue)
	end

	local integerPart = math.floor(numberValue)
	local decimalPart = numberValue - integerPart

	local text = tostring(integerPart)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()

	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end

	if decimalPart > 0 then
		local decimalText = tostring(math.floor(decimalPart * 100 + 0.5) / 100):match("%.(%d+)$")

		if decimalText then
			formatted ..= "." .. decimalText
		end
	end

	return sign .. formatted
end

function FormatUtil.FormatAbbreviated(value: number | string, decimals: number?): string
	local numberValue = tonumber(value) or 0
	local decimalPlaces = decimals or 1
	local sign = ""

	if numberValue < 0 then
		sign = "-"
		numberValue = math.abs(numberValue)
	end

	for _, suffixData in ipairs(SUFFIXES) do
		local amount = suffixData[1]
		local suffix = suffixData[2]

		if numberValue >= amount then
			local rounded = math.floor((numberValue / amount) * (10 ^ decimalPlaces) + 0.5) / (10 ^ decimalPlaces)
			return sign .. cleanDecimalString(tostring(rounded)) .. suffix
		end
	end

	return sign .. FormatUtil.FormatNumberWithCommas(numberValue)
end

function FormatUtil.FormatCash(value: number | string): string
	return "$" .. FormatUtil.FormatNumberWithCommas(value)
end

function FormatUtil.FormatMultiplier(value: number | string): string
	local numberValue = tonumber(value) or 0

	if numberValue % 1 == 0 then
		return "x" .. FormatUtil.FormatNumberWithCommas(numberValue)
	end

	return "x" .. cleanDecimalString(tostring(math.floor(numberValue * 100 + 0.5) / 100))
end

function FormatUtil.FormatTime(seconds: number): string
	seconds = math.max(math.floor(seconds or 0), 0)

	local minutes = math.floor(seconds / 60)
	local remainingSeconds = seconds % 60

	return string.format("%d:%02d", minutes, remainingSeconds)
end

return FormatUtil