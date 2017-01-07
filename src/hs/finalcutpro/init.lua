--- hs.finalcutpro.App
---
--- Represents the Final Cut Pro X application, providing functions that allow different tasks to be accomplished.
---
--- Author: David Peterson (david@randombits.org)
---

--- Standard Modules
local application								= require("hs.application")
local ax 										= require("hs._asm.axuielement")
local osascript 								= require("hs.osascript")
local just										= require("hs.just")
local fs 										= require("hs.fs")
local plist										= require("hs.plist")

local inspect									= require("hs.inspect")
local log										= require("hs.logger").new("fcpxapp")

local axutils									= require("hs.finalcutpro.axutils")

--- Local Modules
local MenuBar									= require("hs.finalcutpro.MenuBar")
local PreferencesWindow							= require("hs.finalcutpro.prefs.PreferencesWindow")
local PrimaryWindow								= require("hs.finalcutpro.main.PrimaryWindow")
local SecondaryWindow							= require("hs.finalcutpro.main.SecondaryWindow")
local FullScreenWindow							= require("hs.finalcutpro.main.FullScreenWindow")
local Timeline									= require("hs.finalcutpro.main.Timeline")
local Browser									= require("hs.finalcutpro.main.Browser")
local Viewer									= require("hs.finalcutpro.main.Viewer")
local CommandEditor								= require("hs.finalcutpro.cmd.CommandEditor")
local ExportDialog								= require("hs.finalcutpro.export.ExportDialog")
local MediaImport								= require("hs.finalcutpro.import.MediaImport")

--- The App module
local App = {}

--- Constants
App.BUNDLE_ID 									= "com.apple.FinalCut"
App.PASTEBOARD_UTI 								= "com.apple.flexo.proFFPasteboardUTI"

App.PREFS_PLIST_PATH 							= "~/Library/Preferences/com.apple.FinalCut.plist"

App.SUPPORTED_LANGUAGES 						= {"de", "en", "es", "fr", "ja", "zh_CN"}
App.FLEXO_LANGUAGES								= {"de", "en", "es_419", "es", "fr", "id", "ja", "ms", "vi", "zh_CN"}


--- doesDirectoryExist() -> boolean
--- Function
--- Returns true if Directory Exists else False
---
--- Parameters:
---  * None
---
--- Returns:
---  * True is Directory Exists otherwise False
---
local function doesDirectoryExist(path)
    local attr = fs.attributes(path)
    return attr and attr.mode == 'directory'
end


--- hs.finalcutpro.App:new() -> App
--- Function
--- Creates a new App instance representing Final Cut Pro
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * True is successful otherwise Nil
---
function App:new()
	o = {}
	setmetatable(o, self)
	self.__index = self
	return o
end

--- hs.finalcutpro.App:application() -> hs.application
--- Function
--- Returns the hs.application for Final Cut Pro X.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * The hs.application, or nil if the application is not installed.
---
function App:application()
	local result = application.applicationsForBundleID(App.BUNDLE_ID) or nil
	-- If there is at least one copy installed, return the first one
	if result and #result > 0 then
		return result[1]
	end
	return nil
end

function App:getBundleID()
	return App.BUNDLE_ID
end

function App:getPasteboardUTI()
	return App.PASTEBOARD_UTI
end

function App:UI()
	return axutils.cache(self, "_ui", function()
		local fcp = self:application()
		return fcp and ax.applicationElement(fcp)
	end)
end

--- hs.finalcutpro.App:isRunning() -> boolean
--- Function
--- Is Final Cut Pro Running?
---
--- Parameters:
---  * None
---
--- Returns:
---  * True if Final Cut Pro is running otherwise False
---
function App:isRunning()
	local fcpx = self:application()
	return fcpx and fcpx:isRunning()
end


