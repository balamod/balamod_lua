return {
    name = "luarun",
    short_description = "Run lua code in the context of the game.",
    usage = "luarun <lua_code>",
    on_call = function(console, args)
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
    on_complete = function (console, current_arg)
        return nil
    end
}
