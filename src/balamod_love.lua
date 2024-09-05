local game_love_draw = love.draw
local game_love_update = love.update
local game_love_keypressed = love.keypressed
local game_love_keyreleased = love.keyreleased
local game_love_mousepressed = love.mousepressed
local game_love_mousereleased = love.mousereleased
local game_love_mousemoved = love.mousemoved
local game_love_wheelmoved = love.wheelmoved
local game_love_textinput = love.textinput
local game_love_resize = love.resize
local game_love_quit = love.quit
local game_love_load = love.load
local game_love_gamepad_pressed = love.gamepadpressed
local game_love_gamepad_released = love.gamepadreleased
local game_love_joystick_axis = love.joystickaxis
local game_love_errhand = love.errhand

local balamod = require("balamod")
local logging = require('logging')
local utils = require('utils')
local logger = logging.getLogger('love')
local localization = require('localization')
local console = require('console')
local stacktrace = require('stacktrace')


function love.load(args)
    -- Dev Console
    console.logger:info("Game loaded", args)
    for _, arg in ipairs(args) do
        local split = splitstring(arg, "=")
        if split[0] == "--log-level" then
            console.logger.level = split[1]:upper()
            console.log_level = split[1]:upper()
        end
    end
    logging.saveLogs()

    local status, message = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_game_load", true, args)
    if not status then
        logger:warn("Failed on_game_load for mods: ", message)
    end
    if game_love_load then
        game_love_load(args)
    end
end

function love.quit()
    console.logger:info("Quitting Balatro...")
    logging.saveLogs()
    local status, message = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_game_quit", true)
    if not status then
        logger:warn("Failed on_game_quit for mods: ", message)
    end
    if game_love_quit then
        game_love_quit()
    end
end

function love.update(dt)
    local cancel_update = false
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_pre_update", false, dt)
    if not status then
        logger:warn("Failed on_pre_update for mods: ", result)
    else
        cancel_update = utils.reduce(result, function(acc, val)
            return acc or val.result
        end, false)
    end
    if cancel_update then
        return
    end

    if game_love_update then
        game_love_update(dt)
    end

    if balamod.is_loaded == false then
        balamod.is_loaded = true
        console:initialize()
        console:registerCommands(balamod.mods)
        local status, message = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_enable", true)
        if not status then
            logger:warn("Failed to load mods: ", message)
        else
            localization.inject()
        end
    end

    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_post_update", false, dt)
    if not status then
        logger:warn("Failed on_post_update for mods: ", result)
    end
end

function love.draw()
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_pre_render", false)
    if not status then
        logger:warn("Failed on_pre_render for mods: ", result)
    end

    if game_love_draw then
        game_love_draw()
    end
    if console.is_open then
        console:draw()
    end
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_post_render", false)
    if not status then
        logger:warn("Failed on_post_render for mods: ", result)
    end
end

function love.keypressed(key)
    local cancel_event = false
    cancel_event = console:handleKeyPressed(key)
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_key_pressed", false, key)
    if not status then
        logger:warn("Failed on_key_pressed for mods: ", result)
    else
        cancel_event = utils.reduce(result, function(acc, val)
            return acc or val.result
        end, cancel_event)
    end

    if cancel_event then
        return
    end

    if game_love_keypressed then
        game_love_keypressed(key)
    end
end

function love.keyreleased(key)
    local cancel_event = false
    cancel_event = console:handleKeyReleased(key)
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_key_released", false, key)
    if not status then
        logger:warn("Failed on_key_released for mods: ", result)
    else
        cancel_event = utils.reduce(result, function(acc, val)
            return acc or val.result
        end, cancel_event)
    end

    if cancel_event then
        return
    end

    if game_love_keyreleased then
        game_love_keyreleased(key)
    end
end

function love.gamepadpressed(joystick, button)
    local cancel_event = false
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_gamepad_pressed", false, joystick, button)
    if not status then
        logger:warn("Failed on_gamepad_pressed for mods: ", result)
    else
        cancel_event = utils.reduce(result, function(acc, val)
            return acc or val.result
        end, false)
    end
    if cancel_event then
        return
    end

    if game_love_gamepad_pressed then
        game_love_gamepad_pressed(joystick, button)
    end
end

function love.gamepadreleased(joystick, button)
    local cancel_event = false
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_gamepad_released", false, joystick, button)
    if not status then
        logger:warn("Failed on_gamepad_released for mods: ", result)
    else
        cancel_event = utils.reduce(result, function(acc, val)
            return acc or val.result
        end, false)
    end
    if cancel_event then
        return
    end

    if game_love_gamepad_released then
        game_love_gamepad_released(joystick, button)
    end
end

