local balamod = require('balamod')
local utils = require('utils')
local logging = require('logging')
local logger = logging.getLogger('i18n')

local _MODULE = {
    _VERSION = "1.0.0",
}

local function getModLocale(mod, locale)
    logger:debug("Getting locale for mod ", mod.id, " and locale ", locale)
    if not mod.enabled then
        -- do not inject disabled mods
        return nil
    end
    local modDir = 'mods/'..mod.id
    if not love.filesystem.getInfo(modDir, "directory") then
        logger:trace("Mod directory does not exist: ", modDir)
        return nil
    end
    local localeDir = modDir..'/localization'
    if not love.filesystem.getInfo(localeDir, "directory") then
        logger:trace("Locale directory does not exist: ", localeDir)
        return nil
    end
    local pathToLocale = localeDir..'/'..locale:lower()..'.json'
    if not love.filesystem.getInfo(pathToLocale, "file") then
        logger:trace("Locale file does not exist: ", pathToLocale)
        return getModLocale(mod, 'en-us')  -- try to fallback to the english locale
    end
    local json_locale = love.filesystem.read(pathToLocale)
    print(json_locale)
    local schema = love.filesystem.read("balamod/localization.schema.json")
    print(schema)
    if not schema then
        logger:error("Localization schema does not exist")
        return nil
    end
    local json_schema_result = balalib.validate_schema(schema, json_locale)
    print(json_schema_result)
    if json_locale ~= "valid" then
        logger:error("Invalid locale for mod ", mod.id, " and locale ", locale, ": ", json_schema_result)
        return nil
    end
    local modLocale = balalib.json_to_lua(json_locale)
    logger:info("Loaded locale for mod ", mod.id, " and locale ", locale, ": ", modLocale)
    return modLocale
end

local function inject()
    local localizations = {}
    for _, mod in pairs(balamod.mods) do
        local modLocale = getModLocale(mod, G.SETTINGS.language)
        if modLocale then
            logger:debug("Injecting locale for mod ", mod.id, ": ", modLocale)
            localizations = utils.mergeTables(localizations, modLocale, logger)
            logger:trace("Result:", localizations)
        end
    end
    G.localization = utils.mergeTables(G.localization, localizations, logger)
    logger:info("Injected locales: ", G.localization.misc.poker_hands)
end

_MODULE.getModLocale = getModLocale
_MODULE.inject = inject

return _MODULE
