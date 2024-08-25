balalib = require("balalib") -- to be accessible by the mods
local logging = require('logging')
local platform = require('platform')
local math = require('math')
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
is_loaded = false
local _VERSION = require('balamod_version')

local function isModPresent(modId)
    if not modId then
        logger:error('Mod id is nil')
        return false
    end
    return mods[modId] ~= nil
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

if not love.filesystem.getInfo("mods", "directory") then -- Create mods folder if it doesn't exist
    love.filesystem.createDirectory("mods")
end

if not love.filesystem.getInfo("logs", "directory") then -- Create logs folder if it doesn't exist
    love.filesystem.createDirectory("logs")
end

return {
    logger = logger,
    mods = mods,
    isModPresent = isModPresent,
    is_loaded = is_loaded,
    _VERSION = _VERSION,
    toggleMod = toggleMod,
    callModCallbacksIfExists = callModCallbacksIfExists,
}
