return {
    name = "give",
    short_description = "Gives the player an item.",
    usage = "Usage: give <item> [amount]",
    on_call = function(console, args)
        local id = args[1]
        local c1 = nil
        if string.sub(id, 1, 2) == "j_" then
            c1 = create_card(nil, G.jokers, nil, 1, true, false, id, nil)
        else
            c1 = create_card(nil, G.consumeables, nil, 1, true, false, id, nil)
        end
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.1,
            func = function()
                c1:add_to_deck()
                if string.sub(id, 1, 2) == "j_" then
                    G.jokers:emplace(c1)
                else
                    G.consumeables:emplace(c1)
                end

                G.CONTROLLER:save_cardarea_focus('jokers')
                G.CONTROLLER:recall_cardarea_focus('jokers')
                return true
            end
        }))
        return true
    end,
    on_complete = function(console, current_arg)
        local ret = {}
        for k,_ in pairs(G.P_CENTERS) do
            if string.find(k, current_arg) == 1 then
                table.insert(ret, k)
            end
        end
        return ret
    end
}