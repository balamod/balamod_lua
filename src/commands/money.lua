return {
    name = "money",
    short_description = "Changes the player's money.",
    usage = "Usage: money <add|remove|set> <amount>",
    on_call = function(console, args)
        if args[1] and args[2] then
            local amount = tonumber(args[2])
            if amount then
                if args[1] == "add" then
                    ease_dollars(amount, true)
                    console.logger:info("Added " .. amount .. " money to the player")
                elseif args[1] == "remove" then
                    ease_dollars(-amount, true)
                    console.logger:info("Removed " .. amount .. " money from the player")
                elseif args[1] == "set" then
                    local currentMoney = G.GAME.dollars
                    local diff = amount - currentMoney
                    ease_dollars(diff, true)
                    console.logger:info("Set player money to " .. amount)
                else
                    console.logger:error("Invalid operation, use add, remove or set")
                end
            else
                console.logger:error("Invalid amount")
                return false
            end
        else
            console.logger:warn("Usage: money <add/remove/set> <amount>")
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