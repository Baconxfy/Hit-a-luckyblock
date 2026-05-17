--[[

░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

---Utility module for formatting numbers and time values.
---Provides comprehensive formatting functions for numbers (with commas, abbreviations, smart formatting)
---and time values (various formats including relative time, compact, verbose, and standard time formats).
---All functions are optimized for performance with O(n) complexity.

local FormatUtil = {}

---Constants
local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3600
local SECONDS_PER_DAY = 86400

local INVERSE_SECONDS_PER_MINUTE = 1 / SECONDS_PER_MINUTE
local INVERSE_SECONDS_PER_HOUR = 1 / SECONDS_PER_HOUR
local INVERSE_SECONDS_PER_DAY = 1 / SECONDS_PER_DAY

local NUMBER_ABBREVIATIONS = {
	{ Value = 1e33, Suffix = "Dc" },
	{ Value = 1e30, Suffix = "No" },
	{ Value = 1e27, Suffix = "Oc" },
	{ Value = 1e24, Suffix = "Sp" },
	{ Value = 1e21, Suffix = "Sx" },
	{ Value = 1e18, Suffix = "Qi" },
	{ Value = 1e15, Suffix = "Qa" },
	{ Value = 1e12, Suffix = "T" },
	{ Value = 1e9, Suffix = "B" },
	{ Value = 1e6, Suffix = "M" },
	{ Value = 1e3, Suffix = "k" },
}

local DYNAMIC_SUFFIXES = {
	"a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"g",
	"h",
	"i",
	"j",
	"k",
	"l",
	"m",
	"n",
	"o",
	"p",
	"q",
	"r",
	"s",
	"t",
	"u",
	"v",
	"w",
	"x",
	"y",
	"z",
}

local TIME_UNITS = {
	{ Value = SECONDS_PER_DAY, Singular = "day", Plural = "days", Short = "d" },
	{ Value = SECONDS_PER_HOUR, Singular = "hour", Plural = "hours", Short = "h" },
	{ Value = SECONDS_PER_MINUTE, Singular = "minute", Plural = "minutes", Short = "m" },
	{ Value = 1, Singular = "second", Plural = "seconds", Short = "s" },
}

---Adds thousands separators (commas) to a numeric string.
---Efficiently formats strings by grouping digits into sets of three from right to left.
---Example: "1234567" becomes "1,234,567"
---@param NumString string The numeric string to format (must contain only digits, no decimal point)
---@return string The formatted string with comma separators every three digits
local function AddCommas(NumString: string): string
	local Length = #NumString
	if Length <= 3 then
		return NumString
	end

	local Parts = {}
	local Start = 1
	local Remainder = Length % 3

	if Remainder > 0 then
		table.insert(Parts, NumString:sub(1, Remainder))
		Start = Remainder + 1
	end

	for I = Start, Length, 3 do
		table.insert(Parts, NumString:sub(I, I + 2))
	end

	return table.concat(Parts, ",")
end

---Rounds a number to a specified number of decimal places using standard rounding rules.
---Uses half-up rounding (0.5 rounds up).
---Example: RoundToDecimals(3.14159, 2) returns 3.14, RoundToDecimals(3.145, 2) returns 3.15
---@param Number number The number to round
---@param Decimals number The number of decimal places to round to (must be non-negative)
---@return number The rounded number with the specified decimal precision
local function RoundToDecimals(Number: number, Decimals: number): number
	local Multiplier = 10 ^ Decimals
	return math.floor(Number * Multiplier + 0.5) / Multiplier
end

---Formats a number with thousands separators (commas) for improved readability.
---Adds commas every three digits and optionally includes decimal places.
---Example: FormatNumberWithCommas(1234567.89, 2) returns "1,234,567.89"
---Example: FormatNumberWithCommas(-5000) returns "-5,000"
---@param Number number The number to format (can be positive, negative, or zero)
---@param Decimals number? Optional number of decimal places to display (default: 0, no decimals)
---@return string The formatted number string with comma separators and optional decimal places
function FormatUtil.FormatNumberWithCommas(Number: number, Decimals: number?): string
	Decimals = Decimals or 0
	local Rounded = RoundToDecimals(Number, Decimals)
	local IsNegative = Rounded < 0
	local AbsRounded = math.abs(Rounded)
	local NumString = tostring(AbsRounded)
	-- Plain tostring() can use scientific notation for large magnitudes; AddCommas expects digit text.
	if NumString:find("[eE]") then
		if Decimals == 0 then
			NumString = string.format("%.0f", AbsRounded)
		else
			NumString = string.format("%." .. Decimals .. "f", AbsRounded)
		end
	end

	if Decimals == 0 then
		return (IsNegative and "-" or "") .. AddCommas(NumString)
	end

	local DotPos = NumString:find("%.")
	if DotPos then
		local IntegerPart = NumString:sub(1, DotPos - 1)
		local DecimalPart = NumString:sub(DotPos + 1)
		local DecLen = #DecimalPart

		if DecLen > Decimals then
			DecimalPart = DecimalPart:sub(1, Decimals)
		elseif DecLen < Decimals then
			DecimalPart = DecimalPart .. ("0"):rep(Decimals - DecLen)
		end

		return (IsNegative and "-" or "") .. AddCommas(IntegerPart) .. "." .. DecimalPart
	else
		return (IsNegative and "-" or "") .. AddCommas(NumString) .. "." .. ("0"):rep(Decimals)
	end
end

---Generates a dynamic abbreviation suffix for numbers beyond standard abbreviations (above 1e33).
---Creates unique suffixes by combining letters from the alphabet in a systematic pattern.
---This allows formatting of arbitrarily large numbers without limit.
---Example: GenerateDynamicSuffix(39) might return "a" for 1e39, "b" for 1e42, etc.
---@param Power number The power of 10 (e.g., 36 for 1e36, 39 for 1e39)
---@return string The generated suffix string, or empty string if power is below threshold
local function GenerateDynamicSuffix(Power: number): string
	local BasePower = 36
	local Level = math.floor((Power - BasePower) / 3)

	if Level < 0 then
		return ""
	end

	local SuffixParts = {}
	local RemainingLevel = Level
	local SuffixCount = #DYNAMIC_SUFFIXES

	while RemainingLevel >= 0 do
		local Index = (RemainingLevel % SuffixCount) + 1
		table.insert(SuffixParts, 1, DYNAMIC_SUFFIXES[Index])
		RemainingLevel = math.floor(RemainingLevel / SuffixCount) - 1
	end

	return table.concat(SuffixParts)
end

---Formats a number using compact abbreviations (k, M, B, T, etc.) for large values.
---Automatically selects the appropriate abbreviation based on the number's magnitude.
---Supports numbers of any size, including those beyond standard abbreviations using dynamic suffixes.
---Example: FormatNumberWithAbbreviation(1500) returns "1.5k"
---Example: FormatNumberWithAbbreviation(2500000) returns "2.5M"
---Example: FormatNumberWithAbbreviation(1234567890) returns "1.2B"
---@param Number number The number to format (can be positive, negative, or zero)
---@param Decimals number? Optional number of decimal places for the abbreviated value (default: 1)
---@return string The formatted number string with abbreviation suffix (e.g., "1.5k", "2.3M", "1.2B")
function FormatUtil.FormatNumberWithAbbreviation(Number: number, Decimals: number?): string
	Decimals = Decimals or 1

	if Number == 0 then
		return "0"
	end

	local IsNegative = Number < 0
	local AbsNumber = math.abs(Number)

	local function FormatAbbreviatedMantissa(Rounded: number, Suffix: string): string
		local Formatted = tostring(Rounded)
		-- Only strip trailing zeros after a decimal point; "%.?0+$" on "100" would wrongly become "1".
		if Decimals > 0 and Formatted:find("%.") then
			Formatted = Formatted:gsub("%.?0+$", "")
		end
		return (IsNegative and "-" or "") .. Formatted .. Suffix
	end

	if AbsNumber < 1000 then
		local Rounded = RoundToDecimals(AbsNumber, Decimals)
		return FormatAbbreviatedMantissa(Rounded, "")
	end

	-- Use groups of 10³ so the mantissa is in [1, 1000). Pick suffix from the fixed list or dynamic.
	local function SuffixForThousandsPower(ThousandsPower: number): string
		for _, Abbrev in ipairs(NUMBER_ABBREVIATIONS) do
			local AbbPower = math.floor(math.log10(Abbrev.Value) + 0.5)
			if AbbPower == ThousandsPower then
				return Abbrev.Suffix
			end
		end
		return GenerateDynamicSuffix(ThousandsPower)
	end

	local Characteristic = math.floor(math.log10(AbsNumber))
	local ThousandsPower = math.floor(Characteristic / 3) * 3

	while true do
		local Divisor = 10 ^ ThousandsPower
		local Value = AbsNumber / Divisor
		local Rounded = RoundToDecimals(Value, Decimals)
		if Rounded < 1000 then
			return FormatAbbreviatedMantissa(Rounded, SuffixForThousandsPower(ThousandsPower))
		end
		ThousandsPower += 3
	end
end

---Intelligently formats numbers by automatically choosing between comma and abbreviation formatting.
---Uses comma formatting for smaller numbers (below threshold) and abbreviation formatting for larger numbers.
---This provides the best readability for numbers of any size.
---Example: FormatNumberSmart(500000) returns "500,000" (comma format)
---Example: FormatNumberSmart(5000000) returns "5.0M" (abbreviation format)
---@param Number number The number to format (can be positive, negative, or zero)
---@param Threshold number? Optional threshold value for switching to abbreviation format (default: 1000000)
---@param AbbreviationDecimals number? Optional decimal places when using abbreviation format (default: 1)
---@param CommaDecimals number? Optional decimal places when using comma format (default: 0)
---@return string The formatted number string using the most appropriate format based on the threshold
function FormatUtil.FormatNumberSmart(
	Number: number,
	Threshold: number?,
	AbbreviationDecimals: number?,
	CommaDecimals: number?
): string
	Threshold = Threshold or 1000000
	AbbreviationDecimals = AbbreviationDecimals or 1
	CommaDecimals = CommaDecimals or 0

	if math.abs(Number) >= Threshold then
		return FormatUtil.FormatNumberWithAbbreviation(Number, AbbreviationDecimals)
	else
		return FormatUtil.FormatNumberWithCommas(Number, CommaDecimals)
	end
end

---Formats a duration in minutes and seconds format (MM:SS).
---Useful for displaying short to medium durations like countdown timers or elapsed time.
---Example: FormatTimeMMSS(125) returns "2:05" (2 minutes, 5 seconds)
---Example: FormatTimeMMSS(65, false) returns "1:5" (without leading zero on seconds)
---@param Seconds number The duration in seconds (will be floored to nearest integer)
---@param ShowLeadingZeros boolean? Optional flag to show leading zeros on seconds (default: true)
---@return string The formatted time string in MM:SS format (e.g., "5:30", "125:45")
function FormatUtil.FormatTimeMMSS(Seconds: number, ShowLeadingZeros: boolean?): string
	local TotalSeconds = math.floor(Seconds)
	local Minutes = math.floor(TotalSeconds * INVERSE_SECONDS_PER_MINUTE)
	local Secs = TotalSeconds % SECONDS_PER_MINUTE

	if ShowLeadingZeros ~= false then
		return string.format("%d:%02d", Minutes, Secs)
	else
		return string.format("%d:%d", Minutes, Secs)
	end
end

---Formats a duration in hours, minutes, and seconds format (HH:MM:SS).
---Most comprehensive standard time format, suitable for any duration up to 24 hours.
---Example: FormatTimeHHMMSS(3665) returns "1:01:05" (1 hour, 1 minute, 5 seconds)
---Example: FormatTimeHHMMSS(125) returns "0:02:05" (2 minutes, 5 seconds)
---@param Seconds number The duration in seconds (will be floored to nearest integer)
---@param ShowLeadingZeros boolean? Optional flag to show leading zeros on minutes and seconds (default: true)
---@return string The formatted time string in HH:MM:SS format (e.g., "1:30:45", "0:05:30")
function FormatUtil.FormatTimeHHMMSS(Seconds: number, ShowLeadingZeros: boolean?): string
	local TotalSeconds = math.floor(Seconds)
	local Hours = math.floor(TotalSeconds * INVERSE_SECONDS_PER_HOUR)
	local Remainder = TotalSeconds % SECONDS_PER_HOUR
	local Minutes = math.floor(Remainder * INVERSE_SECONDS_PER_MINUTE)
	local Secs = Remainder % SECONDS_PER_MINUTE

	if ShowLeadingZeros ~= false then
		return string.format("%d:%02d:%02d", Hours, Minutes, Secs)
	else
		return string.format("%d:%d:%d", Hours, Minutes, Secs)
	end
end

---Formats a duration in hours and minutes format (HH:MM), omitting seconds.
---Useful when seconds precision is not needed, such as for estimated completion times.
---Example: FormatTimeHHMM(3665) returns "1:01" (1 hour, 1 minute)
---Example: FormatTimeHHMM(125) returns "0:02" (2 minutes)
---@param Seconds number The duration in seconds (will be floored to nearest integer)
---@param ShowLeadingZeros boolean? Optional flag to show leading zeros on minutes (default: true)
---@return string The formatted time string in HH:MM format (e.g., "1:30", "0:05")
function FormatUtil.FormatTimeHHMM(Seconds: number, ShowLeadingZeros: boolean?): string
	local TotalSeconds = math.floor(Seconds)
	local Hours = math.floor(TotalSeconds * INVERSE_SECONDS_PER_HOUR)
	local Minutes = math.floor((TotalSeconds % SECONDS_PER_HOUR) * INVERSE_SECONDS_PER_MINUTE)

	if ShowLeadingZeros ~= false then
		return string.format("%d:%02d", Hours, Minutes)
	else
		return string.format("%d:%d", Hours, Minutes)
	end
end

---Formats a duration in days, hours, minutes, and seconds format (D:HH:MM:SS).
---Designed for displaying very long durations that span multiple days.
---Example: FormatTimeDDHHMMSS(90061) returns "1:01:01:01" (1 day, 1 hour, 1 minute, 1 second)
---Example: FormatTimeDDHHMMSS(172800) returns "2:00:00:00" (2 days)
---@param Seconds number The duration in seconds (will be floored to nearest integer)
---@param ShowLeadingZeros boolean? Optional flag to show leading zeros on hours, minutes, and seconds (default: true)
---@return string The formatted time string in D:HH:MM:SS format (e.g., "1:02:30:45", "5:12:05:30")
function FormatUtil.FormatTimeDDHHMMSS(Seconds: number, ShowLeadingZeros: boolean?): string
	local TotalSeconds = math.floor(Seconds)
	local Days = math.floor(TotalSeconds * INVERSE_SECONDS_PER_DAY)
	local Remainder = TotalSeconds % SECONDS_PER_DAY
	local Hours = math.floor(Remainder * INVERSE_SECONDS_PER_HOUR)
	Remainder = Remainder % SECONDS_PER_HOUR
	local Minutes = math.floor(Remainder * INVERSE_SECONDS_PER_MINUTE)
	local Secs = Remainder % SECONDS_PER_MINUTE

	if ShowLeadingZeros ~= false then
		return string.format("%d:%02d:%02d:%02d", Days, Hours, Minutes, Secs)
	else
		return string.format("%d:%d:%d:%d", Days, Hours, Minutes, Secs)
	end
end

---Formats a duration in days, hours, and minutes format (D:HH:MM), omitting seconds.
---Useful for displaying multi-day durations without second-level precision.
---Example: FormatTimeDDHHMM(90061) returns "1:01:01" (1 day, 1 hour, 1 minute)
---Example: FormatTimeDDHHMM(172800) returns "2:00:00" (2 days)
---@param Seconds number The duration in seconds (will be floored to nearest integer)
---@param ShowLeadingZeros boolean? Optional flag to show leading zeros on hours and minutes (default: true)
---@return string The formatted time string in D:HH:MM format (e.g., "1:02:30", "5:12:05")
function FormatUtil.FormatTimeDDHHMM(Seconds: number, ShowLeadingZeros: boolean?): string
	local TotalSeconds = math.floor(Seconds)
	local Days = math.floor(TotalSeconds * INVERSE_SECONDS_PER_DAY)
	local Remainder = TotalSeconds % SECONDS_PER_DAY
	local Hours = math.floor(Remainder * INVERSE_SECONDS_PER_HOUR)
	local Minutes = math.floor((Remainder % SECONDS_PER_HOUR) * INVERSE_SECONDS_PER_MINUTE)

	if ShowLeadingZeros ~= false then
		return string.format("%d:%02d:%02d", Days, Hours, Minutes)
	else
		return string.format("%d:%d:%d", Days, Hours, Minutes)
	end
end

---Formats a duration in a compact format showing only the most significant time units.
---Displays up to MaxUnits of the largest non-zero units with single-letter abbreviations.
---Ideal for UI elements with limited space or when showing approximate durations.
---Example: FormatTimeCompact(3665) returns "1h 1m" (1 hour, 1 minute)
---Example: FormatTimeCompact(90061, 3) returns "1d 1h 1m" (1 day, 1 hour, 1 minute)
---Example: FormatTimeCompact(45) returns "45s" (45 seconds)
---@param Seconds number The duration in seconds (will be floored to nearest integer)
---@param MaxUnits number? Optional maximum number of units to display (default: 2)
---@return string The formatted time string with compact abbreviations (e.g., "2h 30m", "5d 2h", "45s")
function FormatUtil.FormatTimeCompact(Seconds: number, MaxUnits: number?): string
	MaxUnits = MaxUnits or 2
	local TotalSeconds = math.floor(Seconds)

	if TotalSeconds == 0 then
		return "0s"
	end

	local Parts = {}
	local UnitsShown = 0

	for I = 1, #TIME_UNITS do
		if UnitsShown >= MaxUnits then
			break
		end

		local Unit = TIME_UNITS[I]
		local Count = math.floor(TotalSeconds / Unit.Value)
		if Count > 0 then
			table.insert(Parts, string.format("%d%s", Count, Unit.Short))
			TotalSeconds = TotalSeconds % Unit.Value
			UnitsShown += 1
		end
	end

	return table.concat(Parts, " ")
end

---Formats a duration in a verbose format with full unit names and proper pluralization.
---Displays up to MaxUnits of the largest non-zero units with complete words.
---Automatically handles singular/plural forms (e.g., "1 minute" vs "2 minutes").
---Ideal for user-facing messages or detailed time displays.
---Example: FormatTimeVerbose(3665) returns "1 hour 1 minute"
---Example: FormatTimeVerbose(90061, 3) returns "1 day 1 hour 1 minute"
---Example: FormatTimeVerbose(45) returns "45 seconds"
---@param Seconds number The duration in seconds (will be floored to nearest integer)
---@param MaxUnits number? Optional maximum number of units to display (default: 2)
---@return string The formatted time string with full unit names (e.g., "2 hours 30 minutes", "5 days 2 hours")
function FormatUtil.FormatTimeVerbose(Seconds: number, MaxUnits: number?): string
	MaxUnits = MaxUnits or 2
	local TotalSeconds = math.floor(Seconds)

	if TotalSeconds == 0 then
		return "0 seconds"
	end

	local Parts = {}
	local UnitsShown = 0

	for I = 1, #TIME_UNITS do
		if UnitsShown >= MaxUnits then
			break
		end

		local Unit = TIME_UNITS[I]
		local Count = math.floor(TotalSeconds / Unit.Value)
		if Count > 0 then
			local Label = Count == 1 and Unit.Singular or Unit.Plural
			table.insert(Parts, string.format("%d %s", Count, Label))
			TotalSeconds = TotalSeconds % Unit.Value
			UnitsShown += 1
		end
	end

	return table.concat(Parts, " ")
end

---Formats a duration as a simple number of seconds with optional decimal precision.
---The simplest time format, useful for precise measurements or when seconds are the primary unit.
---Example: FormatTimeSeconds(125.5) returns "126" (rounded to nearest integer)
---Example: FormatTimeSeconds(125.567, 2) returns "125.57" (2 decimal places)
---@param Seconds number The duration in seconds (can include fractional seconds)
---@param Decimals number? Optional number of decimal places to display (default: 0, rounds to nearest integer)
---@return string The formatted time string showing only seconds (e.g., "150", "3600", "125.57")
function FormatUtil.FormatTimeSeconds(Seconds: number, Decimals: number?): string
	if Decimals == nil or Decimals == 0 then
		return tostring(math.floor(Seconds + 0.5))
	else
		local Rounded = RoundToDecimals(Seconds, Decimals)
		return string.format("%." .. Decimals .. "f", Rounded)
	end
end

---Formats a time difference in a human-readable relative format with full words.
---Automatically determines if the time is in the past or future and formats accordingly.
---Provides natural language descriptions like "2 minutes ago" or "in 5 hours".
---Example: FormatTimeRelative(-120) returns "2 minutes ago"
---Example: FormatTimeRelative(3600) returns "in 1 hour"
---Example: FormatTimeRelative(-30) returns "just now"
---@param Seconds number The time difference in seconds (positive for future, negative for past, zero for now)
---@return string The formatted relative time string (e.g., "2 minutes ago", "in 5 hours", "just now")
function FormatUtil.FormatTimeRelative(Seconds: number): string
	local AbsSeconds = math.abs(Seconds)
	local IsPast = Seconds < 0

	if AbsSeconds < SECONDS_PER_MINUTE then
		return IsPast and "just now" or "in a moment"
	elseif AbsSeconds < SECONDS_PER_HOUR then
		local Minutes = math.floor(AbsSeconds * INVERSE_SECONDS_PER_MINUTE)
		local Unit = Minutes == 1 and "minute" or "minutes"
		return IsPast and string.format("%d %s ago", Minutes, Unit) or string.format("in %d %s", Minutes, Unit)
	elseif AbsSeconds < SECONDS_PER_DAY then
		local Hours = math.floor(AbsSeconds * INVERSE_SECONDS_PER_HOUR)
		local Unit = Hours == 1 and "hour" or "hours"
		return IsPast and string.format("%d %s ago", Hours, Unit) or string.format("in %d %s", Hours, Unit)
	else
		local Days = math.floor(AbsSeconds * INVERSE_SECONDS_PER_DAY)
		local Unit = Days == 1 and "day" or "days"
		return IsPast and string.format("%d %s ago", Days, Unit) or string.format("in %d %s", Days, Unit)
	end
end

---Formats a time difference in a compact relative format with abbreviated units.
---Similar to FormatTimeRelative but uses short abbreviations (m, h, d) for space-constrained displays.
---Example: FormatTimeRelativeShort(-120) returns "2m ago"
---Example: FormatTimeRelativeShort(3600) returns "1h"
---Example: FormatTimeRelativeShort(-30) returns "now"
---@param Seconds number The time difference in seconds (positive for future, negative for past, zero for now)
---@return string The formatted short relative time string (e.g., "2m ago", "5h", "3d ago", "now")
function FormatUtil.FormatTimeRelativeShort(Seconds: number): string
	local AbsSeconds = math.abs(Seconds)
	local IsPast = Seconds < 0
	local Suffix = IsPast and " ago" or ""

	if AbsSeconds < SECONDS_PER_MINUTE then
		return "now"
	elseif AbsSeconds < SECONDS_PER_HOUR then
		local Minutes = math.floor(AbsSeconds * INVERSE_SECONDS_PER_MINUTE)
		return string.format("%dm%s", Minutes, Suffix)
	elseif AbsSeconds < SECONDS_PER_DAY then
		local Hours = math.floor(AbsSeconds * INVERSE_SECONDS_PER_HOUR)
		return string.format("%dh%s", Hours, Suffix)
	else
		local Days = math.floor(AbsSeconds * INVERSE_SECONDS_PER_DAY)
		return string.format("%dd%s", Days, Suffix)
	end
end

return FormatUtil
