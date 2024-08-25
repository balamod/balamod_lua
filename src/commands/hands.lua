return {
    name = "hands",
    short_description = "Changes the player's available hands.",
    usage = "hands <add|remove|set> <amount>",
    on_call = function(console, args)
        if args[1] and args[2] then
            local amount = tonumber(args[2])
            if amount then
                if args[1] == "add" then
                    ease_hands_played(amount, true)
                    console.logger:info("Added " .. amount .. " hands to the player")
                elseif args[1] == "remove" then
                    ease_hands_played(-amount, true)
                    console.logger:info("Removed " .. amount .. " hands from the player")
                elseif args[1] == "set" then
                    local currentHands = G.GAME.current_round.hands_left
                    local diff = amount - currentHands
                    ease_hands_played(diff, true)
                    console.logger:info("Set player hands to " .. amount)
                else
                    console.logger:error("Invalid operation, use add, remove or set")
                    return false
                end
            else
                console.logger:error("Invalid amount")
                return false
            end
        else
            console.logger:warn("Usage: hands <add/remove/set> <amount>")
            return false
        end
        return true
    end,
    on_complete = function (console, current_arg)
        local subcommands = {"add", "remove", "set"}
        for i, v in ipairs(subcommands) do
            if v:find(current_arg, 1, true) == 1 then
                return {v}
            end
        end
        return nil
    end
}