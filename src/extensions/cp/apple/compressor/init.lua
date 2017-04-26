--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                        C O M P R E S S O R     A P I                       --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.apple.compressor ===
---
--- Represents the Compressor application, providing functions that allow different tasks to be accomplished.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log										= require("hs.logger").new("compressor")

local application								= require("hs.application")
local fs 										= require("hs.fs")
local inspect									= require("hs.inspect")

local v											= require("semver")

local plist										= require("cp.plist")
local just										= require("cp.just")
local tools										= require("cp.tools")
local is										= require("cp.is")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local App = {}

--- cp.apple.compressor.BUNDLE_ID
--- Constant
--- Compressor's Bundle ID
App.BUNDLE_ID 									= "com.apple.Compressor"

--- cp.apple.compressor:application() -> hs.application
--- Method
--- Returns the hs.application for Compressor.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The hs.application, or nil if the application is not installed.
function App:application()
	if self:isInstalled() then
		local result = application.applicationsForBundleID(App.BUNDLE_ID) or nil
		-- If there is at least one copy running, return the first one
		if result and #result > 0 then
			return result[1]
		end
	end
	return nil
end

--- cp.apple.compressor:getBundleID() -> string
--- Method
--- Returns the Compressor Bundle ID
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string of the Compressor Bundle ID
function App:getBundleID()
	return App.BUNDLE_ID
end

--- cp.apple.compressor:launch() -> boolean
--- Method
--- Launches Compressor, or brings it to the front if it was already running.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if Compressor was either launched or focused, otherwise false (e.g. if Compressor doesn't exist)
function App:launch()

	local result = nil

	local app = self:application()
	if app == nil then
		-- Compressor is Closed:
		result = application.launchOrFocusByBundleID(App.BUNDLE_ID)
	else
		-- Compressor is Open:
		if not app:isFrontmost() then
			-- Open if not Active:
			result = application.launchOrFocusByBundleID(App.BUNDLE_ID)
		else
			-- Already frontmost:
			return true
		end
	end

	return result
end

--- cp.apple.compressor:restart() -> boolean
--- Method
--- Restart the application.
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if the application was running and restarted successfully.
function App:restart()
	local app = self:application()
	if app then
		-- Kill Compressor:
		self:quit()

		-- Wait until Compressor is Closed (checking every 0.1 seconds for up to 20 seconds):
		just.doWhile(function() return self:isRunning() end, 20, 0.1)

		-- Launch Compressor:
		return self:launch()
	end
	return false
end

--- cp.apple.compressor:show() -> cp.apple.compressor object
--- Method
--- Activate Compressor
---
--- Parameters:
---  * None
---
--- Returns:
---  * An `cp.apple.compressor` object otherwise `nil`
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

--- cp.apple.compressor:hide() -> cp.apple.compressor object
--- Method
--- Hides Compressor
---
--- Parameters:
---  * None
---
--- Returns:
---  * An `cp.apple.compressor` object otherwise `nil`
function App:hide()
	local app = self:application()
	if app then
		app:hide()
	end
	return self
end

--- cp.apple.compressor:quit() -> cp.apple.compressor object
--- Method
--- Quits Compressor
---
--- Parameters:
---  * None
---
--- Returns:
---  * An `cp.apple.compressor` object otherwise `nil`
function App:quit()
	local app = self:application()
	if app then
		app:kill()
	end
	return self
end

--- cp.apple.compressor:path() -> string or nil
--- Method
--- Path to Compressor Application
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing Compressor's filesystem path, or `nil` if the bundle identifier could not be located
function App:getPath()
	return application.pathForBundleID(App.BUNDLE_ID)
end


--- cp.apple.compressor.isRunning <cp.is: boolean; read-only>
--- Field
--- Is the app is running?
App.isRunning = is.new(function(self)
	local app = self:application()
	return app and app:isRunning()
end):bind(App)

--- cp.apple.compressor.isShowing <cp.is: boolean; read-only>
--- Field
--- Is Compressor Showing?
App.isShowing = is.new(function(owner)
	local app = owner:application()
	return app ~= nil and app:isRunning() and not app:isHidden()
end):bind(App)

--- cp.apple.compressor.isInstalled <cp.is: boolean; read-only>
--- Field
--- Is a supported version of Compressor Installed?
App.isInstalled = is.new(function(owner)
	local app = application.infoForBundleID(App.BUNDLE_ID)
	if app then return true end
	return false
end):bind(App)

--- cp.apple.compressor.isFrontmost <cp.is: boolean; read-only>
--- Field
--- Is Compressor Frontmost?
App.isFrontmost = is.new(function(owner)
	local app = owner:application()
	return app and app:isFrontmost()
end):bind(App)

--- cp.apple.compressor:getVersion() -> string | nil
--- Method
--- Version of Compressor
---
--- Parameters:
---  * None
---
--- Returns:
---  * Version as string or nil if an error occurred
---
--- Notes:
---  * If Compressor is running it will get the version of the active Compressor application, otherwise, it will use hs.application.infoForBundleID() to find the version.
function App:getVersion()
	local app = self:application()
	if app then
		return app and app["CFBundleShortVersionString"] or nil
	else
		local info = application.infoForBundleID(App.BUNDLE_ID)
		return info and info["CFBundleShortVersionString"] or nil
	end
end

return App