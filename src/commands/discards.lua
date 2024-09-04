return {
    name = "discards",
    short_description = "Changes the player's available discards.",
    usage = "discards <add|remove|set> <amount>",
    on_call = function(console, args)
        if args[1] and args[2] then
            local amount = tonumber(args[2])
            if amount then
                if args[1] == "add" then
                    ease_discard(amount, true)
                    console.logger:info("Added " .. amount .. " discards to the player")
                elseif args[1] == "remove" then
                    ease_discard(-amount, true)
                    console.logger:info("Removed " .. amount .. " discards from the player")
                elseif args[1] == "set" then
                    local currentDiscards = G.GAME.current_round.discards_left
                    local diff = amount - currentDiscards
                    ease_discard(diff, true)
                    console.logger:info("Set player discards to " .. amount)
                else
                    console.logger:error("Invalid operation, use add, remove or set")
                    return false
                end
            else
                console.logger:error("Invalid amount")
                return false
            end
        else
            console.logger:warn("Usage: discards <add/remove/set> <amount>")
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
