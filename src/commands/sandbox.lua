return {
    name = "sandbox",
    short_description = "Open the game's sandbox scene.",
    usage = "Usage: sandbox",
    on_call = function(console, args)
        G:sandbox()
        return true
    end,
    on_complete = function (console, current_arg)
        return nil
    end
}
