local logging = require("logging")

return {
    name = "clear",
    short_description = "Clears the console.",
    usage = "Usage: clear",
    on_call = function(console)
        logging.clearLogs()
        return true
    end,
    on_complete = function(console, current_arg)
        return nil
    end
}