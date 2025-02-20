-- name: Platform Icons
-- description: \\#3399ff\\Platform Icons v1.0.0\n\n\\#dcdcdc\\Adds platform and device icons to the player list.\n\nMod by \\#646464\\kermeow\n\\#dcdcdc\\Playerlist recreation by \\#008800\\Squishy6094

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

local render_platforms, render_devices = true, true
if mod_storage_exists("render_platforms") then render_platforms = mod_storage_load_bool("render_platforms") end
if mod_storage_exists("render_devices") then render_devices = mod_storage_load_bool("render_devices") end

local playerlistWidth, playerlistHeight = 710, 684
local modlistWidth, modlistHeight = 280, 0

---@type DjuiTheme, DjuiFontType
local sDjuiTheme, sDjuiFont
local fake_playerlist = false
local mod_list = {}

local function convert_color(text)
	if text:sub(2, 2) ~= "#" then
		return nil
	end
	text = text:sub(3, -2)
	local rstring = text:sub(1, 2) or "ff"
	local gstring = text:sub(3, 4) or "ff"
	local bstring = text:sub(5, 6) or "ff"
	local astring = text:sub(7, 8) or "ff"
	local r = tonumber("0x" .. rstring) or 255
	local g = tonumber("0x" .. gstring) or 255
	local b = tonumber("0x" .. bstring) or 255
	local a = tonumber("0x" .. astring) or 255
	return r, g, b, a
end

local function remove_color(text, get_color)
	local start = text:find("\\")
	local next = 1
	while (next ~= nil) and (start ~= nil) do
		start = text:find("\\")
		if start ~= nil then
			next = text:find("\\", start + 1)
			if next == nil then
				next = text:len() + 1
			end

			if get_color then
				local color = text:sub(start, next)
				local render = text:sub(1, start - 1)
				text = text:sub(next + 1)
				return text, color, render
			else
				text = text:sub(1, start - 1) .. text:sub(next + 1)
			end
		end
	end
	return text
end

local function generate_rainbow_text(text)
	local preResult = {}
	local postResult = {}
	for match in text:gmatch(string.format(".", "(.)")) do
		table.insert(preResult, match)
	end

	RED = djui_menu_get_rainbow_string_color(0)
	GREEN = djui_menu_get_rainbow_string_color(1)
	BLUE = djui_menu_get_rainbow_string_color(2)
	YELLOW = djui_menu_get_rainbow_string_color(3)

	local sRainbowColors = {
		[0] = YELLOW,
		[1] = RED,
		[2] = GREEN,
		[3] = BLUE,
	}

	for i = 1, #preResult do
		rainbow = sRainbowColors[i % 4]
		table.insert(postResult, rainbow .. preResult[i])
	end

	local result = table.concat(postResult, "")
	return result
end

local function djui_hud_print_text_with_color(text, x, y, scale, red, green, blue, alpha)
	djui_hud_set_color(red or 255, green or 255, blue or 255, alpha or 255)
	local space = 0
	local color
	text, color, render = remove_color(text, true)
	while render ~= nil do
		local r, g, b, a = convert_color(color)
		if alpha then a = alpha end
		djui_hud_print_text(render, x + space, y, scale);
		if r then djui_hud_set_color(r, g, b, a) end
		space = space + djui_hud_measure_text(render) * scale
		text, color, render = remove_color(text, true)
	end
	djui_hud_print_text(text, x + space, y, scale);
end

local function djui_hud_render_djui(x, y, width, height, rectColor, borderColor)
	djui_hud_set_color(borderColor.r, borderColor.g, borderColor.b, borderColor.a)

	djui_hud_render_rect(x, y, 8, height)
	djui_hud_render_rect(x + width - 8, y, 8, height)
	djui_hud_render_rect(x + 8, y, width - 16, 8)
	djui_hud_render_rect(x + 8, y + height - 8, width - 16, 8)

	djui_hud_set_color(rectColor.r, rectColor.g, rectColor.b, rectColor.a)
	djui_hud_render_rect(x + 8, y + 8, width - 16, height - 16)
end

local function djui_hud_render_fake_header(text, x, y, w, h)
	if not fake_playerlist then return end

	local headerFont = djui_menu_get_theme().panels.hudFontHeader and FONT_HUD or FONT_MENU
	djui_hud_set_font(headerFont)

	local hudFont = headerFont == FONT_HUD
	local scale = hudFont and 4 * 0.7 or 1
	local headerFontOffset = hudFont and 31.65 or 14.5
	local defaultHeaderOffset = y + headerFontOffset

	local textWidth = djui_hud_measure_text(remove_color(text, false))

	djui_hud_render_djui(x, y, w, h, sDjuiTheme.threePanels.rectColor, sDjuiTheme.threePanels.borderColor)
	djui_hud_print_text_with_color(text, x + (w - textWidth * scale) / 2, defaultHeaderOffset, scale,
		255,
		255, 255, 255)
end

local life_icons = {
	[0] = gTextures.mario_head,
	[1] = gTextures.luigi_head,
	[2] = gTextures.toad_head,
	[3] = gTextures.waluigi_head,
	[4] = gTextures.wario_head
}

