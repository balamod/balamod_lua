return {
    name = "history",
    short_description = "Prints the command history.",
    usage = "Usage: history",
    on_call = function(console)
        console.logger:print("Command history:")
        for i, cmd in ipairs(console.command_history) do
            console.logger:print(i .. ": " .. cmd)
        end
        return true
    end,
    on_complete = function(console, current_arg)
        return nil
    end
}
