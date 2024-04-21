local saveDir = love.filesystem.getSaveDirectory()
local balamodDir = saveDir .. "/balamod"
package.path = package.path .. ";" .. balamodDir .. "/?.lua"
if love.system.getOS() == "Windows" or love.system.getOS() == "Linux" then
    package.cpath = package.cpath .. ";" .. balamodDir .. "/?.dll"
elseif love.system.getOS() == "OS X" then
    package.cpath = package.cpath .. ";" .. balamodDir .. "/?.so" .. ";" .. balamodDir .. "/?.dll"
end

require('patches')
