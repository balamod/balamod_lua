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
    callModCallbacksIfExists = callModCallbacksIfExists,
}