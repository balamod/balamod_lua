local balamod = require("balamod")

return {
    name = "luamod",
    short_description = "Hot reloads a balamod mod.",
    usage = "luamod <mod_id>",
    on_call = function(console, args)
        if args[1] then
            local modId = args[1]
            if isModPresent(modId) then
                local mod = balamod.mods[modId]
                if mod.enabled and mod.on_disable and type(mod.on_disable) == "function" then
                    local success, result = pcall(mod.on_disable)
                    if not success then
                        console.logger:error("Error disabling mod: " .. modId)
                        console.logger:error(result)
                        return false
                    end
                end
                mod = loadMod(modId)
                balamod.mods[modId] = mod

                local sort_status, sortedMods = pcall(balalib.sort_mods, balamod.mods)
                if not sort_status then
                    logger:warn("Failed to sort mods: ", sortedMods)
                else
                    balamod.mods = sortedMods
                end
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
    on_complete = function (console, current_arg)
        local completions = {}
        for modId, _ in pairs(balamod.mods) do
            if modId:find(current_arg, 1, true) == 1 then
                table.insert(completions, modId)
            end
        end
        return completions
    end
}