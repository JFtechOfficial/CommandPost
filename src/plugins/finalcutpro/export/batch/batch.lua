--- === plugins.finalcutpro.export.batch ===
---
--- Batch Export Plugin

local require = require

local log           = require("hs.logger").new("batch")

local fnutils       = require("hs.fnutils")
local fs            = require("hs.fs")
local image         = require("hs.image")

local compressor    = require("cp.apple.compressor")
local config        = require("cp.config")
local destinations  = require("cp.apple.finalcutpro.export.destinations")
local dialog        = require("cp.dialog")
local Do            = require("cp.rx.go.Do")
local fcp           = require("cp.apple.finalcutpro")
local html          = require("cp.web.html")
local i18n          = require("cp.i18n")
local just          = require("cp.just")
local tools         = require("cp.tools")

local insert        = table.insert

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

--- plugins.finalcutpro.export.batch.DEFAULT_CUSTOM_FILENAME -> string
--- Constant
--- Default Custom Filename
mod.DEFAULT_CUSTOM_FILENAME = i18n("batchExport")

-- plugins.finalcutpro.export.batch._existingClipNames -> table
-- Variable
-- Table of existing clip names.
mod._existingClipNames = {}

-- plugins.finalcutpro.export.batch._clips -> table
-- Variable
-- Table of clips to batch export.
mod._clips = {}

-- plugins.finalcutpro.export.batch._nextID -> number
-- Variable
-- Next available ID for building the UI.
mod._nextID = 0

--- plugins.finalcutpro.export.batch.replaceExistingFiles <cp.prop: boolean>
--- Field
--- Defines whether or not a Batch Export should Replace Existing Files.
mod.replaceExistingFiles = config.prop("batchExportReplaceExistingFiles", false)

--- plugins.finalcutpro.export.batch.useCustomFilename <cp.prop: boolean>
--- Field
--- Defines whether or not the Batch Export tool should override the clipname with a custom filename.
mod.useCustomFilename = config.prop("batchExportOverrideClipnameWithCustomFilename", false)

--- plugins.finalcutpro.export.batch.customFilename <cp.prop: string>
--- Field
--- Custom Filename for Batch Export.
mod.customFilename = config.prop("batchExportCustomFilename", mod.DEFAULT_CUSTOM_FILENAME)

--- plugins.finalcutpro.export.batch.ignoreMissingEffects <cp.prop: boolean>
--- Field
--- Defines whether or not a Batch Export should Ignore Missing Effects.
mod.ignoreMissingEffects = config.prop("batchExportIgnoreMissingEffects", false)

--- plugins.finalcutpro.export.batch.ignoreInvalidCaptions <cp.prop: boolean>
--- Field
--- Defines whether or not a Batch Export should Ignore Invalid Captions.
mod.ignoreInvalidCaptions = config.prop("batchExportIgnoreInvalidCaptions", false)

--- plugins.finalcutpro.export.batch.ignoreProxies <cp.prop: boolean>
--- Field
--- Defines whether or not a Batch Export should Ignore Proxies.
mod.ignoreProxies = config.prop("batchExportIgnoreProxies", false)

