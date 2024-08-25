local balamod = require("balamod")
local logging = require('logging')
local utils = require('utils')
local logger = logging.getLogger('patches')

local function mergeTables(table1, table2)
    local result = utils.copyTable(table1, true)
    for k, v in pairs(table2) do
        if type(v) == "table" and type(result[k]) == "table" then
            local isDictTable = all(map(utils.keys(result), function(k)
                return type(k) ~= "number"
            end))
            if isDictTable then
                result[k] = mergeTables(result[k], v)
            else
                -- we assume it's an array table
                for _, v2 in ipairs(v) do
                    table.insert(result[k], v2)
                end
            end
        else
            result[k] = v
        end
    end
    return result
end

logger:info("Loading mods from folders ")
for _, mod in ipairs(balalib.get_local_mods()) do
    if mod ~= nil then
        local modPath = "mods/" .. mod.id .. "/main"
        local status, mod_table = pcall(require, modPath)
        if not status then
            logger:warn("Failed to load mod: ", modPath, " error: ", mod)
        end

        balamod.mods[mod.id] = mergeTables(mod, mod_table)
        logger:info("Loaded mod: ", mod.id)
    end
end

local status, sortedMods = pcall(balalib.sort_mods, balamod.mods)
if not status then
    logger:warn("Failed to sort mods: ", sortedMods)
else
    balamod.mods = sortedMods
end

logger:info("Mods: ", utils.keys(mods))
local status, message = pcall(balamod.callModCallbacksIfExists, balamod.mods, "on_pre_load", true)
if not status then
    logger:warn("Failed to preload mods: ", message)
end

require('balamod_back')
require('balamod_love')
require('balamod_card')
require('balamod_game')
require('balamod_uidefs')
require('balamod_misc_functions')
require('mod_menu')
