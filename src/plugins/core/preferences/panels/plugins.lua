--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--            P L U G I N S    P R E F E R E N C E S    P A N E L            --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === core.preferences.panels.plugins ===
---
--- Plugins Preferences Panel

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log										= require("hs.logger").new("prefsPlugin")

local fnutils									= require("hs.fnutils")
local fs										= require("hs.fs")
local image										= require("hs.image")
local timer										= require("hs.timer")
local toolbar                  					= require("hs.webview.toolbar")
local webview									= require("hs.webview")

local dialog									= require("cp.dialog")
local config									= require("cp.config")
local tools										= require("cp.tools")
local plugins									= require("cp.plugins")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local mod = {}

--- core.preferences.panels.plugins.SETTINGS_DISABLED
--- Constant
--- Plugins Disabled
mod.SETTINGS_DISABLED = "plugins.disabled"

--------------------------------------------------------------------------------
-- DISABLE PLUGIN:
--------------------------------------------------------------------------------
local function disablePlugin(id)
	local result = dialog.displayMessage("Are you sure you want to disable this plugin?\n\nIf you continue, CommandPost will need to restart.", {"Yes", "No"})
	if result == "Yes" then
		plugins.disable(id)
		hs.reload()
	end
end

--------------------------------------------------------------------------------
-- ENABLE PLUGIN:
--------------------------------------------------------------------------------
local function enablePlugin(id)
	local result = dialog.displayMessage("Are you sure you want to enable this plugin?\n\nIf you continue, CommandPost will need to restart.", {"Yes", "No"})
	if result == "Yes" then
		plugins.enable(id)
		hs.reload()
	end
end

--------------------------------------------------------------------------------
-- CONTROLLER CALLBACK:
--------------------------------------------------------------------------------
local function controllerCallback(message)

	--log.df("plugins panel clicked: %s", hs.inspect(message))

	if message["body"][1] == "openErrorLog" then
		hs.openConsole()
	elseif message["body"][1] == "pluginsFolder" then

		if not tools.doesDirectoryExist(config.userPluginsPath) then
			log.df("Creating Plugins directory.")
			local status, err = fs.mkdir(config.userPluginsPath)
			if not status then
				log.ef("Failed to create Plugins directory: %s", err)
				return
			end
		end

		local pathToOpen = fs.pathToAbsolute(config.userPluginsPath)
		if pathToOpen then
			local _, status = hs.execute('open "' .. pathToOpen .. '"')
			if status then return end
		end

		log.df("Failed to Open Plugins Window.")

	elseif message["body"][2] == "disable" then
		disablePlugin(message["body"][1])
	elseif message["body"][2] == "enable" then
		enablePlugin(message["body"][1])
	else
		--log.df("Unrecognised action: ", hs.inspect(message))
	end

end

--------------------------------------------------------------------------------
-- PLUGIN STATUS:
--------------------------------------------------------------------------------
local function pluginStatus(id)
	local status = plugins.getPluginStatus(id)
	return string.format("<span class='status-%s'>%s</span>", status, i18n("plugin_status_" .. status))
end

--------------------------------------------------------------------------------
-- PLUGIN CATEGORY:
--------------------------------------------------------------------------------
local function pluginCategory(id)
	local group = plugins.getPluginGroup(id)
	return i18n("plugin_group_" .. group, {default = group})
end

--------------------------------------------------------------------------------
-- PLUGIN SHORT NAME:
--------------------------------------------------------------------------------
local function pluginShortName(path)

	local result = i18n(string.gsub(path, "%.", "_") .. "_label") or path
	if result ~= path then
		result = string.format('<div class="tooltip">%s<span class="tooltiptext">%s</span></div>', result, path)
	end
	return result
end

