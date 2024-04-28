local _MODULE = {
    _VERSION = "0.1.0",
    is_mac = love.system.getOS() == "OS X",
    is_windows = love.system.getOS() == "Windows",
    is_linux = love.system.getOS() == "Linux",
    is_mobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS",
    is_desktop = love.system.getOS() == "OS X" or love.system.getOS() == "Windows" or love.system.getOS() == "Linux",
    is_android = love.system.getOS() == "Android",
    is_ios = love.system.getOS() == "iOS",
}

--- Strip the path off a path+filename.
-- @param pathname string: A path+name, such as "/a/b/c"
-- or "\a\b\c".
-- @return string: The filename without its path, such as "c".
local function baseName(pathname)
    assert(type(pathname) == "string")

    local base = pathname:match(".*[/\\]([^/\\]*)")
    return base or pathname
 end

 --- Strip the name off a path+filename.
 -- @param pathname string: A path+name, such as "/a/b/c".
 -- @return string: The filename without its path, such as "/a/b/".
 -- For entries such as "/a/b/", "/a/" is returned. If there are
 -- no directory separators in input, "" is returned.
 local function dirName(pathname)
    assert(type(pathname) == "string")

    return (pathname:gsub("/*$", ""):match("(.*/)[^/]*")) or ""
 end

 local function stripBaseDir(pathname)
    return pathname:gsub("^[^/]*/", "")
 end

_MODULE.baseName = baseName
_MODULE.dirName = dirName
_MODULE.stripBaseDir = stripBaseDir

return _MODULE