--- plugins.finalcutpro.export.batch.sendTimelineClipsToCompressor(clips) -> boolean
--- Function
--- Send Timeline Clips to Compressor.
---
--- Parameters:
---  * clips - table of selected Clips
---
--- Returns:
---  * `true` if successful otherwise `false`
function mod.sendTimelineClipsToCompressor(clips)

    --------------------------------------------------------------------------------
    -- Launch Compressor:
    --------------------------------------------------------------------------------
    local result
    if not compressor:isRunning() then
        result = just.doUntil(function()
            compressor:launch()
            return compressor:isFrontmost()
        end, 10, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to Launch Compressor.")
            return false
        end
    end

    --------------------------------------------------------------------------------
    -- Make sure Final Cut Pro is Active:
    --------------------------------------------------------------------------------
    result = just.doUntil(function()
        fcp:launch()
        return fcp:isFrontmost()
    end, 10, 0.1)
    if not result then
        dialog.displayErrorMessage("Failed to switch back to Final Cut Pro.")
        return false
    end

    --------------------------------------------------------------------------------
    -- Make sure the Timeline is focussed:
    --------------------------------------------------------------------------------
    result = just.doUntil(function()
        fcp:timeline():doFocus(true):Now()
        return fcp:timeline():isFocused()
    end, 10, 0.1)
    if not result then
        dialog.displayErrorMessage("Failed to focus on timeline.")
        return false
    end

    --------------------------------------------------------------------------------
    -- Process each clip individually:
    --------------------------------------------------------------------------------
    local playhead = fcp:timeline():playhead()
    local timelineContents = fcp:timeline():contents()
    for _,clip in tools.spairs(clips, function(t,a,b) return t[a]:attributeValue("AXValueDescription") < t[b]:attributeValue("AXValueDescription") end) do

        --------------------------------------------------------------------------------
        -- Make sure Final Cut Pro is Active:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            fcp:launch()
            return fcp:isFrontmost()
        end, 10, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to switch back to Final Cut Pro.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Make sure the Timeline is focussed:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            fcp:timeline():doFocus(true):Now()
            return fcp:timeline():isFocused()
        end, 10, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to focus on timeline.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Get Start Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            timelineContents:selectClip(clip)
            local selectedClips = timelineContents:selectedClipsUI()
            return selectedClips and #selectedClips == 1 and selectedClips[1] == clip
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to select clip during start timecode phase.")
            return false
        end
        if not fcp:selectMenu({"Mark", "Go to", "Range Start"}) then
            dialog.displayErrorMessage("Could not trigger 'Range Start'.")
            return false
        end
        local startTimecode = playhead:timecode()
        if not startTimecode then
            dialog.displayErrorMessage("Could not get start timecode for clip.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Get End Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            timelineContents:selectClip(clip)
            local selectedClips = timelineContents:selectedClipsUI()
            return selectedClips and #selectedClips == 1 and selectedClips[1] == clip
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to select clip during end timecode phase.")
            return false
        end
        if not fcp:selectMenu({"Mark", "Go to", "Range End"}) then
            dialog.displayErrorMessage("Could not trigger 'Range End'.")
            return false
        end
        local endTimecode = playhead:timecode()
        if not endTimecode then
            dialog.displayErrorMessage("Could not get end timecode for clip.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Set Start Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            return playhead:timecode(startTimecode) == startTimecode
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage(string.format("Failed to goto start timecode (%s).", startTimecode))
            return false
        end
        if not fcp:selectMenu({"Mark", "Set Range Start"}) then
            dialog.displayErrorMessage("Could not trigger 'Set Range Start'.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Set End Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            return playhead:timecode(endTimecode) == endTimecode
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage(string.format("Failed to goto end timecode (%s).", endTimecode))
            return false
        end
        if not fcp:selectMenu({"Mark", "Set Range End"}) then
            dialog.displayErrorMessage("Could not trigger 'Set Range End'.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Make sure the Timeline is focussed:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            fcp:timeline():doFocus(true):Now()
            return fcp:timeline():isFocused()
        end, 10, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to focus on timeline.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Trigger Export:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            return fcp:selectMenu({"File", "Send to Compressor"}) == true
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Could not trigger 'Send to Compressor'.")
            return false
        end

    end
    return true

end

--- plugins.finalcutpro.export.batch.batchExportTimelineClips(clips) -> boolean
--- Function
--- Batch Export Timeline Clips
---
--- Parameters:
---  * clips - table of selected Clips
---
--- Returns:
---  * `true` if successful otherwise `false`
function mod.batchExportTimelineClips(clips)

    --------------------------------------------------------------------------------
    -- Setup:
    --------------------------------------------------------------------------------
    local result
    local firstTime             = true
    local exportPath            = mod.getDestinationFolder()
    local destinationPreset     = mod.getDestinationPreset()
    local errorFunction         = "\n\nError occurred in batchExportTimelineClips()."

    --------------------------------------------------------------------------------
    -- Process each clip individually:
    --------------------------------------------------------------------------------
    local playhead = fcp:timeline():playhead()
    local timelineContents = fcp:timeline():contents()
    for _,clip in tools.spairs(clips, function(t,a,b) return t[a]:attributeValue("AXValueDescription") < t[b]:attributeValue("AXValueDescription") end) do

        --------------------------------------------------------------------------------
        -- Make sure Final Cut Pro is Active:
        --------------------------------------------------------------------------------
        if not fcp:launch(10) then
            dialog.displayErrorMessage("Failed to switch back to Final Cut Pro." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Make sure the Timeline is focussed:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            fcp:timeline():doFocus(true):Now()
            return fcp:timeline():isFocused()
        end, 10, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to focus on timeline.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Select clip:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            timelineContents:selectClip(clip)
            local selectedClips = timelineContents:selectedClipsUI()
            return selectedClips and #selectedClips == 1 and selectedClips[1] == clip
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to select clip during start timecode phase." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Get Clip Name whilst we're at it:
        --------------------------------------------------------------------------------
        local clipName = clip:attributeValue("AXDescription")
        if not clipName then
            dialog.displayErrorMessage("Could not get clip name." .. errorFunction)
            return false
        end
        local columnPostion = string.find(clipName, ":")
        if columnPostion then
            clipName = string.sub(clipName, columnPostion + 1)
        end

        --------------------------------------------------------------------------------
        -- Get Start Timecode:
        --------------------------------------------------------------------------------
        if not fcp:selectMenu({"Mark", "Go to", "Range Start"}) then
            dialog.displayErrorMessage("Could not trigger 'Range Start'." .. errorFunction)
            return false
        end
        local startTimecode = playhead:timecode()
        if not startTimecode then
            dialog.displayErrorMessage("Could not get start timecode for clip." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Get End Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            timelineContents:selectClip(clip)
            local selectedClips = timelineContents:selectedClipsUI()
            return selectedClips and #selectedClips == 1 and selectedClips[1] == clip
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to select clip during end timecode phase." .. errorFunction)
            return false
        end
        if not fcp:selectMenu({"Mark", "Go to", "Range End"}) then
            dialog.displayErrorMessage("Could not trigger 'Range End'." .. errorFunction)
            return false
        end
        local endTimecode = playhead:timecode()
        if not endTimecode then
            dialog.displayErrorMessage("Could not get end timecode for clip." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Set Start Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            return playhead:timecode(startTimecode) == startTimecode
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage(string.format("Failed to goto start timecode (%s).", startTimecode))
            return false
        end
        if not fcp:selectMenu({"Mark", "Set Range Start"}) then
            dialog.displayErrorMessage("Could not trigger 'Set Range Start'." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Set End Timecode:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            return playhead:timecode(endTimecode) == endTimecode
        end, 5, 0.1)
        if not result then
            dialog.displayErrorMessage(string.format("Failed to goto end timecode (%s).", endTimecode))
            return false
        end
        if not fcp:selectMenu({"Mark", "Set Range End"}) then
            dialog.displayErrorMessage("Could not trigger 'Set Range End'." .. errorFunction)
            return false
        end

        --------------------------------------------------------------------------------
        -- Make sure the Timeline is focussed:
        --------------------------------------------------------------------------------
        result = just.doUntil(function()
            fcp:timeline():doFocus(true):Now()
            return fcp:timeline():isFocused()
        end, 10, 0.1)
        if not result then
            dialog.displayErrorMessage("Failed to focus on timeline.")
            return false
        end

        --------------------------------------------------------------------------------
        -- Trigger Export:
        --------------------------------------------------------------------------------
        local exportDialog = fcp:exportDialog()
        local errorMessage
        _, errorMessage = exportDialog:show(destinationPreset, mod.ignoreProxies(), mod.ignoreMissingEffects(), mod.ignoreInvalidCaptions())
        if errorMessage then
            return false
        end

        --------------------------------------------------------------------------------
        -- Press 'Next':
        --------------------------------------------------------------------------------
        exportDialog:pressNext()

        --------------------------------------------------------------------------------
        -- If 'Next' has been clicked (as opposed to 'Share'):
        --------------------------------------------------------------------------------
        local saveSheet = exportDialog:saveSheet()
        if exportDialog:isShowing() then

            --------------------------------------------------------------------------------
            -- Click 'Save' on the save sheet:
            --------------------------------------------------------------------------------
            if not just.doUntil(function() return saveSheet:isShowing() end) then
                dialog.displayErrorMessage("Failed to open the 'Save' window." .. errorFunction)
                return false
            end

            --------------------------------------------------------------------------------
            -- Set Custom Export Path (or Default to Desktop):
            --------------------------------------------------------------------------------
            if firstTime then
                saveSheet:setPath(exportPath)
                firstTime = false
            end

            --------------------------------------------------------------------------------
            -- Make sure we don't already have a clip with the same name in the batch:
            --------------------------------------------------------------------------------
            local filename = saveSheet:filename():getValue()
            if filename then
                local newFilename = clipName

                --------------------------------------------------------------------------------
                -- Inject Custom Filenames:
                --------------------------------------------------------------------------------
                local customFilename = mod.customFilename()
                local useCustomFilename = mod.useCustomFilename()
                if useCustomFilename and customFilename then
                    newFilename = customFilename
                end

                while fnutils.contains(mod._existingClipNames, newFilename) do
                    newFilename = tools.incrementFilename(newFilename)
                end
                if filename ~= newFilename then
                    saveSheet:filename():setValue(newFilename)
                end
                table.insert(mod._existingClipNames, newFilename)
            end

            --------------------------------------------------------------------------------
            -- Click 'Save' on the save sheet:
            --------------------------------------------------------------------------------
            saveSheet:pressSave()

        end

        --------------------------------------------------------------------------------
        -- Make sure Save Window is closed:
        --------------------------------------------------------------------------------
        while saveSheet:isShowing() do
            local replaceAlert = saveSheet:replaceAlert()
            if mod.replaceExistingFiles() and replaceAlert:isShowing() then
                replaceAlert:pressReplace()
            else
                replaceAlert:pressCancel()

                local originalFilename = saveSheet:filename():getValue()
                if originalFilename == nil then
                    dialog.displayErrorMessage("Failed to get the original Filename." .. errorFunction)
                    return false
                end

                local newFilename = tools.incrementFilename(originalFilename)

                saveSheet:filename():setValue(newFilename)
                saveSheet:pressSave()
            end
        end

    end
    -- reselect the original list of clips
    timelineContents:selectClips(clips)
    return true
end

mod.destinationPreset = config.prop("batchExportDestinationPreset")

--- plugins.finalcutpro.export.batch.changeExportDestinationPreset() -> none
--- Function
--- Change Export Destination Preset.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.changeExportDestinationPreset()
    Do(function()
        local destinationList, destinationListError = destinations.names()
        local currentPreset = mod.destinationPreset()

        if not destinationList then
            log.ef("Destination List Error: %s", destinationListError)
            destinationList = {}
        end

        if compressor.isInstalled() then
            insert(destinationList, 1, i18n("sendToCompressor"))
        end

        local result = dialog.displayChooseFromList(i18n("selectDestinationPreset"), destinationList, {currentPreset})

        if result and #result > 0 then
            mod.destinationPreset(result[1])
        end

        --------------------------------------------------------------------------------
        -- Refresh the Preferences:
        --------------------------------------------------------------------------------
        mod._bmMan.refresh()
    end):After(0)
end

--- plugins.finalcutpro.export.batch.changeExportDestinationFolder() -> none
--- Function
--- Change Export Destination Folder.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.changeExportDestinationFolder()
    Do(function()
        local result = dialog.displayChooseFolder(i18n("selectDestinationFolder"))
        if result ~= false then
            config.set("batchExportDestinationFolder", result)

            --------------------------------------------------------------------------------
            -- Refresh the Preferences:
            --------------------------------------------------------------------------------
            mod._bmMan.refresh()
        end
    end):After(0)
end

--- plugins.finalcutpro.export.batch.changeCustomFilename() -> none
--- Function
--- Change Custom Filename String.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.changeCustomFilename()
    Do(function()
        local result = mod.customFilename(dialog.displayTextBoxMessage(i18n("enterCustomFilename") .. ":", i18n("enterCustomFilenameError"), mod.customFilename(), function(value)
            if value and type("value") == "string" and value ~= tools.trim("") and tools.safeFilename(value, value) == value then
                return true
            else
                return false
            end
        end))
        if type(result) == "string" then
            mod.customFilename(result)
        end

        --------------------------------------------------------------------------------
        -- Refresh the Preferences:
        --------------------------------------------------------------------------------
        mod._bmMan.refresh()
    end):After(0)
end

--- plugins.finalcutpro.export.batch.getDestinationFolder() -> string
--- Function
--- Gets the destination folder path.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The destination folder path as a string.
function mod.getDestinationFolder()
    local batchExportDestinationFolder = config.get("batchExportDestinationFolder")
    local NSNavLastRootDirectory = fcp.preferences.NSNavLastRootDirectory
    local exportPath = os.getenv("HOME") .. "/Desktop"
    if batchExportDestinationFolder ~= nil then
         if tools.doesDirectoryExist(batchExportDestinationFolder) then
            exportPath = batchExportDestinationFolder
         end
    else
        if tools.doesDirectoryExist(NSNavLastRootDirectory) then
            exportPath = NSNavLastRootDirectory
        end
    end
    return exportPath and fs.pathToAbsolute(exportPath)
end

--- plugins.finalcutpro.export.batch.getDestinationFolder() -> string | nil
--- Function
--- Gets the destination preset.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The destination preset as a string, or `nil` if no preset is set.
function mod.getDestinationPreset()

    --------------------------------------------------------------------------------
    -- Get Destination Preset from Preferences:
    --------------------------------------------------------------------------------
    local destinationPreset = config.get("batchExportDestinationPreset")

    --------------------------------------------------------------------------------
    -- If it's "Send to Compressor" - make sure Compressor is installed:
    --------------------------------------------------------------------------------
    if destinationPreset == i18n("sendToCompressor") then
        if not compressor:isInstalled() then
            --log.df("Apple Compressor could not be detected.")
            destinationPreset = nil
            config.set("batchExportDestinationPreset", nil)
        end
    end

    --------------------------------------------------------------------------------
    -- If there's no existing destination, then try use the Default Destination:
    --------------------------------------------------------------------------------
    if destinationPreset == nil then
        local defaultItem = fcp:menu():findMenuUI({"File", "Share", function(menuItem)
            return menuItem:attributeValue("AXMenuItemCmdChar") ~= nil
        end})
        if defaultItem ~= nil then
            local title = defaultItem:attributeValue("AXTitle")
            if title then
                --log.df("Using Default Destination: '%s'", title)
                --------------------------------------------------------------------------------
                -- Remove the " (default)…" if it exists:
                --------------------------------------------------------------------------------
                if title:sub(-13) == " (default)…" then
                    title = title:sub(1, -14)
                end
                destinationPreset = title
            end
        end
    end

    --------------------------------------------------------------------------------
    -- If that fails, try the first item on the list:
    --------------------------------------------------------------------------------
    if destinationPreset == nil then
        local firstItem = fcp:menu():findMenuUI({"File", "Share", 1})
        if firstItem ~= nil then
            local title = firstItem:attributeValue("AXTitle")
            if title then
                --------------------------------------------------------------------------------
                -- Remove the "…" if it exists:
                --------------------------------------------------------------------------------
                if title:sub(-3) == "…" then
                    title = title:sub(1, -4)
                end
                destinationPreset = title
            end
        end
    end

    --------------------------------------------------------------------------------
    -- If that fails, try using Compressor if installed:
    --------------------------------------------------------------------------------
    if destinationPreset == nil then
        if compressor:isInstalled() then
            destinationPreset = i18n("sendToCompressor")
        end
    end

    return destinationPreset
end

--- plugins.finalcutpro.export.batch.batchExport() -> boolean
--- Function
--- Opens the Batch Export popup.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if successful otherwise `false`
function mod.batchExport()
    --------------------------------------------------------------------------------
    -- Make sure Final Cut Pro is Active:
    --------------------------------------------------------------------------------
    local result = just.doUntil(function()
        fcp:launch()
        return fcp:isFrontmost()
    end, 10, 0.1)
    if not result then
        dialog.displayErrorMessage("Failed to activate Final Cut Pro. Batch Export aborted.")
        return false
    end

    --------------------------------------------------------------------------------
    -- Reset Everything:
    --------------------------------------------------------------------------------
    mod._clips = nil
    mod._existingClipNames = nil
    mod._existingClipNames = {}

    --------------------------------------------------------------------------------
    -- Check if we have any currently-selected clips:
    --------------------------------------------------------------------------------
    local timelineContents = fcp:timeline():contents()
    local selectedClips = timelineContents:selectedClipsUI()

    if not selectedClips or #selectedClips == 0 then
        dialog.displayMessage(i18n("batchExportNoClipsInTimeline"))
        return
    end

    mod._clips = selectedClips
    mod._bmMan.show()
end

-- clipsToCountString(clips) -> string
-- Function
-- Calculates the numbers of clips supplied and returns the number as a formatted string.
--
-- Parameters:
--  * clips - A table of clips
--
-- Returns:
--  * A string.
local function clipsToCountString(clips)
    local countText = " "
    if clips and #clips > 1 then countText = " " .. tostring(#clips) .. " " end
    return countText
end

--- plugins.finalcutpro.export.batch.performBatchExport() -> none
--- Function
--- Performs the Browser Batch Export function.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.performBatchExport()
    Do(function()
        --------------------------------------------------------------------------------
        -- Hide the Window:
        --------------------------------------------------------------------------------
        mod._bmMan.hide()

        --------------------------------------------------------------------------------
        -- Export the clips:
        --------------------------------------------------------------------------------
        local result
        local destinationPreset = mod.getDestinationPreset()
        if destinationPreset == i18n("sendToCompressor") then
            result = mod.sendTimelineClipsToCompressor(mod._clips)
        else
            result = mod.batchExportTimelineClips(mod._clips)
        end

        --------------------------------------------------------------------------------
        -- Batch Export Complete:
        --------------------------------------------------------------------------------
        if result then
            dialog.displayMessage(i18n("batchExportComplete"), {i18n("done")})
        end
    end):After(0)
end

-- nextID() -> number
-- Function
-- Returns the next free ID.
--
-- Parameters:
--  * None
--
-- Returns:
--  * The next ID as a number.
local function nextID()
    mod._nextID = mod._nextID + 1
    return mod._nextID
end

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
    id              = "finalcutpro.export.batch",
    group           = "finalcutpro",
    dependencies    = {
        ["core.menu.manager"]                   = "manager",
        ["finalcutpro.menu.manager"]            = "menuManager",
        ["finalcutpro.commands"]                = "fcpxCmds",
        ["finalcutpro.export.batch.manager"]    = "batchExportManager",
    }
}

function plugin.init(deps)

    --------------------------------------------------------------------------------
    -- Create the Batch Export window:
    --------------------------------------------------------------------------------
    mod._bmMan = deps.batchExportManager
    local fcpPath = fcp:getPath() or ""

    --------------------------------------------------------------------------------
    -- Timeline Panel:
    --------------------------------------------------------------------------------
    mod._timelinePanel = mod._bmMan.addPanel({
        priority    = 2,
        id          = "timeline",
        label       = i18n("timeline"),
        image       = image.imageFromPath(tools.iconFallback(fcpPath .. "/Contents/Frameworks/Flexo.framework/Versions/A/Resources/FFMediaManagerCompoundClipIcon.png")),
        tooltip     = i18n("timeline"),
        height      = 620,
    })
        :addHeading(nextID(), i18n("batchExportFromTimeline"))
        :addParagraph(nextID(), function()
                local clipCount = mod._clips and #mod._clips or 0
                local clipCountString = clipsToCountString(mod._clips)
                local itemString = i18n("item", {count=clipCount})
                return i18n("finalCutProTimelineBatchExportMessage", {clipCountString=clipCountString, itemString=itemString})
            end)
        :addParagraph(nextID(), html.br())
        :addContent(nextID(), function()
                local destinationPreset = mod.getDestinationPreset()
                if destinationPreset == i18n("sendToCompressor") then
                    return html.p {class="uiItem", style="color:#3f9253; font-weight:bold;"} (i18n("changeDestinationFolderInCompressor"))
                else
                    local destinationFolder = mod.getDestinationFolder()
                    if destinationFolder then
                        return html.div {style="white-space: nowrap; overflow: hidden;"} (
                            html.p {class="uiItem", style="color:#5760e7; font-weight:bold;"} (destinationFolder)
                        )
                    else
                        return html.p {class="uiItem", style="color:#d1393e; font-weight:bold;"} (i18n("noDestinationFolderSelected"))
                    end
                end
            end)
        :addParagraph(nextID(), html.br())
        :addButton(nextID(),
            {
                width = 200,
                label = i18n("changeDestinationFolder"),
                onclick = function()
                    local destinationPreset = mod.getDestinationPreset()
                    if destinationPreset == i18n("sendToCompressor") then
                        compressor:launch()
                    else
                        mod.changeExportDestinationFolder()
                    end
                end
            })
        :addParagraph(nextID(), html.br())
        :addParagraph(nextID(), i18n("usingTheFollowingDestinationPreset") .. ":")
        :addParagraph(nextID(), html.br())
        :addContent(nextID(), function()
                local destinationPreset = mod.getDestinationPreset()
                if destinationPreset then
                    --------------------------------------------------------------------------------
                    -- Trim the "(default)…":
                    --------------------------------------------------------------------------------
                    local trimmedDestinationPreset = destinationPreset:match("(.*) %([^()]+%)…$")
                    if trimmedDestinationPreset then
                        destinationPreset = trimmedDestinationPreset
                    end
                    return html.div {style="white-space: nowrap; overflow: hidden;"} (
                        html.p {class="uiItem", style="color:#5760e7; font-weight:bold;"} (destinationPreset)
                    )
                else
                    return html.p {class="uiItem", style="color:#d1393e; font-weight:bold;"} (i18n("noDestinationPresetSelected"))
                end
            end)
        :addParagraph(nextID(), html.br())
        :addButton(nextID(),
            {
                width = 200,
                label = i18n("changeDestinationPreset"),
                onclick = mod.changeExportDestinationPreset
            })
        :addParagraph(nextID(), html.br())
        :addParagraph(nextID(), i18n("usingTheFollowingNamingConvention") .. ":")
        :addParagraph(nextID(), html.br())
        :addContent(nextID(), function()
                local useCustomFilename = mod.useCustomFilename()
                if useCustomFilename then
                    local customFilename = mod.customFilename() or mod.DEFAULT_CUSTOM_FILENAME
                    return [[<div style="white-space: nowrap; overflow: hidden;"><p class="uiItem" style="color:#5760e7; font-weight:bold;">]] .. customFilename .."</p></div>"
                else
                    return [[<p class="uiItem" style="color:#3f9253; font-weight:bold;">]] .. i18n("originalClipName") .. [[</p>]]
                end
            end, false)
        :addParagraph(nextID(), html.br())
        :addButton(nextID(),
            {
                width = 200,
                label = i18n("changeCustomFilename"),
                onclick = mod.changeCustomFilename,
            })
        :addHeading(nextID(), "Preferences")
        :addCheckbox(nextID(),
            {
                label = i18n("replaceExistingFiles"),
                onchange = function(_, params) mod.replaceExistingFiles(params.checked) end,
                checked = mod.replaceExistingFiles,
            })
        :addCheckbox(nextID(),
            {
                label = i18n("ignoreMissingEffects"),
                onchange = function(_, params) mod.ignoreMissingEffects(params.checked) end,
                checked = mod.ignoreMissingEffects,
            })
        :addCheckbox(nextID(),
            {
                label = i18n("ignoreProxies"),
                onchange = function(_, params) mod.ignoreProxies(params.checked) end,
                checked = mod.ignoreProxies,
            })
        :addCheckbox(nextID(),
            {
                label = i18n("ignoreInvalidCaptions"),
                onchange = function(_, params) mod.ignoreInvalidCaptions(params.checked) end,
                checked = mod.ignoreInvalidCaptions,
            })
        :addCheckbox(nextID(),
            {
                label = i18n("useCustomFilename"),
                onchange = function(_, params)
                    mod.useCustomFilename(params.checked)

                    --------------------------------------------------------------------------------
                    -- Refresh the Preferences:
                    --------------------------------------------------------------------------------
                    mod._bmMan.refresh()
                end,
                checked = mod.useCustomFilename,
            })
        :addParagraph(nextID(), html.br())
        :addButton(nextID(),
            {
                width = 200,
                label = i18n("performBatchExport"),
                onclick = function()
                    Do(function() mod.performBatchExport("timeline") end):After(0)
                end,
            })

    --------------------------------------------------------------------------------
    -- Add items to Menubar:
    --------------------------------------------------------------------------------
    local menuManager = deps.menuManager
    menuManager.timeline:addItems(1001, function()
        return {
            {
                title       = i18n("batchExportActiveTimeline"),
                fn          = function() mod.batchExport("timeline") end,
                disabled    = not fcp:isRunning()
            },
        }
    end)

    --------------------------------------------------------------------------------
    -- Commands:
    --------------------------------------------------------------------------------
    deps.fcpxCmds:add("cpBatchExportFromTimeline")
        :activatedBy():ctrl():option():cmd("e")
        :whenActivated(function() mod.batchExport("timeline") end)

    --------------------------------------------------------------------------------
    -- Return the module:
    --------------------------------------------------------------------------------
    return mod
end

return plugin
