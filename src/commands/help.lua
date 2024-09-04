return {
    name = "help",
    short_description = "Prints a list of available commands.",
    usage = "Usage: help <command>",
    on_call = function(console)
        console.logger:print("Available commands:")
        for name, cmd in pairs(console.commands) do
            if cmd.desc then
                console.logger:print(name .. ": " .. cmd.desc)
            end
        end
        return true
    end,
    on_complete = function(console, current_arg)
        local completions = {}
        for name, _ in pairs(console.commands) do
            if name:find(current_arg, 1, true) == 1 then
                table.insert(completions, name)
            end
        end
        return completions
    end
}