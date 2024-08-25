-- Downloaded from https://github.com/ignacio/StackTracePlus/raw/master/src/StackTracePlus.lua
-- Injected into balamod libraries through the CI pipeline, on release of balamod LUA libraries
local STP = require("StackTracePlus")

-- Register the balamod functions as known functions and tables

local balamod = require('balamod')

STP.add_known_table(balamod, "balamod.lua")
-- STP.add_known_function(balamod.isModPresent, "balamod.lua::isModPresent")
-- STP.add_known_function(balamod.toggleMod, "balamod.lua::toggleMod")
-- STP.add_known_function(balamod.callModCallbacksIfExists, "balamod.lua::callModCallbacksIfExists")

local balalib = require('balalib')
STP.add_known_table(balalib, "balalib.lua")

local utils = require('utils')
STP.add_known_table(utils, "utils.lua")

local logger = require('logging')
STP.add_known_table(logger, "logging.lua")

local console = require('console')
STP.add_known_table(console, "console.lua")

local assets = require('assets')
STP.add_known_table(assets, "assets.lua")

local challenge = require('challenge')
STP.add_known_table(challenge, "challenge.lua")

local consumable = require('consumable')
STP.add_known_table(consumable, "consumable.lua")

local deck = require('deck')
STP.add_known_table(deck, "deck.lua")

local joker = require('joker')
STP.add_known_table(joker, "joker.lua")

local localization = require('localization')
STP.add_known_table(localization, "localization.lua")

local platform = require('platform')
STP.add_known_table(platform, "platform.lua")

local seal = require('seal')
STP.add_known_table(seal, "seal.lua")

-- End of registering known functions and tables

return STP
