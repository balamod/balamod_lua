-- API to add decks to Balatro

local utils = require("utils")
local logging = require("logging")
local logger = logging.getLogger("deck")
local math = require("math")


local _MODULE = {}
_MODULE._VERSION = "1.0.0"
local decks = {}
local GAME_BACKS = utils.copyTable(G.P_CENTER_POOLS.Back, true) -- copy the original table

local function getNextOrder()
    local latestOrder = utils.reduce(
        G.P_CENTER_POOLS.Back,
        function(acc, deck)
            return math.max(acc, deck.order or 1)
        end,
        1
    )
    return latestOrder + 1
end

local function computeDeckOrders()
    local latestOrder = utils.reduce(
        GAME_BACKS
        function(acc, deck)
            return math.max(acc, deck.order or 1)
        end,
        1
    )
    for deck_id, deck in pairs(decks) do
        deck.order = i + latestOrder
    end
end

local function add(deck_id, deck)
    deck.key = deck_id
    decks[deck_id] = deck
    computeDeckOrders()
    G.P_CENTERS[deck_id] = decks[deck_id]
    table.insert(G.P_CENTER_POOLS.Back, deck)
    table.sort(self.P_CENTER_POOLS["Back"], function (a, b) return (a.order - (a.unlocked and 100 or 0)) < (b.order - (b.unlocked and 100 or 0)) end)
end

local function remove(deck_id)
    G.P_CENTERS[deck_id] = nil
    decks[deck_id] = nil
    for i, pool_deck in ipairs(G.P_CENTER_POOLS.Back) do
        if pool_deck.key == deck_id then
            table.remove(G.P_CENTER_POOLS.Back, i)
            break
        end
    end
end

-- local function getDeckAPI()
--     local DeckApi = {
--         decks = {},
--         order = 17,
--     }

--     function DeckApi:create(id, name)
--         local deck = {
--             name = name,
--             config = {},
--             discovered = true,
--             unlocked = true,
--             -- In theory `pos` and `set` set the back of the deck from the atlas
--             set = "Back",
--             pos =   {x=0,y=0},
--             order = self.order,
--             stake = 1,
--         }

--         function deck:setConfig(option_name, option_value)
--             self.config[option_name] = option_value
--             return self
--         end

--         function deck:addCard(card)
--             if self.config.cards == nil then
--                 self.config.cards = {}
--             end
--             table.insert(self.config.cards, card)
--             return self
--         end

--         function deck:addCards(cards)
--             for _, card in ipairs(cards) do
--                 self:addCard(card)
--             end
--             return self
--         end

--         function deck:setCards(cards)
--             self.config.cards = cards
--             return self
--         end

--         function deck:stringify()
--             local str = "Deck: " .. self.name .. " with " .. #self.cards .. " cards"
--             for _, card in ipairs(self.cards) do
--                 str = str .. "\n" .. card:stringify()
--             end
--             return str
--         end
--         self.decks[id] = deck
--         self.order = self.order + 1  -- increment order
--         return deck
--     end

--     function DeckApi:hookInto()
--         local toReplace = [[
--             if args.challenge and args.challenge.decks then
--                 _de = args.challenge.deck
--             end
--         ]]
--         local replacement = [[
--             if args.challenge and args.challenge.decks then
--                 _de = args.challenge.deck
--             end
--             if self.GAME.starting_params.cards then
--                 card_protos = self.GAME.starting_params.cards
--             end
--         ]]
--         inject("game.lua", "Game:start_run", toReplace, replacement)
--         toReplace = [[
--             if self.effect.config.reroll_discount then
--                 G.GAME.starting_params.reroll_cost = G.GAME.starting_params.reroll_cost - self.effect.config.reroll_discount
--             end
--         ]]
--         replacement = [[
--             if self.effect.config.reroll_discount then
--                 G.GAME.starting_params.reroll_cost = G.GAME.starting_params.reroll_cost - self.effect.config.reroll_discount
--             end
--             if self.effect.config.cards then
--                 G.GAME.starting_params.cards = self.effect.config.cards
--             end
--         ]]
--         inject("back.lua", "Back:apply_to_run", toReplace, replacement)

--         for deck_id, deck in ipairs(self.decks) do
--             G.P_CENTERS[deck_id] = deck
--             table.insert(G.P_CENTER_POOLS.Back, deck)
--         end
--     end

--     function DeckApi:hookOut()
--         local toReplace = [[
--             if args.challenge and args.challenge.decks then
--                 _de = args.challenge.deck
--             end
--             if self.GAME.starting_params.cards then
--                 card_protos = self.GAME.starting_params.cards
--             end
--         ]]
--         local replacement = [[
--             if args.challenge and args.challenge.decks then
--                 _de = args.challenge.deck
--             end
--         ]]
--         inject("game.lua", "Game:start_run", toReplace, replacement)
--         toReplace = [[
--             if self.effect.config.reroll_discount then
--                 G.GAME.starting_params.reroll_cost = G.GAME.starting_params.reroll_cost - self.effect.config.reroll_discount
--             end
--             if self.effect.config.cards then
--                 G.GAME.starting_params.cards = self.effect.config.cards
--             end
--         ]]
--         replacement = [[
--             if self.effect.config.reroll_discount then
--                 G.GAME.starting_params.reroll_cost = G.GAME.starting_params.reroll_cost - self.effect.config.reroll_discount
--             end
--         ]]
--         inject("back.lua", "Back:apply_to_run", toReplace, replacement)

--         for deck_id, deck in ipairs(G.P_CENTERS) do
--             if self.decks[deck_id] == nil then
--                 -- deck has been removed
--                 G.P_CENTERS[deck_id] = nil
--             end
--         end
--     end

--     return DeckApi
-- end

-- DeckApi = getDeckAPI()

_MODULE.add = add
_MODULE.remove = remove
return _MODULE
