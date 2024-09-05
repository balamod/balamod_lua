return {
    name = "exit",
    short_description = "Close the console.",
    usage = "Usage: exit",
    on_call = function(console)
        console:toggle()
        return true
    end,
    on_complete = function(console, current_arg)
        return nil
    end
}
