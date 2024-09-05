local balamod = require('balamod')

local consumable = {}
consumable._VERSION = "0.5.0"
consumable.useEffects = {}
consumable.useConditions = {}
consumable.loc_vars = {}
consumable.consumables = {}
consumable.vanilla_sets = {"Tarot", "Planet", "Spectral", "Tarot_Planet", "Consumeables"}
consumable.modded_sets = {}
consumable.num_modded_sets = 0
consumable.tarot_loc_vars = {}
local function add(args)
    if not args.set then logger:error("consumable API: set REQUIRED when adding a consumable"); return end
    if not args.mod_id then logger:error("consumable API: mod_id REQUIRED when adding a consumable"); return end
    local id = args.id or "c_placeholder"..#G.P_CENTER_POOLS[args.set]+1
    local name = args.name or "Consumable Placeholder"
    local use_effect = args.use_effect or function(_) end
    local use_condition = args.use_condition or function(_) end
    local order = #G.P_CENTER_POOLS[args.set] + 1
    local unlocked = nil
    local discovered = nil
    if args.unlocked ~= nil then
        unlocked = args.unlocked
    else
        unlocked = true
    end
    if args.discovered ~= nil then
        discovered = args.discovered
    else
        discovered = true
    end
    local cost = args.cost or 4
    local pos = {x=0, y=0}
    local config = args.config or {}
    local desc = args.desc or {"Placeholder"}
    local alerted = args.alerted or true
    local loc_vars = args.loc_vars or function(_) return {} end
    local set = args.set
    local unlock_condition = args.unlock_condition or nil
    local unlock_condition_desc = args.unlock_condition_desc or {"LOCKED"}
    local no_pool_flag = args.no_pool_flag or nil
    local yes_pool_flag = args.yes_pool_flag or nil
    
    local tooltip = nil
    if args.tooltip then
        if #args.tooltip == 0 then
            logger:error("consumable api: " .. id .. ": invalid tooltip format")
            return false
        end
        for i=1, #args.tooltip do
            if (not args.tooltip[i].name and not args.tooltip[i].text) then
                logger:error("consumable api: " .. id .. ": invalid tooltip format")
                return false
            end
            local temp = args.tooltip
            if not args.tooltip[i].text_parsed then
                temp.text_parsed = {}
                for _, line in ipairs(args.tooltip[i].text) do
                    temp.text_parsed[#temp.text_parsed+1] = loc_parse_string(line)
                end
            end
            G.localization.descriptions.Other[id.."tooltip"..tostring(i)] = temp
        end
        tooltip = args.tooltip
    end
    local extra = args.extra or nil

    local newConsumable = {
        balamod = {
            mod_id = args.mod_id,
            key = id,
            asset_key = args.mod_id .. "_" .. id,
            tooltip = tooltip,
            extra = extra,
        },
        key = id,
        order = order,
        unlocked = unlocked,
        discovered = discovered,
        cost = cost,
        consumable = true,
        name = name,
        pos = pos,
        set = args.set,
        effect = "",
        cost_mult = 1.0,
        config = config,
        no_pool_flag = no_pool_flag,
        yes_pool_flag = yes_pool_flag,
        unlock_condition = unlock_condition,
        alerted = alerted,
        atlas = args.mod_id .. "_" .. id,
    }

    local save_indices = {}

    --add it to all the game tables
    if not G.P_CENTER_POOLS[args.set] then
        logger:error(args.set.." does not exist, did you create it?")
        return false
    end
    table.insert(G.P_CENTER_POOLS[args.set], newConsumable)
    table.insert(G.P_CENTER_POOLS["Consumeables"], newConsumable)
    if args.set == "Tarot" or args.set == "Planet" then
        table.insert(G.P_CENTER_POOLS["Tarot_Planet"], newConsumable)
        save_indices["Tarot_Planet"] = #G.P_CENTER_POOLS["Tarot_Planet"]
    end
    G.P_CENTERS[id] = newConsumable

    --save indices to remove
    save_indices["Consumeables"] = #G.P_CENTER_POOLS["Consumeables"]
    save_indices[args.set] = #G.P_CENTER_POOLS[args.set]

    --add name + description to the localization object
    local consumableText = {name=name, text=desc, unlock=unlock_condition_desc, text_parsed={}, name_parsed={}, unlock_parsed={}}
    for _, line in ipairs(desc) do
        consumableText.text_parsed[#consumableText.text_parsed+1] = loc_parse_string(line)
    end
    for _, line in ipairs(type(consumableText.name) == 'table' and consumableText.name or {newConsumable.name}) do
        consumableText.name_parsed[#consumableText.name_parsed+1] = loc_parse_string(line)
    end
    for _, line in ipairs(consumableText.unlock) do
        consumableText.unlock_parsed[#consumableText.unlock_parsed+1] = loc_parse_string(line)
    end
    if not G.localization.descriptions[args.set] then
        G.localization.descriptions[args.set] = {}
    end
    G.localization.descriptions[args.set][id] = consumableText

    -- consumeable effects
    consumable.useEffects[id] = use_effect
    consumable.useConditions[id] = use_condition

    -- consumeable loc vars
    consumable.loc_vars[id] = loc_vars
    if args.set == "Tarot" then
        consumable.tarot_loc_vars[id] = loc_vars
    end

    -- indices for removal
    consumable.consumables[id] = {indices=save_indices, set=args.set}

    return consumable, consumableText
end
local function remove(id)
    for k, v in pairs(consumable.consumables[id].indices) do
        G.P_CENTER_POOLS[k][v] = nil
    end
    G.P_CENTERS[id] = nil
    G.localization.descriptions[consumable.consumables[id].set][id] = nil
    consumable.useConditions[id] = nil
    consumable.useEffects[id] = nil
    consumable.loc_vars[id] = nil
    consumable.consumables[id] = nil
end
local function newSet(args)
    if not args.name then 
        logger:error("Please enter a name for the set")
        return false
    end
    for k,v in pairs(consumable.modded_sets) do
        if k == args.name then
            logger:error(args.name .. " already exists.")
            return false
        end
    end
    local name = args.name
    local collection_h = args.collection_height or 2
    local collection_w = args.collection_width or 5
    local colour = args.colour or G.C.BLACK
    local temp = {
        name = name,
        width = collection_w,
        height = collection_h,
        colour = colour,
    }
    consumable.modded_sets[name] = temp
    G.P_CENTER_POOLS[name] = {}
    consumable.num_modded_sets = consumable.num_modded_sets + 1
    G.C.SECONDARY_SET[name] = colour
    G.localization.misc.dictionary["k_"..string.lower(name)] = name
end
local _MODULE = consumable

_MODULE.add = add
_MODULE.remove = remove
_MODULE.newSet = newSet

return _MODULE