local function render()
	if gNetworkPlayers[0].currActNum == 99 or gMarioStates[0].action == ACT_INTRO_CUTSCENE or hud_is_hidden() then return end

	local open = djui_attempting_to_open_playerlist() and enable_playerlist
	if not open then return end

	local renderEither = render_platforms or render_devices
	if not renderEither then
		if fake_playerlist then
			gServerSettings.enablePlayerList = 1
		end
		return
	end -- Peak optimisation
	if fake_playerlist then gServerSettings.enablePlayerList = 0 end

	sDjuiTheme = djui_menu_get_theme()
	sDjuiFont = djui_menu_get_font()

	djui_hud_set_resolution(RESOLUTION_DJUI)

	local playerlistX = (djui_hud_get_screen_width() - playerlistWidth) / 2
	local playerlistY = (djui_hud_get_screen_height() - playerlistHeight) / 2

	local text = generate_rainbow_text(djui_language_get("PLAYER_LIST", "PLAYERS"))
	djui_hud_render_fake_header(text, playerlistX, playerlistY, playerlistWidth, playerlistHeight)

	djui_hud_set_font(sDjuiFont)

	local entryNo = -1
	for i = 0, 15 do
		local networkPlayer, os = gNetworkPlayers[i], gPlayerSyncTable[i].os
		local x, y = playerlistX + 24, playerlistY + 88
		local platform, device = 0, 0
		if not networkPlayer.connected then goto continue end
		entryNo = entryNo + 1
		if os == nil then goto continue end

		y = y + entryNo * 36

		if fake_playerlist then
			local entryColor = (entryNo % 2) == 0 and 32 or 16
			djui_hud_set_color(entryColor, entryColor, entryColor, 128)
			djui_hud_render_rect(x, y, playerlistWidth - 48, 32)

			playerNameColor = {
				r = 127 + network_player_get_override_palette_color_channel(networkPlayer, CAP, 0) / 2,
				g = 127 + network_player_get_override_palette_color_channel(networkPlayer, CAP, 1) / 2,
				b = 127 + network_player_get_override_palette_color_channel(networkPlayer, CAP, 2) / 2
			}

			djui_hud_set_color(255, 255, 255, 255)
			djui_hud_render_texture(life_icons[networkPlayer.modelIndex], x, y, 2, 2)
			djui_hud_print_text_with_color(networkPlayer.name, x + 40, y, 1, playerNameColor.r,
				playerNameColor.g, playerNameColor.b, 255)

			local levelName = networkPlayer.overrideLocation ~= "" and networkPlayer.overrideLocation or
				get_level_name(networkPlayer.currCourseNum, networkPlayer.currLevelNum, networkPlayer.currAreaIndex)
			if levelName then
				djui_hud_print_text_with_color(levelName,
					((x + playerlistWidth - 48) - djui_hud_measure_text((string.gsub(levelName, "\\(.-)\\", "")))) - 126,
					y, 1, 0xdc, 0xdc, 0xdc, 255)
			end

			if networkPlayer.currActNum then
				currActNum = networkPlayer.currActNum == 99 and "Done" or
					networkPlayer.currActNum ~= 0 and "# " .. tostring(networkPlayer.currActNum) or
					""
				printedcurrActNum = currActNum
				djui_hud_print_text_with_color(printedcurrActNum,
					x + playerlistWidth - 48 - djui_hud_measure_text(printedcurrActNum) - 18, y, 1, 0xdc, 0xdc, 0xdc, 255)
			end

			if networkPlayer.description then
				djui_hud_print_text_with_color(networkPlayer.description,
					(x + 278) - (djui_hud_measure_text((string.gsub(networkPlayer.description, "\\(.-)\\", ""))) / 2), y,
					1, networkPlayer.descriptionR, networkPlayer.descriptionG, networkPlayer.descriptionB,
					networkPlayer.descriptionA)
			end
		end

		x = playerlistX + 68 + djui_hud_measure_text(remove_color(networkPlayer.name, false))

		-- djui_hud_print_text(os, x, y, 1)

		djui_hud_set_color(255, 255, 255, 255)

		if os == "Unknown" then goto continue end
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

	if not fake_playerlist then return end

	x = djui_hud_get_screen_width() / 2 + 363
	y = (djui_hud_get_screen_height() - modlistHeight) / 2

	text = generate_rainbow_text(djui_language_get("MODLIST", "MODS"))
	djui_hud_render_fake_header(text, x, y, modlistWidth, modlistHeight)

	djui_hud_set_font(sDjuiFont)

	for i, mod in next, mod_list do
		v = (i % 2) ~= 0 and 32 or 16
		djui_hud_set_color(v, v, v, 128)
		local entryWidth = modlistWidth - 48
		local entryX = x + 24
		local entryY = y + 52 + i * 36
		djui_hud_render_rect(entryX, entryY, entryWidth, 32)
		local stringSubCount = 23
		local inColor = false
		for i = 1, #mod do
			if mod:sub(i, i) == "\\" then
				inColor = not inColor
			end
			if inColor then
				stringSubCount = stringSubCount + 1
			end
		end
		djui_hud_print_text_with_color(mod:sub(1, stringSubCount), entryX, entryY, 1, 0xdc, 0xdc, 0xdc, 255)
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
		for i = 0, #gActiveMods do
			table.insert(mod_list, gActiveMods[i].name)
		end
		modlistHeight = 108 + 36 * #mod_list
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
