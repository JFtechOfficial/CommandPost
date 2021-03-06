--- === plugins.finder.pasteboard.history ===
---
--- Adds text pasteboard history actions to the Search Console.

local require           = require

--local log               = require "hs.logger".new "pbHistory"

local eventtap          = require "hs.eventtap"
local pasteboard        = require "hs.pasteboard"
local timer             = require "hs.timer"

local config            = require "cp.config"
local i18n              = require "cp.i18n"
local json              = require "cp.json"

local doEvery           = timer.doEvery
local keyStroke         = eventtap.keyStroke

local mod = {}

-- HISTORY_SIZE -> number
-- Constant
-- The number of history items to keep.
local HISTORY_SIZE = 50

-- DISALLOWED_UTI -> table
-- Constant
-- A table of disallowed UTI values as found on http://nspasteboard.org/
local DISALLOWED_UTI = {
    "com.agilebits.onepassword",
    "com.typeit4me.clipping",
    "de.petermaurer.TransientPasteboardType",
    "org.nspasteboard.AutoGeneratedType",
    "org.nspasteboard.ConcealedType",
    "org.nspasteboard.TransientType",
    "Pasteboard generator type"
}

-- mod.cached -> table
-- Variable
-- Cached pasteboard history
mod.cached = {}

--- plugins.finder.pasteboard.history.history <cp.prop: table>
--- Field
--- Contains the pasteboard history.
mod.history = json.prop(config.userConfigRootPath, "Pasteboard History", "Text Pasteboard History.cpPasteboard", {})

local plugin = {
    id              = "finder.pasteboard.history",
    group           = "finder",
    dependencies    = {
        ["core.action.manager"] = "actionmanager",
    }
}

function plugin.init(deps)

    --------------------------------------------------------------------------------
    -- Restore history from JSON:
    --------------------------------------------------------------------------------
    mod.cached = mod.history()

    --------------------------------------------------------------------------------
    -- Setup Handler:
    --------------------------------------------------------------------------------
    local actionmanager = deps.actionmanager
    mod._handler = actionmanager.addHandler("global_pasteboard", "global")
        :onChoices(function(choices)
            for _, item in pairs(mod.cached) do
                if item.text then
                    choices
                        :add(item.text)
                        :subText(i18n("pasteboardHistory"))
                        :params({
                            text = item.text,
                        })
                        :id("global_pasteboard_" .. item.text)
                end
            end
        end)
        :onExecute(function(action)
            pasteboard.setContents(action.text)
            timer.doAfter(0.1, function()
                keyStroke({"cmd"}, "v")
            end)
        end)
        :onActionId(function(params)
            return "global_menuactions_" .. params.text
        end)

    --------------------------------------------------------------------------------
    -- Setup Pasteboard Timer:
    --------------------------------------------------------------------------------
    mod.timer = doEvery(1, function()
        --------------------------------------------------------------------------------
        -- Get pasteboard contents:
        --------------------------------------------------------------------------------
        local contents = pasteboard.getContents()

        --------------------------------------------------------------------------------
        -- Don't process if nothing's changed:
        --------------------------------------------------------------------------------
        if not contents or contents == mod.lastContents then
            return
        end
        mod.lastContents = contents

        --------------------------------------------------------------------------------
        -- Disallow certain UTI's:
        --------------------------------------------------------------------------------
        local currentTypes = pasteboard.allContentTypes()[1]
        for _,aType in pairs(currentTypes) do
            for _,uti in pairs(DISALLOWED_UTI) do
                if uti == aType then
                    return
                end
            end
        end

        --------------------------------------------------------------------------------
        -- Ignore if already in the history:
        --------------------------------------------------------------------------------
        for _, v in pairs(mod.cached) do
            if v.text == contents then
                return
            end
        end

        --------------------------------------------------------------------------------
        -- Add item to cache:
        --------------------------------------------------------------------------------
        local item = {}
        item["text"] = contents
        item["uti"] = currentTypes[1]
        table.insert(mod.cached, item)

        --------------------------------------------------------------------------------
        -- Limit the history size:
        --------------------------------------------------------------------------------
        if #mod.cached > HISTORY_SIZE then
            table.remove(mod.cached, 1)
        end

        --------------------------------------------------------------------------------
        -- Save to disk:
        --------------------------------------------------------------------------------
        mod.history(mod.cached)

        --------------------------------------------------------------------------------
        -- Reset handler:
        --------------------------------------------------------------------------------
        mod._handler:reset(true)
    end):start()

    return mod
end

return plugin
