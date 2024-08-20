balalib = require("balalib") -- to be accessible by the mods
local logging = require('logging')
local platform = require('platform')
local math = require('math')
local console = require('console')
local utils = require('utils')
local https = require('https')

logger = logging.getLogger('balamod')

balalib.setup_injection()
logger:info('Injection setup done')

--need_update = balalib.need_update()
need_update = false
local status, message = pcall(balalib.need_update)
if not status then
    logger:error('Error while checking for updates: ', message)
    need_update = false
else
    need_update = message
end

logger:info('Need update: ', need_update)

mods = {}
local apis = {
    logging = logging,
    console = console,
    math = math,
    platform = platform,
}
is_loaded = false
local RESULT = {
    SUCCESS = 0,
    MOD_NOT_FOUND_IN_REPOS = 1,
    MOD_NOT_FOUND_IN_MODS = 2,
    MOD_ALREADY_PRESENT = 3,
    NETWORK_ERROR = 4,
    MOD_FS_LOAD_ERROR = 5,
    MOD_PCALL_ERROR = 6,
    TAR_DECOMPRESS_ERROR = 7,
    MOD_NOT_CONFORM = 8,
}
local paths = {} -- Paths to the files that will be loaded
local _VERSION = require('balamod_version')

local function splitstring(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function buildPaths(root,ignore)
    local items = love.filesystem.getDirectoryItems(root)
    for _, file in ipairs(items) do
        if root ~= "" then
            file = root.."/"..file
        end
        local info = love.filesystem.getInfo(file)
        if info then
            if info.type == "file" and file:match("%.lua$") then
                table.insert(paths,file)
            elseif info.type == "directory" then
                local valid = true
                for _, i in ipairs(ignore) do
                    if i == file then
                        valid = false
                    end
                end
                if valid then
                    buildPaths(file,ignore)
                end
            end
        end
    end
end

local function request(url)
    logger:debug('Request made with url: ', url)
    local code
    local response
    code, response, headers = https.request(url, {headers = {['User-Agent'] = 'Balamod-Client'}})
    if (code == 301 or code == 302) and headers.location then
        -- follow redirects if necessary
        code, response = request(headers.location)
    end
    return code, response
end

local function isModPresent(modId)
    if not modId then
        logger:error('Mod id is nil')
        return false
    end
    return mods[modId] ~= nil
end

local function validateManifest(modFolder, manifest)
    local expectedFields = {
        id = true,
        name = true,
        version = true,
        description = true,
        author = true,
        load_before = true,
        load_after = true,
        min_balamod_version = false,
        max_balamod_version = false,
        dependencies = false,
    }

    -- check that all manifest expected fields are present
    for field, required in pairs(expectedFields) do
        if manifest[field] == nil and required then
            logger:error('Manifest in folder ', modFolder, ' is missing field: ', field)
            return false
        end
    end
    -- check that none of the manifest fields are not in the expected fields
    for key, _ in pairs(manifest) do
        if expectedFields[key] == nil then
            logger:error('Manifest in folder ', modFolder, ' contains unexpected field: ', key)
            return false
        end
    end

    -- check that the load_before, load_after and description fields are arrays
    if type(manifest.load_before) ~= 'table' then
        logger:error('Manifest in folder ', modFolder, ' has a non-array load_before field')
        return false
    end
    if type(manifest.load_after) ~= 'table' then
        logger:error('Manifest in folder ', modFolder, ' has a non-array load_after field')
        return false
    end
    if type(manifest.description) ~= 'table' then
        logger:error('Manifest in folder ', modFolder, ' has a non-array description field')
        return false
    end

    -- check that the load_before and load_after fields are strings
    for _, modId in ipairs(manifest.load_before) do
        if type(modId) ~= 'string' then
            logger:error('Manifest in folder ', modFolder, ' has a non-string load_before field')
            return false
        end
    end
    for _, modId in ipairs(manifest.load_after) do
        if type(modId) ~= 'string' then
            logger:error('Manifest in folder ', modFolder, ' has a non-string load_after field')
            return false
        end
    end

    -- check that the version field is a string, matching semantic versioning
    if not manifest.version:match('%d+%.%d+%.%d+') then
        logger:error('Manifest in folder ', modFolder, ' has a non-semantic versioning version field')
        return false
    end

    -- check that the author field is a string
    if type(manifest.author) ~= 'string' then
        logger:error('Manifest in folder ', modFolder, ' has a non-string author field')
        return false
    end

    -- check that the id field is a string
    if type(manifest.id) ~= 'string' then
        logger:error('Manifest in folder ', modFolder, ' has a non-string id field')
        return false
    end

    -- check that the name field is a string
    if type(manifest.name) ~= 'string' then
        logger:error('Manifest in folder ', modFolder, ' has a non-string name field')
        return false
    end

    -- check that the dependencies field is a key-value table, if it exists
    if manifest.dependencies then
        local incorrectDependencies = {}
        if type(manifest.dependencies) ~= 'table' then
            logger:error('Manifest in folder ', modFolder, ' has a non-table dependencies field')
            return false
        end
        for modId, version in pairs(manifest.dependencies) do
            if type(modId) ~= 'string' then
                logger:error('Manifest in folder ', modFolder, ' has a non-string key in dependencies field')
                return false
            end
            if type(version) ~= 'string' then
                logger:error('Manifest in folder ', modFolder, ' has a non-string value in dependencies field')
                return false
            end
            local versionConstraintCorrect = false
            -- exact version match or caret version constraint
            if string.match(version, '%^?%d+%.%d+%.%d+') then
                versionConstraintCorrect = true
            end
            -- also need to support version constraints like >=3,<4, >2.0,<6 and so on
            -- though, lua doesn't support optional groups in its pattern matching for some dumb reason
            -- so we'll build a table that contains all of the patterns programatically
            -- we can at least match the operator with the [<>]=? pattern
            local patterns = {}
            local versionPatterns = {'%d+', '%d+%.%d+', '%d+%.%d+%.%d+'}
            for _, versionPattern1 in ipairs(versionPatterns) do
                for _, versionPattern2 in ipairs(versionPatterns) do
                    table.insert(patterns, '[<>]=?' .. versionPattern1 .. ', ?[<>]=?' .. versionPattern2)
                end
            end
            -- check every generated pattern, one at a time, if any of them matches, then the version constraint is correct
            for _, pattern in ipairs(patterns) do
                if string.match(version, pattern) then
                    versionConstraintCorrect = true
                    break
                end
            end
            if not versionConstraintCorrect then
                table.insert(incorrectDependencies, modId..':'..version)
            end
        end
        if #incorrectDependencies > 0 then
            -- some of the dependencies are incorrect for the mod, let's log them and return false
            logger:error('Manifest in folder ', modFolder, ' has incorrect dependencies field: ', table.concat(incorrectDependencies, ', '))
            return false
        end
    end

    return true
end


local function toggleMod(mod)
    logger:debug('Toggling mod: ' .. mod.id)
    mod.enabled = not mod.enabled
    print(mod.enabled)
    if mod.enabled and mod.on_enable and type(mod.on_enable) == 'function' then
        pcall(mod.on_enable)
    elseif not mod.enabled and mod.on_disable and type(mod.on_disable) == 'function' then
        pcall(mod.on_disable)
    end

    if mod.enabled then
        if love.filesystem.getInfo('mods/' .. mod.id .. '/disable.it', 'file') then
            love.filesystem.remove('mods/' .. mod.id .. '/disable.it')
            print('Removed disable.it')
        end
    else
        love.filesystem.write('mods/' .. mod.id .. '/disable.it', '')
        print('Created disable.it')
    end

    mods[mod.id] = mod
end

local function callModCallbacksIfExists(mods, callback_name, should_log, ...)
    local sorted = utils.values(mods)
    table.sort(sorted, function(a, b)
        return a.order < b.order
    end)
    local mod_returns = {}
    -- pre loading all mods
    for _, mod in ipairs(sorted) do
        if mod.enabled and mod[callback_name] and type(mod[callback_name]) == "function" then
            if should_log then
                logger:info("Calling mod callback", callback_name, "for", mod.id)
            end
            local status, message = pcall(mod[callback_name], ...) -- Call the on_pre_load function of the mod if it exists
            if not status then
                logger:warn("Callback", callback_name, "for mod ", mod.id, "failed: ", message)
            else
                table.insert(mod_returns, {modId = mod.id, result = message})
            end
        end
    end
    return mod_returns
end

buildPaths("",{"mods","apis","resources","localization"})
-- current_game_code = love.filesystem.read(path)
buildPaths = nil -- prevent rerunning (i think)

current_game_code = {}
for _, path in ipairs(paths) do
    current_game_code[path] = love.filesystem.read(path)
end

if not love.filesystem.getInfo("mods", "directory") then -- Create mods folder if it doesn't exist
    love.filesystem.createDirectory("mods")
end

if not love.filesystem.getInfo("logs", "directory") then -- Create logs folder if it doesn't exist
    love.filesystem.createDirectory("logs")
end

if not love.filesystem.getInfo("apis", "directory") then -- Create apis folder if it doesn't exist
    love.filesystem.createDirectory("apis")
end

-- apis will be loaded first, then mods

mods["dev_console"] = {
    id = "dev_console",
    name = "Dev Console",
    load_before = {},
    load_after = {},
    version = "0.6.0",
    author = "sbordeyne & UwUDev",
    description = {
        "Press F2 to open/close the console",
        "Press F1 to restart the game",
        "Use command `help` for a list of ",
        "available commands and shortcuts",
    },
    enabled = true,
    on_game_load = function(args)
        console.logger:info("Game loaded", args)
        for _, arg in ipairs(args) do
            local split = splitstring(arg, "=")
            if split[0] == "--log-level" then
                console.logger.level = split[1]:upper()
                console.log_level = split[1]:upper()
            end
        end
        logging.saveLogs()
    end,
    on_game_quit = function()
        console.logger:info("Quitting Balatro...")
        logging.saveLogs()
    end,
    on_error = function(message)
        console.logger:error("Error: ", message)
        -- on error, write all messages to a file
        logging.saveLogs()
    end,
    on_enable = function()
        console.logger:debug("Dev Console enabled")
        contents, size = love.filesystem.read(console.history_path)
        if contents then
            console.logger:trace("History file size", size)
            for line in contents:gmatch("[^\r\n]+") do
                if line and line ~= "" then
                    table.insert(console.command_history, line)
                end
            end
        end

        console.logger:debug("Registering commands")
        console:registerCommand(
                "help",
                function()
                    console.logger:print("Available commands:")
                    for name, cmd in pairs(console.commands) do
                        if cmd.desc then
                            console.logger:print(name .. ": " .. cmd.desc)
                        end
                    end
                    return true
                end,
                "Prints a list of available commands",
                function(current_arg)
                    local completions = {}
                    for name, _ in pairs(console.commands) do
                        if name:find(current_arg, 1, true) == 1 then
                            table.insert(completions, name)
                        end
                    end
                    return completions
                end,
                "Usage: help <command>"
        )

        console:registerCommand(
                "shortcuts",
                function()
                    console.logger:print("Available shortcuts:")
                    console.logger:print("F2: Open/Close the console")
                    console.logger:print("F1: Restart the game")
                    console.logger:print("F4: Toggle debug mode")
                    if platform.is_mac then
                        console.logger:print("Cmd+C: Copy the current command to the clipboard.")
                        console.logger:print("Cmd+Shift+C: Copies all messages to the clipboard")
                        console.logger:print("Cmd+V: Paste the clipboard into the current command")
                    else
                        console.logger:print("Ctrl+C: Copy the current command to the clipboard.")
                        console.logger:print("Ctrl+Shift+C: Copies all messages to the clipboard")
                        console.logger:print("Ctrl+V: Paste the clipboard into the current command")
                    end
                    return true
                end,
                "Prints a list of available shortcuts",
                function(current_arg)
                    return nil
                end,
                "Usage: shortcuts"
        )

        console:registerCommand(
                "history",
                function()
                    console.logger:print("Command history:")
                    for i, cmd in ipairs(console.command_history) do
                        console.logger:print(i .. ": " .. cmd)
                    end
                    return true
                end,
                "Prints the command history"
        )

        console.logger:debug("Registering command: clear")
        console:registerCommand(
                "clear",
                function()
                    logging.clearLogs()
                    return true
                end,
                "Clear the console"
        )

        console:registerCommand(
                "exit",
                function()
                    console:toggle()
                    return true
                end,
                "Close the console"
        )

        console:registerCommand(
                "give",
                function(args)
                    local id = args[1]
                    local c1 = nil
                    if string.sub(id, 1, 2) == "j_" then
                        c1 = create_card(nil, G.jokers, nil, 1, true, false, id, nil)
                    else
                        c1 = create_card(nil, G.consumeables, nil, 1, true, false, id, nil)
                    end
                    G.E_MANAGER:add_event(Event({
                        trigger = 'after',
                        delay = 0.1,
                        func = function()
                            c1:add_to_deck()
                            if string.sub(id, 1, 2) == "j_" then
                                G.jokers:emplace(c1)
                            else
                                G.consumeables:emplace(c1)
                            end

                            G.CONTROLLER:save_cardarea_focus('jokers')
                            G.CONTROLLER:recall_cardarea_focus('jokers')
                            return true
                        end
                    }))
                    return true
                end,
                "Give an item to the player",
                function(current_arg)
                    local ret = {}
                    for k,_ in pairs(G.P_CENTERS) do
                        if string.find(k, current_arg) == 1 then
                            table.insert(ret, k)
                        end
                    end
                    return ret
                end
        )

        console:registerCommand(
                "money",
                function(args)
                    if args[1] and args[2] then
                        local amount = tonumber(args[2])
                        if amount then
                            if args[1] == "add" then
                                ease_dollars(amount, true)
                                console.logger:info("Added " .. amount .. " money to the player")
                            elseif args[1] == "remove" then
                                ease_dollars(-amount, true)
                                console.logger:info("Removed " .. amount .. " money from the player")
                            elseif args[1] == "set" then
                                local currentMoney = G.GAME.dollars
                                local diff = amount - currentMoney
                                ease_dollars(diff, true)
                                console.logger:info("Set player money to " .. amount)
                            else
                                console.logger:error("Invalid operation, use add, remove or set")
                            end
                        else
                            console.logger:error("Invalid amount")
                            return false
                        end
                    else
                        console.logger:warn("Usage: money <add/remove/set> <amount>")
                        return false
                    end
                    return true
                end,
                "Change the player's money",
                function (current_arg)
                    local subcommands = {"add", "remove", "set"}
                    for i, v in ipairs(subcommands) do
                        if v:find(current_arg, 1, true) == 1 then
                            return {v}
                        end
                    end
                    return nil
                end
        )

        console:registerCommand(
                "discards",
                function(args)
                    if args[1] and args[2] then
                        local amount = tonumber(args[2])
                        if amount then
                            if args[1] == "add" then
                                ease_discard(amount, true)
                                console.logger:info("Added " .. amount .. " discards to the player")
                            elseif args[1] == "remove" then
                                ease_discard(-amount, true)
                                console.logger:info("Removed " .. amount .. " discards from the player")
                            elseif args[1] == "set" then
                                local currentDiscards = G.GAME.current_round.discards_left
                                local diff = amount - currentDiscards
                                ease_discard(diff, true)
                                console.logger:info("Set player discards to " .. amount)
                            else
                                console.logger:error("Invalid operation, use add, remove or set")
                                return false
                            end
                        else
                            console.logger:error("Invalid amount")
                            return false
                        end
                    else
                        console.logger:warn("Usage: discards <add/remove/set> <amount>")
                        return false
                    end
                    return true
                end,
                "Change the player's discards",
                function (current_arg)
                    local subcommands = {"add", "remove", "set"}
                    for i, v in ipairs(subcommands) do
                        if v:find(current_arg, 1, true) == 1 then
                            return {v}
                        end
                    end
                    return nil
                end
        )

        console:registerCommand(
                "hands",
                function(args)
                    if args[1] and args[2] then
                        local amount = tonumber(args[2])
                        if amount then
                            if args[1] == "add" then
                                ease_hands_played(amount, true)
                                console.logger:info("Added " .. amount .. " hands to the player")
                            elseif args[1] == "remove" then
                                ease_hands_played(-amount, true)
                                console.logger:info("Removed " .. amount .. " hands from the player")
                            elseif args[1] == "set" then
                                local currentHands = G.GAME.current_round.hands_left
                                local diff = amount - currentHands
                                ease_hands_played(diff, true)
                                console.logger:info("Set player hands to " .. amount)
                            else
                                console.logger:error("Invalid operation, use add, remove or set")
                                return false
                            end
                        else
                            console.logger:error("Invalid amount")
                            return false
                        end
                    else
                        console.logger:warn("Usage: hands <add/remove/set> <amount>")
                        return false
                    end
                    return true
                end,
                "Change the player's remaining hands",
                function (current_arg)
                    local subcommands = {"add", "remove", "set"}
                    for i, v in ipairs(subcommands) do
                        if v:find(current_arg, 1, true) == 1 then
                            return {v}
                        end
                    end
                    return nil
                end
        )

        console:registerCommand(
                "luamod",
                function(args)
                    if args[1] then
                        local modId = args[1]
                        if isModPresent(modId) then
                            local mod = mods[modId]
                            if mod.enabled and mod.on_disable and type(mod.on_disable) == "function" then
                                local success, result = pcall(mod.on_disable)
                                if not success then
                                    console.logger:error("Error disabling mod: " .. modId)
                                    console.logger:error(result)
                                    return false
                                end
                            end
                            mod = loadMod(modId)
                            mods[modId] = mod
                            mods = sortMods(mods)
                            -- no need to redo the whole shebang, just call on_enable
                            -- this is because the dependencies are most likely already loaded
                            if mod.enabled then
                                if mod.on_enable and type(mod.on_enable) == 'function' then
                                    local status, message = pcall(mod.on_enable)
                                    if not status then
                                        console.logger:error("Error enabling mod: " .. modId)
                                        console.logger:error(message)
                                        return false
                                    end
                                end
                            end
                            console.logger:info("Reloaded mod: " .. modId)
                        else
                            console.logger:error("Mod not found: " .. modId)
                            return false
                        end
                    else
                        console.logger:error("Usage: luamod <mod_id>")
                        return false
                    end
                    return true
                end,
                "Reload a mod using its id",
                function (current_arg)
                    local completions = {}
                    for modId, _ in pairs(mods) do
                        if modId:find(current_arg, 1, true) == 1 then
                            table.insert(completions, modId)
                        end
                    end
                    return completions
                end,
                "Usage: luamod <mod_id>"
        )

        console:registerCommand(
                "sandbox",
                function (args)
                    G:sandbox()
                    return true
                end,
                "Goes to the sandbox stage",
                function (current_arg)
                    return nil
                end,
                "Usage: sandbox"
        )

        console:registerCommand(
                "luarun",
                function (args)
                    local code = table.concat(args, " ")
                    local func, err = load(code)
                    if func then
                        console.logger:info("Lua code executed successfully")
                        console.logger:print(func())
                        return true
                    else
                        console.logger:error("Error loading lua code: ", err)
                        return false
                    end
                end,
                "Run lua code in the context of the game",
                function (current_arg)
                    return nil
                end,
                "Usage: luarun <lua_code>"
        )

        console:registerCommand(
        -- TODO: change with balalib
                "installmod",
                function (args)
                    local url = args[1]
                    local modInfo = {
                        id = "testmod",
                        url = url,
                        present = false,
                        needUpdate = true,
                    }
                    local result = installModFromTar(modInfo)
                    if result == RESULT.SUCCESS then
                        console.logger:info("Mod installed successfully")
                        return true
                    else
                        console.logger:error("Error installing mod: ", result)
                        return false
                    end
                end,
                "Install a mod from a tarball",
                function (current_arg)
                    return nil
                end,
                "Usage: installmod <mod_url>"
        )

        console.logger:debug("Dev Console on_enable completed")
    end,
    on_disable = function()
        console.removeCommand("help")
        console.removeCommand("shortcuts")
        console.removeCommand("history")
        console.removeCommand("clear")
        console.removeCommand("exit")
        console.removeCommand("quit")
        console.removeCommand("give")
        console.removeCommand("money")
        console.removeCommand("discards")
        console.removeCommand("hands")
        console.logger:debug("Dev Console disabled")
    end,
    on_key_pressed = function (key_name)
        if key_name == "f2" then
            console:toggle()
            return true
        end
        if key_name == "f1" then
            balalib.restart()
            return true
        end
        if console.is_open then
            console:typeKey(key_name)
            return true
        end

        if key_name == "f4" then
            G.DEBUG = not G.DEBUG
            if G.DEBUG then
                console.logger:info("Debug mode enabled")
            else
                console.logger:info("Debug mode disabled")
            end
        end
        return false
    end,
    on_post_render = function ()
        console.max_lines = math.floor(love.graphics.getHeight() / console.line_height) - 5  -- 5 lines of bottom padding
        local font = love.graphics.getFont()
        if console.is_open then
            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
            local messagesToDisplay = console:getMessagesToDisplay()
            local i = 1
            for _, message in ipairs(messagesToDisplay) do
                r, g, b = console:getMessageColor(message)
                love.graphics.setColor(r, g, b, 1)
                local formattedMessage = message:formatted()
                if font:getWidth(formattedMessage) > love.graphics.getWidth() then
                    local lines = console:wrapText(formattedMessage, love.graphics.getWidth())
                    for _, line in ipairs(lines) do
                        love.graphics.print(line, 10, 10 + i * 20)
                        i = i + 1
                    end
                else
                    love.graphics.print(formattedMessage, 10, 10 + i * 20)
                    i = i + 1
                end
            end
            love.graphics.setColor(1, 1, 1, 1) -- white
            love.graphics.print(console.cmd, 10, love.graphics.getHeight() - 30)
        end
    end,
    on_key_released = function (key_name)
        if key_name == "capslock" then
            console.modifiers.capslock = not console.modifiers.capslock
            console:modifiersListener()
            return
        end
        if key_name == "scrolllock" then
            console.modifiers.scrolllock = not console.modifiers.scrolllock
            console:modifiersListener()
            return
        end
        if key_name == "numlock" then
            console.modifiers.numlock = not console.modifiers.numlock
            console:modifiersListener()
            return
        end
        if key_name == "lalt" or key_name == "ralt" then
            console.modifiers.alt = false
            console:modifiersListener()
            return false
        end
        if key_name == "lctrl" or key_name == "rctrl" then
            console.modifiers.ctrl = false
            console:modifiersListener()
            return false
        end
        if key_name == "lshift" or key_name == "rshift" then
            console.modifiers.shift = false
            console:modifiersListener()
            return false
        end
        if key_name == "lgui" or key_name == "rgui" then
            console.modifiers.meta = false
            console:modifiersListener()
            return false
        end
        return false
    end,
    on_mouse_pressed = function(x, y, button, touches)
        if console.is_open then
            return true  -- Do not press buttons through the console, this cancels the event
        end
    end,
    on_mouse_released = function(x, y, button)
        if console.is_open then
            return true -- Do not release buttons through the console, this cancels the event
        end
    end,
}


-- Topological sort of mods based on load_before and load_after fields
-- 1. Create a directed graph with the mods as nodes and the load_before and load_after fields as edges
-- 2. Run a topological sort on the graph
-- 3. Return the sorted list of mods
local function sortMods(mods)
    logger:trace('Sorting mods', utils.keys(mods))
    local graph = {}
    for modId, mod in pairs(mods) do
        graph[modId] = {
            before = {},
        }
    end
    logger:trace('Graph generated', graph)
    for modId, mod in pairs(mods) do
        for i, before in ipairs(mod.load_before or {}) do -- load_before is a list of mod ids, if its nil, use an empty table to avoid a crash
            if not graph[before] then
                logger:error('Mod ', mod.id, ' has a load_before field that references a non-existent mod: ', before)
                return nil
            end
            graph[modId].before[before] = true  -- we set to true just because we want a table behaving like a set() instead of an array
        end
        for i, after in ipairs(mod.load_after or {}) do -- load_after is a list of mod ids
            -- load_after is there to ensure that a mod is loaded after another mod
            -- this is equivalent to the other mod being loaded before the current mod
            -- so we add an edge from the other mod to the current mod
            if not graph[after] then
                logger:error('Mod ', mod.id, ' has a load_after field that references a non-existent mod: ', after)
                return nil
            end
            graph[after].before[modId] = true  -- we set to true just because we want a table behaving like a set() instead of an array
        end
    end
    logger:trace('Graph nodes and edges', graph)
    local sorted = {}
    local visited = {}
    local function visit(node)
        logger:trace("Visiting node ", node)
        if visited[node] == "permanent" then
            logger:trace("Node ", node, " already visited")
            return true
        end
        if visited[node] == "temporary" then
            logger:error('Mod ', node, ' has a circular dependency')
            return false
        end
        visited[node] = "temporary"
        for other, _ in pairs(graph[node].before) do
            if not visit(other) then
                return false
            end
        end
        table.insert(sorted, node)
        logger:trace("Inserted node ", node, " in sorted list", sorted)
        logger:trace("Marking node ", node, " as visited")
        visited[node] = "permanent"
        return true
    end
    logger:trace("Starting to visit nodes")
    for node, _ in pairs(graph) do
        if not visited[node] then
            visit(node)
        end
    end
    local sortedMods = {}
    local modCount = #sorted
    -- we need to keep the mapping between the mod id and the mod object
    -- to do so, mod order will be guaranteed through an order(int) field on the mod object
    for i, modId in ipairs(sorted) do
        -- sorted is actually sorted in reverse order
        -- to make the mod ordering work we need to reverse the order
        local mod = mods[modId]
        mod.order = modCount - i
        sortedMods[modId] = mod
    end
    logger:trace("Built sorted mods", utils.keys(sortedMods))
    return sortedMods
end

return {
    logger = logger,
    mods = mods,
    apis = apis,
    isModPresent = isModPresent,
    RESULT = RESULT,
    is_loaded = is_loaded,
    _VERSION = _VERSION,
    console = console,
    toggleMod = toggleMod,
    sortMods = sortMods,
    callModCallbacksIfExists = callModCallbacksIfExists,
}