function love.mousepressed(x, y, button, touch)
    local cancel_event = false
    cancel_event = console.is_open
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_mouse_pressed", false, x, y, button, touch)
    if not status then
        logger:warn("Failed on_mouse_pressed for mods: ", result)
    else
        cancel_event = utils.reduce(result, function(acc, val)
            return acc or val.result
        end, false)
    end
    if cancel_event then
        return
    end

    if game_love_mousepressed then
        game_love_mousepressed(x, y, button, touch)
    end
end

function love.mousereleased(x, y, button)
    local cancel_event = console.is_open
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_mouse_released", false, x, y, button)
    if not status then
        logger:warn("Failed on_mouse_released for mods: ", result)
    else
        cancel_event = utils.reduce(result, function(acc, val)
            return acc or val.result
        end, false)
    end
    if cancel_event then
        return
    end

    if game_love_mousereleased then
        game_love_mousereleased(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    local cancel_event = false
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_mouse_moved", false, x, y, dx, dy, istouch)
    if not status then
        logger:warn("Failed on_mouse_moved for mods: ", result)
    else
        cancel_event = utils.reduce(result, function(acc, val)
            return acc or val.result
        end, false)
    end
    if cancel_event then
        return
    end

    if game_love_mousemoved then
        game_love_mousemoved(x, y, dx, dy, istouch)
    end
end

function love.joystickaxis(joystick, axis, value)
    local cancel_event = false
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_joystick_axis", false, joystick, axis, value)
    if not status then
        logger:warn("Failed on_joystick_axis for mods: ", result)
    else
        cancel_event = utils.reduce(result, function(acc, val)
            return acc or val.result
        end, false)
    end
    if cancel_event then
        return
    end

    if game_love_joystick_axis then
        game_love_joystick_axis(joystick, axis, value)
    end
end

function default_error_handler(msg)
	msg = tostring(msg)

	error_printer(msg, 2)

	if not love.window or not love.graphics or not love.event then
		return
	end

	if not love.graphics.isCreated() or not love.window.isOpen() then
		local success, status = pcall(love.window.setMode, 800, 600)
		if not success or not status then
			return
		end
	end

	-- Reset state.
	if love.mouse then
		love.mouse.setVisible(true)
		love.mouse.setGrabbed(false)
		love.mouse.setRelativeMode(false)
	end
	if love.joystick then
		-- Stop all joystick vibrations.
		for i,v in ipairs(love.joystick.getJoysticks()) do
			v:setVibration()
		end
	end
	if love.audio then love.audio.stop() end
	love.graphics.reset()
	local font = love.graphics.setNewFont(math.floor(love.window.toPixels(14)))

	love.graphics.setBackgroundColor(89, 157, 220)
	love.graphics.setColor(255, 255, 255, 255)

	local trace = debug.traceback()

	love.graphics.clear(love.graphics.getBackgroundColor())
	love.graphics.origin()

	local err = {}

	table.insert(err, "Error\n")
	table.insert(err, msg.."\n\n")

	for l in string.gmatch(trace, "(.-)\n") do
		if not string.match(l, "boot.lua") then
			l = string.gsub(l, "stack traceback:", "Traceback\n")
			table.insert(err, l)
		end
	end

	local p = table.concat(err, "\n")

	p = string.gsub(p, "\t", "")
	p = string.gsub(p, "%[string \"(.-)\"%]", "%1")

	local function draw()
		local pos = love.window.toPixels(70)
		love.graphics.clear(love.graphics.getBackgroundColor())
		love.graphics.printf(p, pos, pos, love.graphics.getWidth() - pos)
		love.graphics.present()
	end

	while true do
		love.event.pump()

		for e, a, b, c in love.event.poll() do
			if e == "quit" then
				return
			elseif e == "keypressed" and a == "escape" then
				return
			elseif e == "touchpressed" then
				local name = love.window.getTitle()
				if #name == 0 or name == "Untitled" then name = "Game" end
				local buttons = {"OK", "Cancel"}
				local pressed = love.window.showMessageBox("Quit "..name.."?", "", buttons)
				if pressed == 1 then
					return
				end
			end
		end

		draw()

		if love.timer then
			love.timer.sleep(0.1)
		end
	end

end

function love.errhand(msg)
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_error", true, msg)
    if not status then
        logger:warn("Failed on_error for mods: ", result)
    end

    if game_love_errhand then
        game_love_errhand(stacktrace.stacktrace(msg))
    else
        default_error_handler(stacktrace.stacktrace(msg))
    end
end

function love.wheelmoved(x, y)
    local cancel_event = false
    cancel_event = console:handleWheelMoved(x, y)
    local status, result = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_mousewheel", false, x, y)
    if not status then
        logger:warn("Failed  for mods: ", result)
    else
        cancel_event = utils.reduce(result, function(acc, val)
            return acc or val.result
        end, false)
    end

    if cancel_event then
        return
    end
    if game_love_wheelmoved then
        game_love_wheelmoved(x, y)
    end
end
