--- === cp.apple.finalcutpro.prefs.PlaybackPanel ===
---
--- Playback Panel Module.

--local log             = require "hs.logger".new "playbackPanel"

--local inspect         = require "hs.inspect"

local require           = require

local axutils           = require "cp.ui.axutils"
local just              = require "cp.just"
local CheckBox          = require "cp.ui.CheckBox"

local Panel             = require "cp.apple.finalcutpro.prefs.Panel"


local PlaybackPanel = {}
PlaybackPanel.mt = setmetatable({}, Panel.mt)
PlaybackPanel.mt.__index = PlaybackPanel.mt

-- TODO: Add documentation
function PlaybackPanel.new(parent)
    return Panel.new(parent, "PEPlaybackPreferenceName", PlaybackPanel.mt)
end

-- TODO: Add documentation
function PlaybackPanel.mt:parent()
    return self._parent
end

function PlaybackPanel.mt:app()
    return self:parent():app()
end

-- TODO: Add documentation
function PlaybackPanel.mt:show()
    local parent = self:parent()
    -- show the parent.
    if parent:show():isShowing() then
        -- get the toolbar UI
        local panel = just.doUntil(function() return self:UI() end)
        if panel then
            panel:doPress()
            just.doUntil(function() return self:isShowing() end)
        end
    end
    return self
end

function PlaybackPanel.mt:hide()
    return self:parent():hide()
end

function PlaybackPanel.mt:createMulticamOptimizedMedia()
    if not self._createOptimizedMedia then
        self._createOptimizedMedia = CheckBox(self, function()
            return axutils.childFromTop(axutils.childrenWithRole(self:contentsUI(), "AXCheckBox"), 2)
        end)
    end
    return self._createOptimizedMedia
end

function PlaybackPanel.mt:backgroundRender()
    if not self._backgroundRender then
        self._backgroundRender = CheckBox(self, function()
            return axutils.childFromTop(axutils.childrenWithRole(self:contentsUI(), "AXCheckBox"), 1)
        end)
    end
    return self._backgroundRender
end

return PlaybackPanel