--- hs.finalcutpro.App:launch() -> boolean
--- Function
--- Launches Final Cut Pro, or brings it to the front if it was already running.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if Final Cut Pro was either launched or focused, otherwise false (e.g. if Final Cut Pro doesn't exist)
---
function App:launch()

	local result = nil

	local fcpx = self:application()
	if fcpx == nil then
		-- Final Cut Pro is Closed:
		result = application.launchOrFocusByBundleID(App.BUNDLE_ID)
	else
		-- Final Cut Pro is Open:
		if not fcpx:isFrontmost() then
			-- Open by not Active:
			result = application.launchOrFocusByBundleID(App.BUNDLE_ID)
		else
			-- Already frontmost:
			return true
		end
	end

	return result
end


--- hs.finalcutpro.App:restart() -> boolean
--- Function
--- Restart Final Cut Pro X
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if Final Cut Pro X was running and restarted successfully.
---
function App:restart()
	local app = self:application()
	if app then
		-- Kill Final Cut Pro:
		self:quit()

		-- Wait until Final Cut Pro is Closed (checking every 0.1 seconds for up to 20 seconds):
		just.doWhile(function() return self:isRunning() end, 20, 0.1)

		-- Launch Final Cut Pro:
		return self:launch()
	end
	return false
end

function App:show()
	local app = self:application()
	if app then
		if app:isHidden() then
			app:unhide()
		end
		if app:isRunning() then
			app:activate()
		end
	end
	return self
end

function App:isShowing()
	local app = self:application()
	return app ~= nil and app:isRunning() and not app:isHidden()
end

function App:hide()
	local app = self:application()
	if app then
		app:hide()
	end
	return self
end

function App:quit()
	local app = self:application()
	if app then
		app:kill()
	end
	return self
end

--- hs.finalcutpro.App:path() -> string or nil
--- Function
--- Path to Final Cut Pro Application
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing Final Cut Pro's filesystem path, or nil if the bundle identifier could not be located
---
function App:getPath()
	return application.pathForBundleID(App.BUNDLE_ID)
end

--- hs.finalcutpro.App:isInstalled() -> boolean
--- Function
--- Is Final Cut Pro X Installed?
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if a version of FCPX is installed.
---
function App:isInstalled()
	local path = self:getPath()
	return doesDirectoryExist(path)
end

--- hs.finalcutpro.App:isFrontmost() -> boolean
--- Function
--- Is Final Cut Pro X Frontmost?
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if Final Cut Pro is Frontmost.
---
function App:isFrontmost()
	local fcpx = self:application()
	return fcpx and fcpx:isFrontmost()
end


--- hs.finalcutpro.App:getVersion() -> string or nil
--- Function
--- Version of Final Cut Pro
---
--- Parameters:
---  * None
---
--- Returns:
---  * Version as string or nil if an error occurred
---
function App:getVersion()
	local version = nil
	if self:isInstalled() then
		ok,version = osascript.applescript('return version of application id "'..App.BUNDLE_ID..'"')
	end
	return version or nil
end

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
--
-- MENU BAR
--
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

function App:menuBar()
	if not self._menuBar then
		self._menuBar = MenuBar:new(self)
	end
	return self._menuBar
end

function App:selectMenu(...)
	return self:menuBar():selectMenu(...)
end

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
--
-- WINDOWS
--
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

function App:preferencesWindow()
	if not self._preferencesWindow then
		self._preferencesWindow = PreferencesWindow:new(self)
	end
	return self._preferencesWindow
end

function App:primaryWindow()
	if not self._primaryWindow then
		self._primaryWindow = PrimaryWindow:new(self)
	end
	return self._primaryWindow
end

function App:secondaryWindow()
	if not self._secondaryWindow then
		self._secondaryWindow = SecondaryWindow:new(self)
	end
	return self._secondaryWindow
end

function App:fullScreenWindow()
	if not self._fullScreenWindow then
		self._fullScreenWindow = FullScreenWindow:new(self)
	end
	return self._fullScreenWindow
end

function App:commandEditor()
	if not self._commandEditor then
		self._commandEditor = CommandEditor:new(self)
	end
	return self._commandEditor
end

function App:mediaImport()
	if not self._mediaImport then
		self._mediaImport = MediaImport:new(self)
	end
	return self._mediaImport
end

function App:exportDialog()
	if not self._exportDialog then
		self._exportDialog = ExportDialog:new(self)
	end
	return self._exportDialog
end

--- hs.finalcutpro.App:windowsUI() -> axuielement
--- Function
--- Returns the UI containing the list of windows in the app.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * The axuielement, or nil if the application is not running.
---
function App:windowsUI()
	local ui = self:UI()
	return ui and ui:attributeValue("AXWindows")
end

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
--
-- APP SECTIONS
--
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------


--- hs.finalcutpro.App:timeline() -> Timeline
--- Function
--- Returns the Timeline instance, whether it is in the primary or secondary window.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * the Timeline
function App:timeline()
	if not self._timeline then
		self._timeline = Timeline:new(self)
	end
	return self._timeline
end


--- hs.finalcutpro.App:viewer() -> Viewer
--- Function
--- Returns the Viewer instance, whether it is in the primary or secondary window.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * the Viewer
function App:viewer()
	if not self._viewer then
		self._viewer = Viewer:new(self, false)
	end
	return self._viewer
end

--- hs.finalcutpro.App:eventViewer() -> Viewer
--- Function
--- Returns the Event Viewer instance, whether it is in the primary or secondary window.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * the Event Viewer
function App:eventViewer()
	if not self._eventViewer then
		self._eventViewer = Viewer:new(self, true)
	end
	return self._eventViewer
end

--- hs.finalcutpro.App:browser() -> Browser
--- Function
--- Returns the Browser instance, whether it is in the primary or secondary window.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * the Browser
function App:browser()
	if not self._browser then
		self._browser = Browser:new(self)
	end
	return self._browser
end

--- hs.finalcutpro.App:libraries() -> LibrariesBrowser
--- Function
--- Returns the LibrariesBrowser instance, whether it is in the primary or secondary window.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * the LibrariesBrowser
function App:libraries()
	return self:browser():libraries()
end

--- hs.finalcutpro.App:media() -> MediaBrowser
--- Function
--- Returns the MediaBrowser instance, whether it is in the primary or secondary window.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * the MediaBrowser
function App:media()
	return self:browser():media()
end

--- hs.finalcutpro.App:generators() -> GeneratorsBrowser
--- Function
--- Returns the GeneratorsBrowser instance, whether it is in the primary or secondary window.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * the GeneratorsBrowser
function App:generators()
	return self:browser():generators()
end

--- hs.finalcutpro.App:effects() -> EffectsBrowser
--- Function
--- Returns the EffectsBrowser instance, whether it is in the primary or secondary window.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * the EffectsBrowser
function App:effects()
	return self:timeline():effects()
end

--- hs.finalcutpro.App:transitions() -> TransitionsBrowser
--- Function
--- Returns the TransitionsBrowser instance, whether it is in the primary or secondary window.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * the TransitionsBrowser
function App:transitions()
	return self:timeline():transitions()
end

--- hs.finalcutpro.App:inspector() -> Inspector
--- Function
--- Returns the Inspector instance from the primary window
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * the Inspector
function App:inspector()
	return self:primaryWindow():inspector()
end

--- hs.finalcutpro.App:colorBoard() -> ColorBoard
--- Function
--- Returns the ColorBoard instance from the primary window
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * the ColorBoard
function App:colorBoard()
	return self:primaryWindow():colorBoard()
end

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
--
-- PREFERENCES, SETTINGS, XML
--
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

--- hs.finalcutpro.App:getPreferences() -> table or nil
--- Function
--- Gets Final Cut Pro's Preferences as a table. It checks if the preferences
--- file has been modified and reloads when necessary.
---
--- Parameters:
---  * forceReload	- (optional) if true, a reload will be forced even if the file hasn't been modified.
---
--- Returns:
---  * A table with all of Final Cut Pro's preferences, or nil if an error occurred
---
function App:getPreferences(forceReload)
	local modified = fs.attributes(App.PREFS_PLIST_PATH, "modification")
	if forceReload or modified ~= self._preferencesModified then
		log.d("Reloading FCPX preferences from file...")
		self._preferences = plist.binaryFileToTable(App.PREFS_PLIST_PATH) or nil
		self._preferencesModified = modified
	 end
	return self._preferences
end

--- hs.finalcutpro.getPreference(preferenceName) -> string or nil
--- Function
--- Get an individual Final Cut Pro preference
---
--- Parameters:
---  * value 			- The preference you want to return
---  * default			- (optional) The default value to return if the preference is not set.
---  * forceReload		= (optional) If true, forces a reload of the app's preferences.
---
--- Returns:
---  * A string with the preference value, or nil if an error occurred
---
function App:getPreference(value, default, forceReload)
	local result = nil
	local preferencesTable = self:getPreferences(forceReload)
	if preferencesTable then
		result = preferencesTable[value]
	end

	if result == nil then
		result = default
	end

	return result
end

--- hs.finalcutpro.App:setPreference(key, value) -> boolean
--- Function
--- Sets an individual Final Cut Pro preference
---
--- Parameters:
---  * key - The preference you want to change
---  * value - The value you want to set for that preference
---
--- Returns:
---  * True if executed successfully otherwise False
---
function App:setPreference(key, value)

	local executeStatus
	local type = nil

	if type(value) == "boolean" then
		value = tostring(value)
		type = "bool"
	elseif type(value) == "table" then
		local arrayString = ""
		for i=1, #value do
			arrayString = arrayString .. value[i]
			if i ~= #value then
				arrayString = arrayString .. ","
			end
		end
		type = "array"
	elseif type(value) == "string" then
		type = "string"
	end
	
	if type then
		local _, executeStatus = hs.execute("defaults write " .. App.PREFS_PLIST_PATH .. " '" .. key .. "' -" .. type .. " " .. value)
		return executeState ~= nil
	end
	return false
end

--- hs.finalcutpro.App:importXML() -> boolean
--- Function
--- Imports an XML file into Final Cut Pro
---
--- Parameters:
---  * path = Path to XML File
---
--- Returns:
---  * A boolean value indicating whether the AppleScript succeeded or not
---
function App:importXML(path)
	if self:isRunning() then
		local appleScriptA = 'set whichSharedXMLPath to "' .. path .. '"' .. '\n\n'
		local appleScriptB = [[
			tell application "Final Cut Pro"
				activate
				open POSIX file whichSharedXMLPath as string
			end tell
		]]
		local bool, _, _ = osascript.applescript(appleScriptA .. appleScriptB)
		return bool
	end
end

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
--
-- SHORTCUTS
--
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

--- hs.finalcutpro.App:getActiveCommandSetPath() -> string or nil
--- Function
--- Gets the 'Active Command Set' value from the Final Cut Pro preferences
---
--- Parameters:
---  * None
---
--- Returns:
---  * The 'Active Command Set' value, or nil if an error occurred
---
function App:getActiveCommandSetPath()
	local result = self:getPreference("Active Command Set") or nil
	if result == nil then
		-- In the unlikely scenario that this is the first time FCPX has been run:
		return "/Applications/Final Cut Pro.app/Contents/Resources/" .. self:getCurrentLanguage() .. ".lproj/Default.commandset"
	end
	return result
end

--- hs.finalcutpro.App:getActiveCommandSet([optionalPath]) -> table or nil
--- Function
--- Returns the 'Active Command Set' as a Table
---
--- Parameters:
---  * optionalPath - The optional path of the Command Set
---
--- Returns:
---  * A table of the Active Command Set's contents, or nil if an error occurred
---
function App:getActiveCommandSet(optionalPath, forceReload)

	if forceReload or not self._activeCommandSet then
		local path = optionalPath or self:getActiveCommandSetPath()

		if path ~= nil then
			if fs.attributes(path) ~= nil then
				self._activeCommandSet = plist.fileToTable(path)
			end
		end
	end

	return self._activeCommandSet
end

--- hs.finalcutpro.performShortcut() -> Boolean
--- Function
--- Performs a Final Cut Pro Shortcut
---
--- Parameters:
---  * whichShortcut - As per the Command Set name
---
--- Returns:
---  * true if successful otherwise false
---
function App:performShortcut(whichShortcut)

	local activeCommandSet = self:getActiveCommandSet()

	if activeCommandSet[whichShortcut] == nil then return false end

	-- There may be one or multiple keyboard combos for a given command
	local currentShortcut = activeCommandSet[whichShortcut]
	if #currentShortcut > 0 then
		currentShortcut = currentShortcut[1]
	end

	if currentShortcut == nil then
		debugMessage("Unable to find keyboard shortcut named '"..whichShortcut.."'")
		return false
	end

	local modifiers = nil
	local charString = nil

	if currentShortcut["modifiers"] ~= nil then
		modifiers = kc.translateKeyboardModifiers(currentShortcut["modifiers"])
	end

	if currentShortcut["modifierMask"] ~= nil then
		modifiers = kc.translateModifierMask(currentShortcut["modifierMask"])
	end

	if currentShortcut["characterString"] ~= nil then
		charString = kc.translateKeyboardCharacters(currentShortcut["characterString"])
	end

	if currentShortcut["character"] ~= nil then
		if keypadModifier then
			charString = kc.translateKeyboardKeypadCharacters(currentShortcut["character"])
		else
			charString = kc.translateKeyboardCharacters(currentShortcut["character"])
		end
	end

	eventtap.keyStroke(modifiers, charString)

	return true

end

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
--
-- LANGUAGE
--
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

App.fileMenuTitle = {
	["File"]		= "en",
	["Ablage"]		= "de",
	["Archivo"]		= "es",
	["Fichier"]		= "fr",
	["ファイル"]		= "ja",
	["文件"]			= "zh_CN"
}


--- hs.finalcutpro.App:getCurrentLanguage() -> string
--- Function
--- Returns the language Final Cut Pro is currently using.
---
--- Parameters:
---  * none
---
--- Returns:
---  * Returns the current language as string (or 'en' if unknown).
---
function App:getCurrentLanguage(forceReload, forceLanguage)

	--------------------------------------------------------------------------------
	-- Force a Language:
	--------------------------------------------------------------------------------
	if forceReload and forceLanguage ~= nil then
		self._currentLanguage = forceLanguage
		return self._currentLanguage
	end

	--------------------------------------------------------------------------------
	-- Caching:
	--------------------------------------------------------------------------------
	if self._currentLanguage ~= nil and not forceReload then
		return self._currentLanguage
	end

	--------------------------------------------------------------------------------
	-- If FCPX is already running, we determine the language off the menu:
	--------------------------------------------------------------------------------
	if self:isRunning() then
		local menuBar = self:menuBar()
		
		local fileMenu = menuBar:findMenuUI("File")
		if fileMenu then
			fileValue = fileMenu:attributeValue("AXTitle") or nil
		
			self._currentLanguage = fileValue and App.fileMenuTitle[fileValue]
			if self._currentLanguage then
				return self._currentLanguage
			end
		end
	end

	--------------------------------------------------------------------------------
	-- If FCPX is not running, we next try to determine the language using
	-- the Final Cut Pro Plist File:
	--------------------------------------------------------------------------------
	local finalCutProLanguage = self:getPreference("AppleLanguages", nil)
	if finalCutProLanguage ~= nil and next(finalCutProLanguage) ~= nil then
		if finalCutProLanguage[1] ~= nil then
			self._currentLanguage = finalCutProLanguage[1]
			return finalCutProLanguage[1]
		end
	end

	--------------------------------------------------------------------------------
	-- If that fails, we try and use the user locale:
	--------------------------------------------------------------------------------
	local a, userLocale = osascript.applescript("return user locale of (get system info)")
	if userLocale ~= nil then

		--------------------------------------------------------------------------------
		-- Only return languages Final Cut Pro actually supports:
		--------------------------------------------------------------------------------
		for i=1, #finalCutProLanguages do
			if userLocale == finalCutProLanguages[i] then
				self._currentLanguage = userLocale
				return userLocale
			else
				if string.sub(userLocale, 1, string.find(userLocale, "_") - 1) == finalCutProLanguages[i] then
					self._currentLanguage = string.sub(userLocale, 1, string.find(userLocale, "_") - 1)
					return string.sub(userLocale, 1, string.find(userLocale, "_") - 1)
				end
			end
		end

	end

	--------------------------------------------------------------------------------
	-- If that also fails, we try and use NSGlobalDomain AppleLanguages:
	--------------------------------------------------------------------------------
	local a, AppleLanguages = hs.osascript.applescript([[
		set lang to do shell script "defaults read NSGlobalDomain AppleLanguages"
			tell application "System Events"
				set pl to make new property list item with properties {text:lang}
				set r to value of pl
			end tell
		return item 1 of r ]])
	if AppleLanguages ~= nil then

		--------------------------------------------------------------------------------
		-- Only return languages Final Cut Pro actually supports:
		--------------------------------------------------------------------------------
		for i=1, #finalCutProLanguages do
			if AppleLanguages == finalCutProLanguages[i] then
				self._currentLanguage = AppleLanguages
				return AppleLanguages
			else
				if string.sub(AppleLanguages, 1, string.find(AppleLanguages, "-") - 1) == finalCutProLanguages[i] then
					self._currentLanguage = string.sub(AppleLanguages, 1, string.find(AppleLanguages, "-") - 1)
					return string.sub(AppleLanguages, 1, string.find(AppleLanguages, "-") - 1)
				end
			end
		end

	end

	--------------------------------------------------------------------------------
	-- If all else fails, assume it's English:
	--------------------------------------------------------------------------------
	return "en"

end


--- hs.finalcutpro.App:getSupportedLanguages() -> table
--- Function
--- Returns a table of languages Final Cut Pro supports
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of languages Final Cut Pro supports
---
function App:getSupportedLanguages()
	return App.SUPPORTED_LANGUAGES
end

--- hs.finalcutpro.App:getFlexoLanguages() -> table
--- Function
--- Returns a table of languages Final Cut Pro's Flexo Framework supports
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of languages Final Cut Pro supports
---
function App:getFlexoLanguages()
	return App.FLEXO_LANGUAGES
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   D E V E L O P M E N T      T O O L S                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- hs.finalcutpro._generateMenuMap() -> Table
--- Function
--- Generates a map of the menu bar and saves it in '/hs/finalcutpro/menumap.json'.
---
--- Parameters:
---  * N/A
---
--- Returns:
---  * True is successful otherwise Nil
---
function App:_generateMenuMap()
	return self:menuBar():generateMenuMap()
end

function App:_listWindows()
	log.d("Listing FCPX windows:")
	local windows = self:windowsUI()
	for i,w in ipairs(windows) do
		debugMessage(string.format("%7d", i)..": "..self:_describeWindow(w))
	end

	debugMessage("")
	debugMessage("   Main: "..self:_describeWindow(self:UI():mainWindow()))
	debugMessage("Focused: "..self:_describeWindow(self:UI():focusedWindow()))
end

function App:_describeWindow(w)
	return "title: "..inspect(w:attributeValue("AXTitle"))..
	       "; role: "..inspect(w:attributeValue("AXRole"))..
		   "; subrole: "..inspect(w:attributeValue("AXSubrole"))..
		   "; modal: "..inspect(w:attributeValue("AXModal"))
end

return App:new()