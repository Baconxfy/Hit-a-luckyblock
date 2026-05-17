
--[[

░░░░░██╗░█████╗░░██████╗  ██████╗░███████╗██╗░░░██╗
░░░░░██║██╔══██╗██╔════╝  ██╔══██╗██╔════╝██║░░░██║
░░░░░██║██║░░██║╚█████╗░  ██║░░██║█████╗░░╚██╗░██╔╝
██╗░░██║██║░░██║░╚═══██╗  ██║░░██║██╔══╝░░░╚████╔╝░
╚█████╔╝╚█████╔╝██████╔╝  ██████╔╝███████╗░░╚██╔╝░░
░╚════╝░░╚════╝░╚═════╝░  ╚═════╝░╚══════╝░░░╚═╝░░░

]]

---ThreadsHandler module using Promise from evaera for better async task management
---@module ThreadsHandler
--< Modules
local Promise = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Promise"))

local ThreadsHandler = {}

---Creates a delayed thread with cancellation support using Promise
---@param duration number The delay duration in seconds
---@param callback () -> any The callback function to execute
---@return () -> (nil, number?) A function that cancels the delay and returns elapsed time
function ThreadsHandler.nedDelayThread(duration: number, callback: () -> any) :()->()
	local startTime = os.clock()
	local cancelled = false

	-- Usar Promise para el delay, pero controlar la ejecución del callback
	local delayPromise = Promise.delay(duration or 1)

	delayPromise
		:andThen(function()
			if not cancelled then
				callback()
			end
		end)
		:catch(function() end) -- Silenciar errores si se cancela

	return function()
		if not cancelled then
			cancelled = true
			local elapsed = math.floor(os.clock() - startTime)
			-- Promise ya no se ejecutará si cancelled es true
			return nil, elapsed
		end
		return nil, math.floor(os.clock() - startTime)
	end
end

---Creates a new thread using Promise for better error handling
---@param callback () -> any The callback function to execute
---@return () -> nil A function that cancels the thread
function ThreadsHandler.newThread(callback: () -> any) :()->()
	local cancelled = false
	local thread

	-- Usamos Promise para manejar errores, pero task.spawn para cancelación
	local promise = Promise.new(function(resolve, reject)
		thread = task.spawn(function()
			local success, result = pcall(function()
				if not cancelled then
					return callback()
				end
			end)

			if success then
				resolve(result)
			else
				reject(result)
			end
		end)
	end)

	promise:catch(function(err)
		-- Manejar errores silenciosamente si fue cancelado
		if not cancelled then
			warn("Error en thread:", err)
		end
	end)

	return function()
		cancelled = true
		if thread then
			-- Intentar cancelar el thread
			local cancelSuccess = pcall(function()
				task.cancel(thread)
			end)

			if not cancelSuccess then
				-- Si no se puede cancelar directamente, usar defer
				task.defer(function()
					task.cancel(thread)
				end)
			end
		end
		return nil
	end
end

---Alternative: Creates a delayed promise with cancellation and time tracking
---@param duration number The delay duration in seconds
---@param callback () -> any The callback function to execute
---@return Promise A promise that can be cancelled
function ThreadsHandler.createDelayedPromise(duration: number, callback: () -> any): typeof(Promise.delay())
	return Promise.delay(duration or 1):andThen(function()
		return callback()
	end)
end

---Alternative: Creates a deferred promise for background execution
---@param callback () -> any The callback function to execute
---@return Promise A promise that can be cancelled
function ThreadsHandler.createDeferredPromise(callback: () -> any): typeof(Promise.delay())
	return Promise.defer(callback)
end

return ThreadsHandler
