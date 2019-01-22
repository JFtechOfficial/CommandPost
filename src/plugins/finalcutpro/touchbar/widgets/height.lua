--- === plugins.finalcutpro.touchbar.widgets.height ===
---
--- Final Cut Pro Zoom Control Widget for Touch Bar.

local require           = require

local log               = require("hs.logger").new("heightWidget")

local canvas            = require("hs.canvas")

local fcp               = require("cp.apple.finalcutpro")
local i18n              = require("cp.i18n")

local touchbar          = require("hs._asm.undocumented.touchbar")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

--- plugins.finalcutpro.touchbar.widgets.height.widget() -> `hs._asm.undocumented.touchbar.item`
--- Function
--- The Widget
---
--- Parameters:
---  * None
---
--- Returns:
---  * A `hs._asm.undocumented.touchbar.item`
function mod.widget()

    local canvasWidth, canvasHeight = 250, 30

    local widgetCanvas = canvas.new{x = 0, y = 0, h = 30, w = canvasWidth}

    widgetCanvas[#widgetCanvas + 1] = {
        id               = "background",
        type             = "rectangle",
        action           = "strokeAndFill",
        strokeColor      = { white = 1 },
        fillColor        = { hex = "#1d1d1d", alpha = 1 },
        roundedRectRadii = { xRadius = 5, yRadius = 5 },
    }

    widgetCanvas[#widgetCanvas + 1] = {
        id                  = "startLine",
        type                = "segments",
        coordinates         = {
            {x = 0, y = canvasHeight/2},
            {x = canvasWidth / 2, y = canvasHeight/2} },
        action              = "stroke",
        strokeColor         = { hex = "#5051e7", alpha = 1 },
        strokeWidth         = 1.5,
    }

    widgetCanvas[#widgetCanvas + 1] = {
        id                  = "endLine",
        type                = "segments",
        coordinates         = {
            {x = canvasWidth / 2, y = canvasHeight/2},
            {x = canvasWidth, y = canvasHeight/2} },
        action              = "stroke",
        strokeColor         = { white = 1.0 },
        strokeWidth         = 1.5,
    }

    widgetCanvas[#widgetCanvas + 1] = {
        id                  = "circle",
        type                = "circle",
        radius              = 10,
        action              = "strokeAndFill",
        fillColor           = { hex = "#414141", alpha = 1 },
        strokeWidth         = 1.5,
        center              = { x = canvasWidth / 2, y = canvasHeight / 2 },
    }

    widgetCanvas:canvasMouseEvents(true, true, false, true)
        :mouseCallback(function(o,m,i,x,y)

            if not fcp.isFrontmost() or not fcp:libraries():isShowing() then return end

            widgetCanvas.circle.center = {
                x = x,
                y = canvasHeight / 2,
            }

            widgetCanvas.startLine.coordinates = {
                {x = 0, y = canvasHeight/2},
                {x = x, y = canvasHeight/2},
            }

            widgetCanvas.endLine.coordinates = {
                { x = x, y = canvasHeight / 2 },
                { x = canvasWidth, y = canvasHeight / 2 },
            }

            if m == "mouseDown" or m == "mouseMove" then
                fcp:libraries():appearanceAndFiltering():show():clipHeight():setValue(x/(canvasWidth/10))
            elseif m == "mouseUp" then
                fcp:libraries():appearanceAndFiltering():hide()
            end
    end)

    mod.item = touchbar.item.newCanvas(widgetCanvas, "browserHeightSlider")
        :canvasClickColor{ alpha = 0.0 }

    return mod.item

end

--- plugins.finalcutpro.touchbar.widgets.height.init() -> nil
--- Function
--- Initialise the module.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.init(deps)

    local params = {
        group = "fcpx",
        text = i18n("browserHeightSlider"),
        subText = i18n("browserHeightSliderDescription"),
        item = mod.widget,
    }
    deps.manager.widgets:new("browserHeightSlider", params)

    return mod

end

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
    id              = "finalcutpro.touchbar.widgets.height",
    group           = "finalcutpro",
    dependencies    = {
        ["core.touchbar.manager"] = "manager",
    }
}

function plugin.init(deps)
    if touchbar.supported() then
        return mod.init(deps)
    end
end

return plugin
