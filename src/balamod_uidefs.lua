local game_create_UIBox_main_menu_buttons = create_UIBox_main_menu_buttons
local game_create_UIBox_your_collection_tarots = create_UIBox_your_collection_tarots
local game_create_UIBox_your_collection_spectrals = create_UIBox_your_collection_spectrals
local game_create_UIBox_your_collection = create_UIBox_your_collection

local consumable = require("consumable")

function create_UIBox_main_menu_buttons()
    local t = game_create_UIBox_main_menu_buttons()
    local modBtn = {
        n = G.UIT.R,
        config = {
            align = "cm",
            padding = 0.2,
            r = 0.1,
            emboss = 0.1,
            colour = G.C.L_BLACK,
        },
        nodes = {
            {
                n = G.UIT.R,
                config = {
                    align = "cm",
                    padding = 0.15,
                    minw = 1,
                    r = 0.1,
                    hover = true,
                    colour = G.C.PURPLE,
                    button = 'show_mods',
                    shadow = true,
                },
                nodes = {
                    {
                        n = G.UIT.T,
                        config = {
                            text = "MODS",
                            scale = 0.6,
                            colour = G.C.UI.TEXT_LIGHT,
                            shadow = true,
                        },
                    },
                },
            },
        },
    }

    local insertIndex = #t.nodes[2].nodes
    if not G.F_ENGLISH_ONLY then
        insertIndex = insertIndex - 1
    end
    table.insert(t.nodes[2].nodes, insertIndex, modBtn)
    return t
end