--------------------------------------------------------------------------------
-- GENERATE CONTENT:
--------------------------------------------------------------------------------
local function generateContent()

	local listOfPlugins = plugins.getPluginIds()

	table.sort(listOfPlugins, function(a, b) return a < b end)

	local pluginRows = ""

	local lastCategory = ""

	for _,id in ipairs(listOfPlugins) do

		local currentCategory = pluginCategory(id)
		local cachedCurrentCategory = currentCategory
		if currentCategory == lastCategory then currentCategory = "" end

		local status = plugins.getPluginStatus(id)
		pluginRows = pluginRows .. [[
			<tr>
				<td class="rowCategory">]] .. currentCategory .. [[</td>
				<td class="rowName">]] .. pluginShortName(id) .. [[</td>
				<td class="rowStatus">]] .. i18n("plugin_status_"..status) .. [[</td>]]

		local action = nil

		if status == plugins.status.error then
			action = "errorLog"
		elseif status == plugins.status.active then
			action = "disable"
		elseif status == plugins.status.disabled then
			action = "enable"
		end

		if action then
		local actionLabel = i18n("plugin_action_" .. action,  {default = action})
		pluginRows = pluginRows .. [[
			<td class="rowOption"><a id="]] .. id .. [[" href="#">]] .. actionLabel .. [[</></td>
			<script>
				document.getElementById("]] .. id .. [[").onclick = function() {
					try {
						var result = ["]] .. id .. [[", "]] .. action .. [["];
						webkit.messageHandlers.]] .. mod._webviewLabel .. [[.postMessage(result);
					} catch(err) {
						alert('An error has occurred. Does the controller exist yet?');
					}
				}
			</script>
			]]
		else
			pluginRows = pluginRows .. [[<td class="rowOption">&nbsp;</td>]]
		end

		pluginRows = pluginRows .. "</tr>"


		lastCategory = cachedCurrentCategory

	end

	local result = [[
		<style>
			.tooltip {
				position: relative;
				display: inline-block;
				/* border-bottom: 1px dotted black; */
			}

			.tooltip .tooltiptext {
				visibility: hidden;
				width: 120px;
				background-color: black;
				color: #fff;
				text-align: center;
				border-radius: 6px;
				padding: 5px 0;
				position: absolute;
				z-index: 1;
				bottom: 150%;
				left: 50%;
				margin-left: -60px;
			}

			.tooltip .tooltiptext::after {
				content: "";
				position: absolute;
				top: 100%;
				left: 50%;
				margin-left: -5px;
				border-width: 5px;
				border-style: solid;
				border-color: black transparent transparent transparent;
			}

			.tooltip:hover .tooltiptext {
				visibility: visible;
			}

			.plugins {
				table-layout: fixed;
				width: 100%;
				white-space: nowrap;

				border: 1px solid #cccccc;
				padding: 8px;
				background-color: #ffffff;
				text-align: left;
			}

			.plugins td {
			  white-space: nowrap;
			  overflow: hidden;
			  text-overflow: ellipsis;
			}

			.rowCategory {
				width:20%;
				font-weight: bold;
			}

			.rowName {
				width:50%;
			}

			.rowStatus {
				width:15%;
			}

			.rowOption {
				width:15%;
			}

			.plugins thead, .plugins tbody tr {
				display:table;
				table-layout:fixed;
				width: calc( 100% - 1.5em );
			}

			.plugins tbody {
				display:block;
				height: 250px;
				font-weight: normal;
				font-size: 10px;

				overflow-x: hidden;
				overflow-y: auto;
			}

			.plugins tbody tr {
				display:table;
				width:100%;
				table-layout:fixed;
			}

			.plugins thead {
				font-weight: bold;
				font-size: 12px;
			}

			.plugins tbody {
				font-weight: normal;
				font-size: 10px;
			}

			.plugins tbody tr:nth-child(even) {
				background-color: #f5f5f5
			}

			.plugins tbody tr:hover {
				background-color: #006dd4;
				color: white;
			}

			.plugins .status-failed {
				font-weight: bold;
				color: red;
			}

			.plugins .status-disabled {
				font-weight: bold;
			}
		</style>
		<h3>Plugins Manager:</h3>
		<table class="plugins">
			<thead>
				<tr>
					<th class="rowCategory">Category</th>
					<th class="rowName">Plugin Name</th>
					<th class="rowStatus">Status</th>
					<th class="rowOption">Control</th>
				</tr>
			</thead>
			<tbody>
				]] .. pluginRows .. [[
			</tbody>
		</table>
		<style>
			divTable{
				display: table;
				width: 100%;
			}
			.divTableRow {
				display: table-row;
			}
			.divTableHeading {
				display: table-header-group;
			}
			.divTableCell, .divTableHead {
				display: table-cell;
				padding: 20px;
			}
			.divTableHeading {
				display: table-header-group;
			}
			.divTableFoot {
				display: table-footer-group;
			}
			.divTableBody {
				display: table-row-group;
			}
		</style>
		<div class="divTable">
			<div class="divTableBody">
				<div class="divTableRow">
					<div class="divTableCell" style="vertical-align: middle;">
						<span style="font-weight: bold;">Custom Plugins</span> can also be saved in the Plugins Folder.
					</div>
					<div class="divTableCell" style="width: 170px; vertical-align: middle; text-align: right;">
						<a id="pluginsFolder" class="button" href="#">Open Plugins Folder</a>
						<script>
							var pluginsFolder=document.getElementById("pluginsFolder");
							pluginsFolder.onclick = function (){
								try {
									var result = ["pluginsFolder"];
									webkit.messageHandlers.]] .. mod._webviewLabel .. [[.postMessage(result);
								} catch(err) {
									alert('An error has occurred. Does the controller exist yet?');
								}
							}
						</script>
					</div>
				</div>
			</div>
		</div>
	]]
	return result
end

--- core.preferences.panels.plugins() -> none
--- Function
--- Initialises the module.
---
--- Parameters:
---  * deps - Dependencies Table
---
--- Returns:
---  * None
function mod.init(deps)

	mod._webviewLabel = deps.manager.getLabel()

	local id 			= "plugins"
	local label 		= "Plugins"
	local image			= image.imageFromPath("/System/Library/PreferencePanes/Extensions.prefPane/Contents/Resources/Extensions.icns")
	local priority		= 2050
	local tooltip		= "Plugins Panel"
	local contentFn		= generateContent
	local callbackFn 	= controllerCallback

	deps.manager.addPanel(id, label, image, priority, tooltip, contentFn, callbackFn)

end

--------------------------------------------------------------------------------
--
-- THE PLUGIN:
--
--------------------------------------------------------------------------------
local plugin = {
	id				= "core.preferences.panels.plugins",
	group			= "core",
	dependencies	= {
		["core.preferences.manager"]			= "manager",
	}
}

--------------------------------------------------------------------------------
-- INITIALISE PLUGIN:
--------------------------------------------------------------------------------
function plugin.init(deps)
	return mod.init(deps)
end

return plugin