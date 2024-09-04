return {
    name = "shortcuts",
    short_description = "Prints a list of available shortcuts.",
    usage = "Usage: shortcuts",
    on_call = function(console)
        console.logger:print("Available shortcuts:")
        console.logger:print("F2: Open/Close the console")
        console.logger:print("F1: Restart the game")
        console.logger:print("F4: Toggle debug mode")
        if platform.is_mac then
            console.logger:print("Cmd+C: Copy the current command to the clipboard.")
            console.logger:print("Cmd+Shift+C: Copies all messages to the clipboard")
            console.logger:print("Cmd+V: Paste the clipboard into the current command")
        else
            console.logger:print("Ctrl+C: Copy the current command to the clipboard.")
            console.logger:print("Ctrl+Shift+C: Copies all messages to the clipboard")
            console.logger:print("Ctrl+V: Paste the clipboard into the current command")
        end
        return true
    end,
    on_complete = function(console, current_arg)
        return nil
    end
}