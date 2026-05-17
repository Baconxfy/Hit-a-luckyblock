--!strict

--[[
	Stack Module
	
	A generic stack data structure implementation for LIFO (Last In, First Out) operations.
	Used internally by iRichText for managing nested tag states during parsing.
]]

local Stack = {}
Stack.__index = Stack
Stack.__metatable = true

--[[
	Internal type representing the stack's internal state.
]]
type self = {
	_data: { any },
}

--[[
	Stack Type
	
	The exported Stack type. A LIFO data structure that supports push, pop, peek, and search operations.
]]
export type Stack = typeof(setmetatable({} :: self, Stack))

--[[
	Creates a new empty Stack instance.
	
	@return Stack A new empty stack
]]
function Stack.new(): Stack
	local self = setmetatable({}, Stack)
	self._data = {}
	return self
end

--[[
	Pushes an element onto the top of the stack.
	
	@param Element any The element to add to the stack
]]
function Stack:Push(Element: any): ()
	table.insert(self._data, Element)
end

--[[
	Removes and returns the top element from the stack.
	
	@return any The element that was at the top of the stack
	@error Throws an error if the stack is empty
]]
function Stack:Pop(): any
	if #self._data == 0 then
		error("Attempted to call Pop on an empty stack", 2)
	end
	local Value = self._data[#self._data]
	self._data[#self._data] = nil
	return Value
end

--[[
	Returns the top element of the stack without removing it.
	
	@return any The element at the top of the stack
	@error Throws an error if the stack is empty
]]
function Stack:Peek(): any
	if #self._data == 0 then
		error("Attempted to call Peek on an empty stack", 2)
	end
	return self._data[#self._data]
end

--[[
	Checks if the stack is empty.
	
	@return boolean True if the stack has no elements, false otherwise
]]
function Stack:Empty(): boolean
	return #self._data == 0
end

--[[
	Searches for an element in the stack and returns its position from the top.
	
	Position 1 is the top element. Returns -1 if the element is not found.
	
	@param Element any The element to search for
	@return number The position of the element from the top (1-based), or -1 if not found
]]
function Stack:Search(Element: any): number
	local Index = table.find(self._data, Element)
	if not Index then
		return -1
	end
	return #self._data - Index + 1
end

--[[
	Metamethod for converting the stack to a string representation.
	
	@return string A string representation showing the top element and stack size
]]
function Stack:__tostring(): string
	return `Stack({self._data[#self._data]},#{#self._data})`
end

--[[
	Metamethod for iterating over the stack elements.
	
	Allows the stack to be used in for loops. Iterates in the order they were pushed.
	
	@return (function, table) An iterator function and the stack's data table
]]
function Stack:__iter(): (typeof(next), { any })
	return next, self._data
end

return Stack
