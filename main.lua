-- name: Platform Icons
-- description: \\#33ff33\\Platform Icons v1.0.0\n\n\\#dcdcdc\\Adds platform and device icons to the player list.\n\nMod by \\#646464\\kermeow

-- 0 = Mac
-- 1 = Linux
-- 2 = Windows
-- 3 = Android
local os_platforms = {
	["Mac OSX"] = 0,
	["Linux"] = 1,
	["Unix"] = 1,
	["FreeBSD"] = 1,
	["Unknown"] = 1,
	["Windows"] = 2,
	["Android"] = 3
}
-- 0 = Android
-- 1 = Desktop
local os_devices = {
	["Mac OSX"] = 1,
	["Linux"] = 1,
	["Unix"] = 1,
	["FreeBSD"] = 1,
	["Unknown"] = 1,
	["Windows"] = 1,
	["Android"] = 0
}

local platforms_texture = get_texture_info("platforms")
local devices_texture = get_texture_info("devices")

local render_platforms, render_devices, enable_playerlist = true, true, true
if mod_storage_exists("render_platforms") then render_platforms = mod_storage_load_bool("render_platforms") end
if mod_storage_exists("render_devices") then render_devices = mod_storage_load_bool("render_devices") end
if mod_storage_exists("enable_playerlist") then enable_playerlist = mod_storage_load_bool("enable_playerlist") end

-- Platform Icon
-- local tx,ty = i % 2, math.floor(i / 2)
-- djui_hud_render_texture_tile(platforms_texture, x, y, 1, 1, tx * 32, ty * 32, 32, 32)
-- Device Icon
-- local tx = i % 2
-- djui_hud_render_texture_tile(devices_texture, x, y, 1, 1, tx * 32, 0, 32, 32)

local enable_playerlist = false
local fake_playerlist = false

local function render()
	local open = djui_attempting_to_open_playerlist() and enable_playerlist
	if not open then return end

	local renderEither = render_platforms or render_devices

	if fake_playerlist and not renderEither then
		gServerSettings.enablePlayerList = 1
	elseif fake_playerlist then
		gServerSettings.enablePlayerList = 0
	end
	if not renderEither then return end -- Peak optimisation

	djui_hud_set_resolution(RESOLUTION_DJUI)
	djui_hud_set_font(djui_menu_get_font())
	djui_hud_set_color(255, 255, 255, 255)

	local playerlistWidth = 710
	local playerlistHeight = 684 -- thank you squishy

	local playerlistX = (djui_hud_get_screen_width() - playerlistWidth) / 2
	local playerlistY = (djui_hud_get_screen_height() - playerlistHeight) / 2

	local entryNo = -1
	for i = 0, 15 do
		local networkPlayer, os, name = gNetworkPlayers[i], gPlayerSyncTable[i].os, ""
		local x, y = playerlistX + 68, playerlistY + 88
		local platform, device = 0, 0
		if not networkPlayer.connected then goto continue end
		entryNo = entryNo + 1
		if (os == nil) or (os == "Unknown") then goto continue end

		name = string.gsub(networkPlayer.name, "\\#%x+\\", "")
		x = x + djui_hud_measure_text(name)
		y = y + entryNo * 36

		-- djui_hud_print_text(os, x, y, 1)

		if render_devices then
			device = os_devices[os]
			djui_hud_render_texture_tile(devices_texture,
				x, y, 1, 1, device * 32, 0, 32, 32)
			x = x + 28
		end

		if render_platforms then
			platform = os_platforms[os]
			djui_hud_render_texture_tile(platforms_texture,
				x, y, 1, 1, (platform % 2) * 32, math.floor(platform / 2) * 32, 32, 32)
		end

		::continue::
	end
end

-- Make sure we hook hud rendering "last"
-- Some mods hook "last" on the first update instead, but I prefer this way
local function on_mods_loaded()
	local os = get_os_name()
	print(string.format("Running on %s", os))
	gPlayerSyncTable[0].os = os

	enable_playerlist = gServerSettings.enablePlayerList == 1
	if not _G.charSelectExists then
		fake_playerlist = true
		gServerSettings.enablePlayerList = 0
		hook_mod_menu_checkbox("Enable playerlist", enable_playerlist, function(_, value)
			enable_playerlist = value
			mod_storage_save_bool("enable_playerlist", enable_playerlist)
		end)
	end

	hook_mod_menu_checkbox("Show device icons", render_devices, function(_, value)
		render_devices = value
		mod_storage_save_bool("render_devices", render_devices)
	end)
	hook_mod_menu_checkbox("Show platform icons", render_platforms, function(_, value)
		render_platforms = value
		mod_storage_save_bool("render_platforms", render_platforms)
	end)

	hook_event(HOOK_ON_HUD_RENDER, render)
end
hook_event(HOOK_ON_MODS_LOADED, on_mods_loaded)
