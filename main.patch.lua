--Search Source, then the save directory
love.filesystem.setIdentity(love.filesystem.getIdentity(),true)
-- Load the game
local gameMain, size = love.filesystem.read("main.lua")
local newMain, _ = load(gameMain)
if newMain then
    pcall(newMain)
end
--Search Save directory, then the Source Directory
love.filesystem.setIdentity(love.filesystem.getIdentity(),false)

local saveDir = love.filesystem.getSaveDirectory()
local balamodDir = saveDir .. "/balamod"
local modsDir = saveDir .. "/mods"
package.path = package.path .. ";" .. balamodDir .. "/?.lua" .. ";" .. modsDir .. "/?.lua"
if love.system.getOS() == "Windows" then
    package.cpath = package.cpath .. ";" .. balamodDir .. "/?.dll"
elseif love.system.getOS() == "OS X" then
    package.cpath = package.cpath .. ";" .. balamodDir .. "/?.dylib"
elseif love.system.getOS() == "Linux" then
    package.cpath = package.cpath .. ";" .. balamodDir .. "/?.so"
end

require('patches')
