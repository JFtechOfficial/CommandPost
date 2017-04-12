--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                 P R E F E R E N C E S    P L U G I N                       --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === core.preferences.advanced ===
---
--- Advanced Preferences Panel.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log				= require("hs.logger").new("prefadv")

local console			= require("hs.console")
local ipc				= require("hs.ipc")

local config			= require("cp.config")
local fcp				= require("cp.finalcutpro")
local dialog			= require("cp.dialog")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

--- core.preferences.advanced.resetSettings() -> none
--- Function
--- Resets all of the CommandPost Preferences to their default values.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.resetSettings()

	local finalCutProRunning = fcp:isRunning()

	local resetMessage = i18n("trashPreferences")
	if finalCutProRunning then
		resetMessage = resetMessage .. "\n\n" .. i18n("adminPasswordRequiredAndRestart")
	else
		resetMessage = resetMessage .. "\n\n" .. i18n("adminPasswordRequired")
	end

	if not dialog.displayYesNoQuestion(resetMessage) then
		return
	end

	--------------------------------------------------------------------------------
	-- Remove Hacks Shortcut in Final Cut Pro:
	--------------------------------------------------------------------------------
	mod.hacksShortcuts.disableHacksShortcuts()

	--------------------------------------------------------------------------------
	-- Trash all Script Settings:
	--------------------------------------------------------------------------------
	config.reset()

	--------------------------------------------------------------------------------
	-- Restart Final Cut Pro if running:
	--------------------------------------------------------------------------------
	if finalCutProRunning then
		if not fcp:restart() then
			--------------------------------------------------------------------------------
			-- Failed to restart Final Cut Pro:
			--------------------------------------------------------------------------------
			dialog.displayMessage(i18n("restartFinalCutProFailed"))
		end
	end

	--------------------------------------------------------------------------------
	-- Reload Hammerspoon:
	--------------------------------------------------------------------------------
	console.clearConsole()
	hs.reload()

end

--- core.preferences.advanced.toggleDeveloperMode() -> none
--- Function
--- Toggles the Developer Mode.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.toggleDeveloperMode()
	local debugMode = config.get("debugMode")
	config.set("debugMode", not debugMode)
	console.clearConsole()
	hs.reload()
end

--- core.preferences.advanced.getDeveloperMode() -> boolean
--- Function
--- Returns the Developer Mode status.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if developer mode is enabled otherwise `false`.
function mod.getDeveloperMode()
	return config.get("debugMode")
end

--- core.preferences.advanced.openErrorLog() -> none
--- Function
--- Opens the Error Log
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.openErrorLog()
	hs.openConsole()
end

--
-- Get Command Line Tool Title:
--
local function getCommandLineToolTitle()
	local cliStatus = ipc.cliStatus()
	if cliStatus then
		return i18n("uninstall")
	else
		return i18n("install")
	end
end

--- core.preferences.advanced.toggleCommandLineTool() -> none
--- Function
--- Toggles the Command Line Tool
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function mod.toggleCommandLineTool()

	local cliStatus = ipc.cliStatus()
	if cliStatus then
		--log.df("Uninstalling Command Line Tool")
		ipc.cliUninstall()
	else
		--log.df("Installing Command Line Tool")
		ipc.cliInstall()
	end

	local newCliStatus = ipc.cliStatus()
	if cliStatus == newCliStatus then
		if cliStatus then
			dialog.displayMessage(i18n("cliUninstallError"))
		else
			dialog.displayMessage(i18n("cliInstallError"))
		end
	else
		mod.manager.injectScript([[
			document.getElementById("commandLineTool").innerHTML = "]] .. getCommandLineToolTitle() .. [["
		]])
	end

end

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
	id				= "core.preferences.advanced",
	group			= "core",
	dependencies	= {
		["core.preferences.panels.advanced"]	= "advanced",
		["core.preferences.manager"]			= "manager",
	}
}
--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)

	mod.manager = deps.manager

	--------------------------------------------------------------------------------
	-- Setup General Preferences Panel:
	--------------------------------------------------------------------------------
	deps.advanced:addHeading(60, function()
		return { title = i18n("developer") .. ":" }
	end)

	:addCheckbox(61, function()
		return { title = i18n("enableDeveloperMode"),	fn = mod.toggleDeveloperMode, checked = mod.getDeveloperMode() }
	end)

	:addHeading(62, function()
		return { title = "<br />" .. i18n("advanced") .. ":" }
	end)

	:addButton(63, function()
		return { title = i18n("openErrorLog"),	fn = mod.openErrorLog }
	end, 150)

	:addButton(64, function()
		return { title = i18n("trashPreferences"),	fn = mod.resetSettings }
	end, 150)

	:addHeading(70, function()
		return { title = "<br />" .. i18n("commandLineTool") .. [[:</h3>
			<p>]] .. i18n("commandLineToolDescription") .. [[</p><h3>
		]] }
	end)

	:addButton(75, function()
		return { title = getCommandLineToolTitle(),	fn = mod.toggleCommandLineTool }
	end, 150, "commandLineTool", "commandLineTool")

end

return plugin