function create_UIBox_your_collection_tarots()
    -- change tarot options to properly add new pages
    local tarot_options = {}
    for i = 1, math.ceil(#G.P_CENTER_POOLS.Tarot/11) do
        table.insert(tarot_options, localize('k_page')..' '..tostring(i)..'/'..tostring(math.ceil(#G.P_CENTER_POOLS.Tarot/11)))
    end
    
    local old_return = game_create_UIBox_your_collection_tarots()
    -- remove old option cycle dynatext object
    old_return.nodes[1].nodes[1].nodes[1].nodes[2].nodes[1].nodes[2].nodes[1].nodes[2].nodes[1].nodes[1].nodes[1].config.object:remove()
    -- create new option cycle
    old_return.nodes[1].nodes[1].nodes[1].nodes[2] = create_option_cycle({options = tarot_options, w = 4.5, cycle_shoulders = true, opt_callback = 'your_collection_tarot_page', focus_args = {snap_to = true, nav = 'wide'},current_option = 1, colour = G.C.RED, no_pips = true})
    return old_return 
end

function create_UIBox_your_collection_spectrals()
    local spectral_options = {}
    for i = 1, math.ceil(#G.P_CENTER_POOLS.Spectral/9) do
      table.insert(spectral_options, localize('k_page')..' '..tostring(i)..'/'..tostring(math.ceil(#G.P_CENTER_POOLS.Spectral/9)))
    end

    local old_return = game_create_UIBox_your_collection_spectrals()
    -- remove old option cycle dynatext object
    old_return.nodes[1].nodes[1].nodes[1].nodes[2].nodes[1].nodes[2].nodes[1].nodes[2].nodes[1].nodes[1].nodes[1].config.object:remove()
    -- create new option cycle
    old_return.nodes[1].nodes[1].nodes[1].nodes[2] = create_option_cycle({options = spectral_options, w = 4.5, cycle_shoulders = true, opt_callback = 'your_collection_spectral_page', focus_args = {snap_to = true, nav = 'wide'},current_option = 1, colour = G.C.RED, no_pips = true})
    return old_return 
end
  
function create_UIBox_your_collection()
    local old_return = game_create_UIBox_your_collection()
    -- if there are more than 3 modded consumable types, use a separate menu instead
    if consumable.num_modded_sets > 3 then
        table.insert(old_return.nodes[1].nodes[1].nodes[1].nodes[1].nodes[4].nodes[2].nodes, UIBox_button({
            button = 'modded_consumable_types_list', label={ "See more consumables" }, minw=4, id='modded_consumable_types_list',colour = G.C.BLACK
        }))
        return old_return
    end
    -- otherwise, put new buttons below vanilla consumable sets
    for k,v in pairs(consumable.modded_sets) do
        table.insert(old_return.nodes[1].nodes[1].nodes[1].nodes[1].nodes[4].nodes[2].nodes, UIBox_button({
            button = 'modded_consumable_collection', 
            label={ v.name.." Cards" }, 
            minw=4, 
            id=v,
            colour = v.colour, 
            count = {tally=#G.P_CENTER_POOLS[v.name], of=#G.P_CENTER_POOLS[v.name]}
        }))
    end
    return old_return
end

function create_UIBox_modded_consumable_collection(data)
    local deck_tables = {}

    G.your_collection = {}
    for h=1, data.height do
        G.your_collection[h] = CardArea(
            G.ROOM.T.x + 0.2*G.ROOM.T.w/2, G.ROOM.T.h,
            data.width*G.CARD_W,
            0.95*G.CARD_H,
            {card_limit = data.width, type = 'title', highlight_limit = 0, collection = true}
        )
        table.insert(deck_tables,
        {n=G.UIT.R, config={align="cm", padding=0.07, no_fill = true}, nodes={
            {n=G.UIT.O, config={object=G.your_collection[h]}}
        }}
        )
    end

    local consumable_options = {}
    for i=1, math.max(math.ceil(#G.P_CENTER_POOLS[data.name]/(data.width*data.height)), 1) do
        table.insert(consumable_options, localize('k_page').." "..tostring(i)..'/'..tostring(math.max(math.ceil(#G.P_CENTER_POOLS[data.name]/(data.width*data.height)), 1)))
    end
    for w=1, data.width do
        for h=1, data.height do
            local center = G.P_CENTER_POOLS[data.name][w+(h-1)*data.width]
            if center then
                local card = Card(G.your_collection[h].T.x + G.your_collection[h].T.w/2, G.your_collection[h].T.y, G.CARD_W, G.CARD_H, nil, center)
                G.your_collection[h]:emplace(card)
            end
        end
    end

    INIT_COLLECTION_CARD_ALERTS()

    local t = create_UIBox_generic_options({ back_func = 'your_collection', contents = {
        {n=G.UIT.R, config={align = "cm", r = 0.1, colour = G.C.BLACK, emboss = 0.05}, nodes = deck_tables},
        {n=G.UIT.R, config={align = "cm"}, nodes={
            create_option_cycle({options=consumable_options, w = 4.5, cycle_shoulders = true, opt_callback = "modded_consumable_collection_page", current_option = 1, colour = G.C.RED, no_pips = true, ref_table=data, focus_args = {snap_to = true, nav = 'wide', }})
        }}
    }})
    return t
end

-- for consumable sets
G.FUNCS.modded_consumable_collection = function(e)
    local data = e.config.id -- hacky way to pass data, but it works
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu{
        definition = create_UIBox_modded_consumable_collection(data),
    }
end

G.FUNCS.modded_consumable_collection_page = function(args)
    if not args or not args.cycle_config then return end
    for k,v in pairs(args) do
        logger:info(k, v)
    end
    local width, height = #G.your_collection[1].cards, #G.your_collection
    for j=1, #G.your_collection do
        for i=#G.your_collection[j].cards, 1, -1 do
            local card = G.your_collection[j]:remove_card(G.your_collection[j].cards[i])
            card:remove()
            card = nil
        end
    end
    for i=1, width do
        for j=1, height do
            local center = G.P_CENTER_POOLS[args.cycle_config.ref_table.name][i+(j-1)*width + (width*#G.your_collection*(args.cycle_config.current_option-1))]
            if not center then break end
            local card = Card(G.your_collection[j].T.x + G.your_collection[j].T.w/2, G.your_collection[j].T.y, G.CARD_W, G.CARD_H, G.P_CARDS.empty, center)
            G.your_collection[j]:emplace(card)
        end
    end
    INIT_COLLECTION_CARD_ALERTS()
end
