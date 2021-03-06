--- === plugins.core.tangent.manager.named ===
---
--- Provides common functions for 'named' Tangent nodes
---
--- Tables with `named` in it's metatable chain will have `name` methods added
--- as described below.

local require = require

local tools             = require("cp.tools")
local x                 = require("cp.web.xml")

local match             = string.match


local named = {}
named.mt = {}

local id = {}

-- makeStringTangentFriendly(value) -> none
-- Function
-- Removes any illegal characters from the value
--
-- Parameters:
--  * value - The string you want to process
--
-- Returns:
--  * A string that's valid for Tangent's panels
local function makeStringTangentFriendly(value)
    --------------------------------------------------------------------------------
    -- Replace "&"" with "and"
    --------------------------------------------------------------------------------
    value = string.gsub(value, "&", "and")

    local result = ""

    for i = 1, #value do
        local letter = value:sub(i,i)
        local byte = string.byte(letter)
        if byte >= 32 and byte <= 126 then
            result = result .. letter
        --else
            --log.df("Illegal Character: %s", letter)
        end
    end
    result = tools.trim(result)
    if #result == 0 then
        result = nil
    end
    return result
end

-- getNames(self, create) -> table
-- Function
-- Gets a table of names.
--
-- Parameters:
-- * self - The named module.
-- * create - A boolean.
--
-- Returns:
--  * Names as table.
local function getNames(self, create)
    local names = rawget(self, id)
    if not names and create then
        names = {}
        rawset(self,id, names)
    end
    return names
end

--- plugins.core.tangent.manager.named:name(value) -> string | self
--- Method
--- Gets or sets the full name.
---
--- Parameters:
--- * value - The new name value.
---
--- Returns:
--- * `self`
local function name(self, value)
    if value ~= nil then
        local names = getNames(self, true)
        names.name = value
        return self
    else
        local names = getNames(self)
        return names and names.name
    end
end

--- plugins.core.tangent.manager.named:nameX(value) -> string | self
--- Method
--- Sets the name `X`, where `X` is a number as defined when the `named` was created.
---
--- Parameters:
--- * value - The new name value.
---
--- Returns:
--- * The current value, or `self` if a new value was provided.
named.mt.__index = function(_, key)
    if key == "name" then
        return name
    else
        local i = match(key, "name([0-9]+)")
        if i then
            i = tonumber(i)

            return function(source, value)
                if value ~= nil then
                    local names = getNames(source, true)
                    names[i] = value:sub(1, i)
                    return source
                else
                    local names = getNames(source)
                    return names and names[i]
                end
            end
        end
    end
    return nil
end

--- plugins.core.tangent.manager.named.xml(thing) -> cp.web.xml
--- Function
--- Returns the `xml` configuration for the Action.
---
--- Parameters:
--- * thing     - The thing to retrieve the names from.
---
--- Returns:
--- * The `xml` for the Action.
function named.xml(self)
    return x(function()
        local result = x()
        local names = getNames(self)

        if names then
            local theName = makeStringTangentFriendly(names.name)
            if theName then
                result(x.Name(theName))
            end
            for i,v in pairs(names) do
                if type(i) == "number" and v then
                    theName = makeStringTangentFriendly(v)
                    if theName then
                        result(x["Name"..i](theName))
                    end
                end
            end
        end
        return result
    end)
end

--- plugins.core.tangent.manager.named.is(thing) -> boolean
--- Function
--- Check if the `thing` is a `named` table.
---
--- Parameters:
--- * thing     - The thing to check.
---
--- Returns:
--- * `true` if it is `named.
function named.is(thing)
    return thing ~= nil and (thing == named.mt or named.is(getmetatable(thing)))
end

local function assignMetatable(target)
    local mt = getmetatable(target)
    if not mt then
        setmetatable(target, named.mt)
    else
        assignMetatable(mt)
    end
    return target
end

named.__call = function(_, target)
    return assignMetatable(target or {})
end
setmetatable(named, named)

named.names = getNames

return named
