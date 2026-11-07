local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Menu = require("ui/widget/menu")
local InputDialog = require("ui/widget/inputdialog")
local InfoMessage = require("ui/widget/infomessage")
local ImageWidget = require("ui/widget/imagewidget")
local ImageViewer = require("ui/widget/imageviewer")
local Button = require("ui/widget/button")
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local HorizontalSpan = require("ui/widget/horizontalspan")
local CenterContainer = require("ui/widget/container/centercontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local TitleBar = require("ui/widget/titlebar")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local TextViewer = require("ui/widget/textviewer")
local Font = require("ui/font")
local Size = require("ui/size")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Screen = Device.screen
local DataStorage = require("datastorage")
local util = require("util")
local rapidjson = require("rapidjson")
local http = require("socket.http")
local https_ok, https_mod = pcall(require, "ssl.https")
local https = https_ok and https_mod or nil
local multi_ok, multi_mod = pcall(require, "ui/widget/multiinputdialog")
local MultiInputDialog = multi_ok and multi_mod or nil
local socketutil = require("socketutil")
local ltn12 = require("ltn12")

local API_VERSION = "1.12.0"
local CLIENT_NAME = "koreader-navidrome"

-- Iconos del conjunto FontAwesome que trae la fuente Nerd Font incluida en KOReader
local ICONS = {
    player   = "\u{f025}",
    search   = "\u{f002}",
    playlist = "\u{f03a}", -- Icono de Listas (fa-list)
    recent   = "\u{f017}",
    random   = "\u{f074}",
    top      = "\u{f06d}",
    discover = "\u{f005}",
    lyrics   = "\u{f022}",
    config   = "\u{f013}",
    artist   = "\u{f130}",
    album    = "\u{f001}",
    cover    = "\u{f03e}",
    add      = "\u{f067}",
    prev     = "\u{f048}",
    play     = "\u{f04b}",
    stop     = "\u{f04d}",
    next     = "\u{f051}",
    shuffle  = "\u{f074}",
    refresh  = "\u{f021}",
    close    = "\u{f00d}",
    trash    = "\u{f1f8}",
}

--------------------------------------------------------------------------
-- Diálogo del reproductor (Now Playing)
--------------------------------------------------------------------------

local PlayerDialog = InputContainer:extend{
    plugin = nil,
    is_playing = false,
    cover_id = nil,
    title_text = "",
    subtitle_text = "",
    modal = true,
}

function PlayerDialog:init()
local plugin = self.plugin
local content_width = Screen:getWidth() * 0.8
self.cover_size = math.floor(Screen:getWidth() * 0.6)

self.cover_holder = CenterContainer:new{
    dimen = Geom:new{ w = self.cover_size, h = self.cover_size },
}
self.title_widget = TextBoxWidget:new{
    text = self.title_text or "",
    width = content_width,
    face = Font:getFace("cfont", 20),
    alignment = "center",
}
self.subtitle_widget = TextBoxWidget:new{
    text = self.subtitle_text or "",
    width = content_width,
    face = Font:getFace("cfont", 16),
    alignment = "center",
}
self.text_group = VerticalGroup:new{
    align = "center",
    self.title_widget,
    self.subtitle_widget,
}

local btn_size = Screen:scaleBySize(52)
self.btn_size = btn_size
local function player_button(icon, callback)
return Button:new{
    text = icon,
    width = btn_size,
    height = btn_size,
    margin = 0,
    padding = Screen:scaleBySize(2),
    text_font_size = 22,
    callback = callback,
}
end
self.playpause_btn = player_button(
    self.is_playing and ICONS.stop or ICONS.play,
    function() plugin:playerToggle(self.is_playing) end)
self.buttons_row = HorizontalGroup:new{
    player_button(ICONS.prev, function() plugin:playerSkip(-1) end),
    self.playpause_btn,
    player_button(ICONS.next, function() plugin:playerSkip(1) end),
    player_button(ICONS.shuffle, function() plugin:playerShuffle() end),
    player_button(ICONS.refresh, function() plugin:refreshNowPlaying() end),
    player_button(ICONS.close, function() self:onClose() end),
}

self.content_group = VerticalGroup:new{
    align = "center",
    self.cover_holder,
    self.text_group,
    self.buttons_row,
}

self[1] = CenterContainer:new{
    dimen = Screen:getSize(),
    FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        radius = Size.radius.window,
        padding = Size.padding.large,
        bordersize = Size.border.window,
        self.content_group,
    },
}

self.key_events = { Close = { { "Back" }, { "Home" } } }
self.ges_events = {
    TapAnywhere = {
        GestureRange:new{
            ges = "tap",
            range = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() },
        },
    },
}

self:setCover(self.cover_id)
end

function PlayerDialog:setText(title, subtitle, is_playing)
if title then self.title_widget:setText(title) end
    if subtitle then self.subtitle_widget:setText(subtitle) end
        if is_playing ~= nil then
            self.is_playing = is_playing
            self.playpause_btn:setText(is_playing and ICONS.stop or ICONS.play, self.btn_size)
            end
            self.text_group:resetLayout()
            self.content_group:resetLayout()
            end

            function PlayerDialog:setCover(cover_id)
            local plugin = self.plugin
            self.cover_id = cover_id
            local size = 400
            local path = plugin:getCachedCoverPath(cover_id, size)
            local key = tostring(cover_id or "") .. "|" .. tostring(path or "")
            if self.cover_key == key and self.cover_holder[1] then return end

                self.cover_holder:clear()
                if path then
                    table.insert(self.cover_holder, ImageWidget:new{
                        file = path,
                        width = self.cover_size,
                        height = self.cover_size,
                    })
                    else
                        table.insert(self.cover_holder, TextWidget:new{
                            text = ICONS.cover,
                            face = Font:getFace("cfont", 60),
                        })
                        end
                        self.cover_key = key
                        self.content_group:resetLayout()
                        end

                        function PlayerDialog:onTapAnywhere() return true end

                        function PlayerDialog:onClose()
                        UIManager:close(self)
                        return true
                        end

                        function PlayerDialog:onCloseWidget()
                        if self.plugin and self.plugin.player_dialog == self then
                            self.plugin.player_dialog = nil
                            end
                            UIManager:setDirty(nil, "ui")
                            if self.plugin and self.plugin.home_screen then
                                UIManager:nextTick(function() self.plugin:refreshHome() end)
                                end
                                end

                                --------------------------------------------------------------------------
                                -- Pantalla principal (Home)
                                --------------------------------------------------------------------------

                                local TapFrame = InputContainer:extend{
                                    content = nil,
                                    callback = nil,
                                    enabled = true,
                                    radius = nil,
                                    bordersize = Size.border.window,
                                    padding = 0,
                                    background = Blitbuffer.COLOR_WHITE,
                                }

                                function TapFrame:init()
                                self.frame = FrameContainer:new{
                                    background = self.background,
                                    radius = self.radius or Size.radius.window,
                                    bordersize = self.bordersize,
                                    padding = self.padding, margin = 0,
                                    self.content,
                                }
                                self[1] = self.frame
                                self.dimen = self.frame:getSize()
                                self.ges_events = {
                                    TapSelect = { GestureRange:new{ ges = "tap", range = self.dimen } },
                                }
                                end

                                function TapFrame:onTapSelect()
                                if not self.enabled or not self.callback then return true end
                                    if G_reader_settings:isFalse("flash_ui") then
                                        self.callback()
                                        return true
                                        end
                                        self.frame.invert = true
                                        UIManager:widgetInvert(self.frame, self.dimen.x, self.dimen.y)
                                        UIManager:setDirty(nil, "fast", self.dimen)
                                        UIManager:forceRePaint()
                                        UIManager:yieldToEPDC()
                                        self.frame.invert = false
                                        UIManager:widgetInvert(self.frame, self.dimen.x, self.dimen.y)
                                        UIManager:setDirty(nil, "fast", self.dimen)
                                        self.callback()
                                        return true
                                        end

                                        local HomeScreen = InputContainer:extend{
                                            plugin = nil,
                                            covers_fullscreen = true,
                                        }

                                        function HomeScreen:init()
                                        local plugin = self.plugin
                                        local screen_w = Screen:getWidth()
                                        local screen_h = Screen:getHeight()
                                        local h_pad = Size.padding.fullscreen
                                        local gap = Screen:scaleBySize(8)
                                        local content_w = screen_w - 2 * h_pad

                                        local config = plugin:getConfig()
                                        local host = config.url:gsub("^https?://", "")
                                        self.title_bar = TitleBar:new{
                                            width = screen_w, fullscreen = true, align = "left",
                                            title = "Navidrome Jukebox",
                                            subtitle = host ~= "" and host or "Sin configurar",
                                            with_bottom_line = true, bottom_line_h_padding = h_pad,
                                            close_callback = function() self:onClose() end,
                                            show_parent = self,
                                        }

                                        local card_pad = Size.padding.large
                                        local card_inner_w = content_w - 2 * Size.border.window - 2 * card_pad
                                        self.cover_size = Screen:scaleBySize(118)
                                        local btn_size = Screen:scaleBySize(44)
                                        local col_gap = Size.padding.large
                                        local col_w = card_inner_w - self.cover_size - col_gap

                                        self.cover_holder = CenterContainer:new{ dimen = Geom:new{ w = self.cover_size, h = self.cover_size } }
                                        self.cover_key = nil

                                        self.status_widget = TextWidget:new{
                                            text = "", face = Font:getFace("cfont", 13), bold = true, fgcolor = Blitbuffer.COLOR_DARK_GRAY, max_width = col_w,
                                        }
                                        self.track_widget = TextWidget:new{ text = "", face = Font:getFace("cfont", 19), bold = true, max_width = col_w }
                                        self.artist_widget = TextWidget:new{ text = "", face = Font:getFace("cfont", 15), max_width = col_w }

                                        local function line(widget) return LeftContainer:new{ dimen = Geom:new{ w = col_w, h = widget:getSize().h }, widget } end

                                        local function control(icon, callback)
                                        return Button:new{
                                            text = icon, width = btn_size, height = btn_size, margin = 0, padding = 0,
                                            radius = Size.radius.button, text_font_size = 18, callback = callback, show_parent = self,
                                        }
                                        end

                                        local play_size = Screen:scaleBySize(52)
                                        self.playpause_icon = TextWidget:new{
                                            text = ICONS.play, face = Font:getFace("cfont", 20), fgcolor = Blitbuffer.COLOR_WHITE,
                                        }
                                        self.playpause_btn = TapFrame:new{
                                            radius = Size.radius.button, bordersize = Size.border.button, background = Blitbuffer.COLOR_BLACK,
                                            callback = function() plugin:homeToggle() end,
                                            content = CenterContainer:new{
                                                dimen = Geom:new{ w = play_size - 2 * Size.border.button, h = play_size - 2 * Size.border.button },
                                                self.playpause_icon,
                                            },
                                        }
                                        self.controls = HorizontalGroup:new{
                                            align = "center",
                                            control(ICONS.prev, function() plugin:homeSkip(-1) end),
                                            HorizontalSpan:new{ width = gap }, self.playpause_btn, HorizontalSpan:new{ width = gap },
                                            control(ICONS.next, function() plugin:homeSkip(1) end),
                                            HorizontalSpan:new{ width = gap * 2 },
                                            control(ICONS.player, function() plugin:showNowPlaying() end),
                                        }

                                        local info_col = VerticalGroup:new{
                                            align = "left",
                                            line(self.status_widget), VerticalSpan:new{ width = Screen:scaleBySize(2) },
                                            line(self.track_widget), line(self.artist_widget), VerticalSpan:new{ width = Screen:scaleBySize(8) },
                                            self.controls,
                                        }
                                        local col_h = math.max(self.cover_size, info_col:getSize().h)
                                        self.card = TapFrame:new{
                                            padding = card_pad,
                                            callback = function() plugin:showNowPlaying() end,
                                            content = HorizontalGroup:new{
                                                align = "center",
                                                CenterContainer:new{ dimen = Geom:new{ w = self.cover_size, h = col_h }, self.cover_holder },
                                                HorizontalSpan:new{ width = col_gap },
                                                LeftContainer:new{ dimen = Geom:new{ w = col_w, h = col_h }, info_col },
                                            },
                                        }

                                        ----------------------------------------------------------------------
                                        -- Cuadrícula de secciones
                                        ----------------------------------------------------------------------
                                        local tiles = {
                                            { ICONS.search,   "Buscar música",       function() plugin:showSearch() end },
                                            { ICONS.playlist, "Mis Listas",          function() plugin:showPlaylists() end },
                                            { ICONS.recent,   "Recién añadidos",     function() plugin:showRecentAlbums() end },
                                            { ICONS.random,   "Álbumes aleatorios",  function() plugin:showRandomAlbums() end },
                                            { ICONS.top,      "Más escuchados",      function() plugin:showTopArtists() end },
                                            { ICONS.discover, "Descubre artistas",   function() plugin:showRecommendedArtists() end },
                                            { ICONS.lyrics,   "Letra",               function() plugin:showLyrics() end },
                                            { ICONS.config,   "Configurar servidor", function() plugin:showConfigDialog() end },
                                        }
                                        local columns = 2
                                        local rows = math.ceil(#tiles / columns)
                                        local section_pad = Screen:scaleBySize(12)
                                        local section_title_h = Screen:scaleBySize(24)
                                        local used_h = self.title_bar:getHeight() + section_pad + self.card:getSize().h + section_pad + section_title_h + h_pad
                                        local grid_h = screen_h - used_h
                                        local tile_w = math.floor((content_w - gap * (columns - 1)) / columns)
                                        local tile_h = math.floor((grid_h - gap * (rows - 1)) / rows)
                                        tile_h = math.max(Screen:scaleBySize(64), math.min(tile_h, Screen:scaleBySize(120)))

                                        local tile_border = Size.border.window
                                        local tile_inner_w = tile_w - 2 * tile_border
                                        local tile_inner_h = tile_h - 2 * tile_border
                                        local icon_face = Font:getFace("cfont", 30)
                                        local label_face = Font:getFace("cfont", 15)
                                        local function tile(def)
                                        local label = TextBoxWidget:new{
                                            text = def[2], face = label_face, bold = true,
                                            width = tile_inner_w - 2 * Size.padding.default, alignment = "center",
                                        }
                                        return TapFrame:new{
                                            bordersize = tile_border, callback = def[3],
                                            content = CenterContainer:new{
                                                dimen = Geom:new{ w = tile_inner_w, h = tile_inner_h },
                                                VerticalGroup:new{
                                                    align = "center",
                                                    TextWidget:new{ text = def[1], face = icon_face },
                                                    VerticalSpan:new{ width = Screen:scaleBySize(4) }, label,
                                                },
                                            },
                                        }
                                        end

                                        local grid = VerticalGroup:new{ align = "left" }
                                        for r = 1, rows do
                                            local row = HorizontalGroup:new{ align = "center" }
                                            for c = 1, columns do
                                                local def = tiles[(r - 1) * columns + c]
                                                if def then
                                                    table.insert(row, tile(def))
                                                    if c < columns then table.insert(row, HorizontalSpan:new{ width = gap }) end
                                                        end
                                                        end
                                                        table.insert(grid, row)
                                                        if r < rows then table.insert(grid, VerticalSpan:new{ width = gap }) end
                                                            end

                                                            local body = VerticalGroup:new{
                                                                align = "left",
                                                                VerticalSpan:new{ width = section_pad }, self.card, VerticalSpan:new{ width = section_pad },
                                                                LeftContainer:new{
                                                                    dimen = Geom:new{ w = content_w, h = section_title_h },
                                                                    TextWidget:new{ text = "EXPLORAR", face = Font:getFace("cfont", 13), bold = true, fgcolor = Blitbuffer.COLOR_DARK_GRAY },
                                                                },
                                                                grid,
                                                            }

                                                            self[1] = FrameContainer:new{
                                                                background = Blitbuffer.COLOR_WHITE, bordersize = 0, padding = 0, width = screen_w, height = screen_h,
                                                                VerticalGroup:new{
                                                                    align = "left", self.title_bar,
                                                                    HorizontalGroup:new{ HorizontalSpan:new{ width = h_pad }, body },
                                                                },
                                                            }
                                                            self.dimen = Geom:new{ x = 0, y = 0, w = screen_w, h = screen_h }

                                                            self.key_events = { Close = { { "Back" }, { "Home" } } }
                                                            self.ges_events = { TapAnywhere = { GestureRange:new{ ges = "tap", range = self.dimen } } }

                                                            self:setNowPlaying({ status = "CARGANDO…", title = "Consultando el servidor", subtitle = "", is_playing = false, cover_id = nil })
                                                            end

                                                            function HomeScreen:setNowPlaying(state)
                                                            self.status_widget:setText(state.status or "")
                                                            self.track_widget:setText(state.title or "")
                                                            self.artist_widget:setText(state.subtitle or "")
                                                            self.playpause_icon:setText(state.is_playing and ICONS.stop or ICONS.play)
                                                            self:setCover(state.cover_id)
                                                            end

                                                            function HomeScreen:setCover(cover_id)
                                                            local path = self.plugin:getCachedCoverPath(cover_id, 400)
                                                            local key = tostring(cover_id or "") .. "|" .. tostring(path or "")
                                                            if self.cover_key == key and self.cover_holder[1] then return end
                                                                self.cover_holder:clear()
                                                                if path then
                                                                    table.insert(self.cover_holder, FrameContainer:new{
                                                                        bordersize = 0, padding = 0, radius = Size.radius.default,
                                                                        ImageWidget:new{ file = path, width = self.cover_size, height = self.cover_size },
                                                                    })
                                                                    else
                                                                        table.insert(self.cover_holder, FrameContainer:new{
                                                                            bordersize = Size.border.thin, color = Blitbuffer.COLOR_DARK_GRAY,
                                                                            background = Blitbuffer.COLOR_LIGHT_GRAY, radius = Size.radius.default, padding = 0,
                                                                            CenterContainer:new{
                                                                                dimen = Geom:new{ w = self.cover_size - 2 * Size.border.thin, h = self.cover_size - 2 * Size.border.thin },
                                                                                TextWidget:new{ text = ICONS.album, face = Font:getFace("cfont", 36), fgcolor = Blitbuffer.COLOR_DARK_GRAY },
                                                                            },
                                                                        })
                                                                        end
                                                                        self.cover_key = key
                                                                        end

                                                                        function HomeScreen:refreshCard()
                                                                        UIManager:setDirty(self, function() return "ui", self.card.dimen end)
                                                                        end

                                                                        function HomeScreen:onTapAnywhere() return true end

                                                                        function HomeScreen:onClose() UIManager:close(self); return true end

                                                                        function HomeScreen:onCloseWidget()
                                                                        if self.plugin and self.plugin.home_screen == self then self.plugin.home_screen = nil end
                                                                            UIManager:setDirty(nil, "ui")
                                                                            end

                                                                            local NavidromePlugin = WidgetContainer:extend{
                                                                                name = "navidrome",
                                                                                is_doc_only = false,
                                                                            }

                                                                            --------------------------------------------------------------------------
                                                                            -- Inicialización
                                                                            --------------------------------------------------------------------------

                                                                            function NavidromePlugin:init()
                                                                            self.ui.menu:registerToMainMenu(self)
                                                                            self:ensureCacheDir()
                                                                            end

                                                                            function NavidromePlugin:ensureCacheDir()
                                                                            local base
                                                                            local ok, path = pcall(function() return DataStorage:getDataDir() end)
                                                                            if ok and path then base = path .. "/cache/navidrome_covers" else base = "/tmp/navidrome_covers" end
                                                                                local created_ok = pcall(util.makePath, base)
                                                                                if not created_ok or not util.pathExists(base) then
                                                                                    base = "/tmp/navidrome_covers"
                                                                                    pcall(util.makePath, base)
                                                                                    end
                                                                                    self.cover_cache_dir = base
                                                                                    end

                                                                                    function NavidromePlugin:addToMainMenu(menu_items)
                                                                                    menu_items.navidrome = {
                                                                                        text = "Navidrome Jukebox", sorting_hint = "tools",
                                                                                        callback = function() self:showMainMenu() end,
                                                                                    }
                                                                                    end

                                                                                    --------------------------------------------------------------------------
                                                                                    -- Configuración y ajustes persistentes
                                                                                    --------------------------------------------------------------------------

                                                                                    function NavidromePlugin:getSettingsFile()
                                                                                    local ok, path = pcall(function() return DataStorage:getDataDir() end)
                                                                                    local dir = (ok and path) and (path .. "/settings") or "/tmp"
                                                                                    pcall(util.makePath, dir)
                                                                                    return dir .. "/navidrome_plugin.json"
                                                                                    end

                                                                                    function NavidromePlugin:loadPluginSettings()
                                                                                    if self.cached_settings then return self.cached_settings end
                                                                                        local settings = {}
                                                                                        local filename = self:getSettingsFile()
                                                                                        if util and util.fileExists and util.fileExists(filename) then
                                                                                            local f = io.open(filename, "r")
                                                                                            if f then
                                                                                                local content = f:read("*a")
                                                                                                f:close()
                                                                                                local ok, parsed = pcall(rapidjson.decode, content)
                                                                                                if ok and type(parsed) == "table" then settings = parsed end
                                                                                                    end
                                                                                                    end
                                                                                                    self.cached_settings = settings
                                                                                                    return settings
                                                                                                    end

                                                                                                    function NavidromePlugin:persistPluginSettings()
                                                                                                    local filename = self:getSettingsFile()
                                                                                                    local ok, json_str = pcall(rapidjson.encode, self.cached_settings or {})
                                                                                                    if ok and json_str then
                                                                                                        local f = io.open(filename, "w")
                                                                                                        if f then f:write(json_str); f:close() end
                                                                                                            end
                                                                                                            end

                                                                                                            function NavidromePlugin:getSetting(key, default)
                                                                                                            if not self.cached_settings then self:loadPluginSettings() end
                                                                                                                if self.cached_settings[key] ~= nil and self.cached_settings[key] ~= "" then return self.cached_settings[key] end
                                                                                                                    if G_reader_settings then
                                                                                                                        local value = G_reader_settings:readSetting("navidrome_" .. key)
                                                                                                                        if value ~= nil and value ~= "" then
                                                                                                                            self.cached_settings[key] = value; return value
                                                                                                                            end
                                                                                                                            end
                                                                                                                            return default
                                                                                                                            end

                                                                                                                            function NavidromePlugin:saveSetting(key, value)
                                                                                                                            if not self.cached_settings then self:loadPluginSettings() end
                                                                                                                                self.cached_settings[key] = value
                                                                                                                                if G_reader_settings then
                                                                                                                                    G_reader_settings:saveSetting("navidrome_" .. key, value)
                                                                                                                                    if type(G_reader_settings.flush) == "function" then pcall(function() G_reader_settings:flush() end) end
                                                                                                                                        end
                                                                                                                                        self:persistPluginSettings()
                                                                                                                                        end

                                                                                                                                        function NavidromePlugin:getConfig()
                                                                                                                                        local raw_url = tostring(self:getSetting("url", "")):gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
                                                                                                                                        local user = tostring(self:getSetting("user", "")):gsub("^%s+", ""):gsub("%s+$", "")
                                                                                                                                        local pass = tostring(self:getSetting("pass", ""))
                                                                                                                                        if raw_url ~= "" and not raw_url:match("^https?://") then raw_url = "http://" .. raw_url end
                                                                                                                                            return { url = raw_url, user = user, pass = pass }
                                                                                                                                            end

                                                                                                                                            function NavidromePlugin:validateConfig()
                                                                                                                                            local config = self:getConfig()
                                                                                                                                            if config.url == "" then return nil, "Falta la URL del servidor Navidrome.\nEntra en 'Configurar servidor y cuenta'." end
                                                                                                                                                if config.user == "" then return nil, "Falta el nombre de usuario de Navidrome.\nEntra en 'Configurar servidor y cuenta'." end
                                                                                                                                                    if config.pass == "" then return nil, "Falta la contraseña de Navidrome.\nEntra en 'Configurar servidor y cuenta'." end
                                                                                                                                                        return config
                                                                                                                                                        end

                                                                                                                                                        --------------------------------------------------------------------------
                                                                                                                                                        -- Utilidades HTTP / Subsonic API
                                                                                                                                                        --------------------------------------------------------------------------

                                                                                                                                                        function NavidromePlugin:urlEncode(value)
                                                                                                                                                        local str = tostring(value or "")
                                                                                                                                                        str = str:gsub("\n", "\r\n")
                                                                                                                                                        str = str:gsub("([^%w%-%_%.%~])", function(c) return string.format("%%%02X", string.byte(c)) end)
                                                                                                                                                        return str
                                                                                                                                                        end

                                                                                                                                                        function NavidromePlugin:makeQuery(params)
                                                                                                                                                        local encoded = {}
                                                                                                                                                        for _, pair in ipairs(params or {}) do
                                                                                                                                                            if pair[2] ~= nil then table.insert(encoded, self:urlEncode(pair[1]) .. "=" .. self:urlEncode(pair[2])) end
                                                                                                                                                                end
                                                                                                                                                                return table.concat(encoded, "&")
                                                                                                                                                                end

                                                                                                                                                                function NavidromePlugin:apiRequest(endpoint, params)
                                                                                                                                                                local config, cfg_err = self:validateConfig()
                                                                                                                                                                if not config then return nil, cfg_err end

                                                                                                                                                                    local query_params = {
                                                                                                                                                                        { "u", config.user }, { "p", config.pass }, { "v", API_VERSION }, { "c", CLIENT_NAME }, { "f", "json" },
                                                                                                                                                                    }
                                                                                                                                                                    for _, pair in ipairs(params or {}) do table.insert(query_params, pair) end

                                                                                                                                                                        local url = config.url .. "/rest/" .. endpoint .. "?" .. self:makeQuery(query_params)
                                                                                                                                                                        local response_body = {}

                                                                                                                                                                        local is_https = url:match("^https://") ~= nil
                                                                                                                                                                        if is_https and not https then return nil, "El servidor usa HTTPS pero el módulo SSL (ssl.https) no está disponible en este KOReader." end

                                                                                                                                                                            local req_func = (is_https and https) and https.request or http.request

                                                                                                                                                                            -- Bucle de reintentos silencioso por si el Wi-Fi del e-reader se está despertando
                                                                                                                                                                            local max_retries = 2
                                                                                                                                                                            local ok, result, code, headers, status

                                                                                                                                                                            for attempt = 1, max_retries do
                                                                                                                                                                                response_body = {}
                                                                                                                                                                                pcall(function() http.TIMEOUT = 10 end)
                                                                                                                                                                                -- Aumentamos el timeout de conexión a 8s
                                                                                                                                                                                local CONNECT_TIMEOUT, TOTAL_TIMEOUT = 8, 15
                                                                                                                                                                                if socketutil and socketutil.set_timeout then pcall(function() socketutil:set_timeout(CONNECT_TIMEOUT, TOTAL_TIMEOUT) end) end

                                                                                                                                                                                    -- Se añade Connection: close para matar sockets zombies y evitar "No route to host"
                                                                                                                                                                                    ok, result, code, headers, status = pcall(req_func, {
                                                                                                                                                                                        url = url,
                                                                                                                                                                                        method = "GET",
                                                                                                                                                                                        headers = { ["Connection"] = "close" },
                                                                                                                                                                                        sink = ltn12.sink.table(response_body)
                                                                                                                                                                                    })

                                                                                                                                                                                    if socketutil and socketutil.reset_timeout then pcall(function() socketutil:reset_timeout() end) end

                                                                                                                                                                                        -- Si fue éxito de red (result == 1), salimos del bucle
                                                                                                                                                                                        if ok and result == 1 then break end
                                                                                                                                                                                            end

                                                                                                                                                                                            if not ok or result ~= 1 then
                                                                                                                                                                                                local err_msg = (not ok) and result or code
                                                                                                                                                                                                local desc = (socketutil and socketutil.describe_error) and socketutil.describe_error(err_msg) or err_msg
                                                                                                                                                                                                return nil, "No se pudo conectar al servidor:\n" .. tostring(desc or err_msg)
                                                                                                                                                                                                end

                                                                                                                                                                                                local status_num = tonumber(code)
                                                                                                                                                                                                if status_num ~= 200 then
                                                                                                                                                                                                    if status_num == 401 then return nil, "Error 401: Usuario o contraseña incorrectos en Navidrome."
                                                                                                                                                                                                        elseif status_num == 404 then return nil, "Error 404: Ruta de API no encontrada en '" .. tostring(config.url) .. "'."
                                                                                                                                                                                                            elseif status_num == 403 then return nil, "Error 403: Permisos insuficientes en Navidrome." end
                                                                                                                                                                                                                local desc = (socketutil and socketutil.describe_error) and socketutil.describe_error(result) or status
                                                                                                                                                                                                                return nil, tostring(desc or status or ("Error HTTP " .. tostring(code or "desconocido")))
                                                                                                                                                                                                                end

                                                                                                                                                                                                                local decoded_ok, data = pcall(rapidjson.decode, table.concat(response_body))
                                                                                                                                                                                                                if not decoded_ok or type(data) ~= "table" then return nil, "El servidor respondió pero no devolvió JSON válido." end

                                                                                                                                                                                                                    local response = data["subsonic-response"]
                                                                                                                                                                                                                    if type(response) ~= "table" then return nil, "Respuesta inesperada del servidor Navidrome." end
                                                                                                                                                                                                                        if response.status == "failed" then
                                                                                                                                                                                                                            local message = response.error and response.error.message
                                                                                                                                                                                                                            return nil, "Navidrome: " .. tostring(message or "la solicitud falló")
                                                                                                                                                                                                                            end
                                                                                                                                                                                                                            return response
                                                                                                                                                                                                                            end

                                                                                                                                                                                                                            --------------------------------------------------------------------------
                                                                                                                                                                                                                            -- Helpers varios
                                                                                                                                                                                                                            --------------------------------------------------------------------------

                                                                                                                                                                                                                            function NavidromePlugin:showMessage(text)
                                                                                                                                                                                                                            local msg = InfoMessage:new{ text = text }
                                                                                                                                                                                                                            UIManager:show(msg)
                                                                                                                                                                                                                            return msg
                                                                                                                                                                                                                            end

                                                                                                                                                                                                                            function NavidromePlugin:showError(err)
                                                                                                                                                                                                                            self:showMessage("Navidrome\n" .. tostring(err or "Error desconocido"))
                                                                                                                                                                                                                            end

                                                                                                                                                                                                                            function NavidromePlugin:safeList(value)
                                                                                                                                                                                                                            if type(value) ~= "table" then return {} end
                                                                                                                                                                                                                                if value.id or value.name or value.title then return { value } end
                                                                                                                                                                                                                                    return value
                                                                                                                                                                                                                                    end

                                                                                                                                                                                                                                    function NavidromePlugin:safeStr(value, fallback)
                                                                                                                                                                                                                                    if type(value) == "string" then return value end
                                                                                                                                                                                                                                        if type(value) == "number" then return tostring(value) end
                                                                                                                                                                                                                                            return fallback or ""
                                                                                                                                                                                                                                            end

                                                                                                                                                                                                                                            --------------------------------------------------------------------------
                                                                                                                                                                                                                                            -- Carátulas: descarga + caché en disco
                                                                                                                                                                                                                                            --------------------------------------------------------------------------

                                                                                                                                                                                                                                            function NavidromePlugin:getCoverArtPath(cover_id, size)
                                                                                                                                                                                                                                            if not cover_id or cover_id == "" then return nil end
                                                                                                                                                                                                                                                local config = self:getConfig()
                                                                                                                                                                                                                                                if config.url == "" then return nil end

                                                                                                                                                                                                                                                    size = tonumber(size) or 300
                                                                                                                                                                                                                                                    local filename = self.cover_cache_dir .. "/" .. tostring(cover_id) .. "_" .. tostring(size) .. ".jpg"

                                                                                                                                                                                                                                                    if util.fileExists(filename) then return filename end

                                                                                                                                                                                                                                                        local query = self:makeQuery({
                                                                                                                                                                                                                                                            { "u", config.user }, { "p", config.pass }, { "v", API_VERSION }, { "c", CLIENT_NAME },
                                                                                                                                                                                                                                                            { "id", cover_id }, { "size", size },
                                                                                                                                                                                                                                                        })
                                                                                                                                                                                                                                                        local url = config.url .. "/rest/getCoverArt.view?" .. query
                                                                                                                                                                                                                                                        local tmp_filename = filename .. ".part"
                                                                                                                                                                                                                                                        local out_file = io.open(tmp_filename, "wb")
                                                                                                                                                                                                                                                        if not out_file then return nil end

                                                                                                                                                                                                                                                            socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
                                                                                                                                                                                                                                                            -- Añadimos Connection: close también a las descargas de imágenes
                                                                                                                                                                                                                                                            local ok, result, code = pcall(http.request, {
                                                                                                                                                                                                                                                                url = url,
                                                                                                                                                                                                                                                                method = "GET",
                                                                                                                                                                                                                                                                headers = { ["Connection"] = "close" },
                                                                                                                                                                                                                                                                sink = ltn12.sink.file(out_file)
                                                                                                                                                                                                                                                            })
                                                                                                                                                                                                                                                            socketutil:reset_timeout()

                                                                                                                                                                                                                                                            if not ok or result ~= 1 or tonumber(code) ~= 200 then
                                                                                                                                                                                                                                                                os.remove(tmp_filename); return nil
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                os.remove(filename)
                                                                                                                                                                                                                                                                if not os.rename(tmp_filename, filename) then
                                                                                                                                                                                                                                                                os.remove(tmp_filename); return nil
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                return filename
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:showCoverArt(cover_id, title)
                                                                                                                                                                                                                                                                if not cover_id or cover_id == "" then self:showMessage("Este elemento no tiene carátula disponible."); return end
                                                                                                                                                                                                                                                                local path = self:getCoverArtPath(cover_id, 600)
                                                                                                                                                                                                                                                                if not path then self:showMessage("No se pudo descargar la carátula."); return end
                                                                                                                                                                                                                                                                UIManager:show(ImageViewer:new{
                                                                                                                                                                                                                                                                file = path, fullscreen = true, with_title_bar = true, title_text = title or "Carátula",
                                                                                                                                                                                                                                                                })
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                --------------------------------------------------------------------------
                                                                                                                                                                                                                                                                -- Menú principal
                                                                                                                                                                                                                                                                --------------------------------------------------------------------------

                                                                                                                                                                                                                                                                function NavidromePlugin:showMainMenu()
                                                                                                                                                                                                                                                                if self.home_screen then UIManager:close(self.home_screen) end
                                                                                                                                                                                                                                                                self.home_screen = HomeScreen:new{ plugin = self }
                                                                                                                                                                                                                                                                UIManager:show(self.home_screen)
                                                                                                                                                                                                                                                                UIManager:nextTick(function() self:refreshHome() end)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:refreshHome()
                                                                                                                                                                                                                                                                local home = self.home_screen
                                                                                                                                                                                                                                                                if not home then return end
                                                                                                                                                                                                                                                                local config = self:validateConfig()
                                                                                                                                                                                                                                                                if not config then
                                                                                                                                                                                                                                                                home:setNowPlaying({ status = "SIN CONFIGURAR", title = "Conecta tu servidor", subtitle = "Toca «Configurar servidor» para empezar" })
                                                                                                                                                                                                                                                                home:refreshCard(); return
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                local state, err = self:getJukeboxState()
                                                                                                                                                                                                                                                                if not state then
                                                                                                                                                                                                                                                                home:setNowPlaying({ status = "SIN CONEXIÓN", title = "No se pudo consultar el servidor", subtitle = tostring(err or ""):gsub("\n.*$", "") })
                                                                                                                                                                                                                                                                home:refreshCard(); return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                home:setNowPlaying({
                                                                                                                                                                                                                                                                status = state.song and (state.is_playing and "EN REPRODUCCIÓN" or "EN PAUSA") or "COLA VACÍA",
                                                                                                                                                                                                                                                                title = state.title, subtitle = state.subtitle, is_playing = state.is_playing, cover_id = state.cover_id,
                                                                                                                                                                                                                                                                })
                                                                                                                                                                                                                                                                home:refreshCard()

                                                                                                                                                                                                                                                                local cover_id = state.cover_id
                                                                                                                                                                                                                                                                if cover_id and cover_id ~= "" and not self:getCachedCoverPath(cover_id, 400) then
                                                                                                                                                                                                                                                                UIManager:nextTick(function()
                                                                                                                                                                                                                                                                if self.home_screen ~= home then return end
                                                                                                                                                                                                                                                                if self:getCoverArtPath(cover_id, 400) then
                                                                                                                                                                                                                                                                home:setCover(cover_id); home:refreshCard()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:homeToggle()
                                                                                                                                                                                                                                                                local action = self.last_is_playing and "stop" or "start"
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("jukeboxControl.view", {{ "action", action }})
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                self:refreshHome()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:homeSkip(direction)
                                                                                                                                                                                                                                                                local current = self.player_current_index or 0
                                                                                                                                                                                                                                                                local length = self.player_queue_length or 0
                                                                                                                                                                                                                                                                if length == 0 then self:showMessage("La cola está vacía."); return end
                                                                                                                                                                                                                                                                local new_index = math.max(0, math.min(length - 1, current + direction))
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("jukeboxControl.view", { { "action", "skip" }, { "index", new_index }, { "offset", 0 } })
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                self:refreshHome()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                --------------------------------------------------------------------------
                                                                                                                                                                                                                                                                -- Letras de canciones (Con Fallback Multinivel Inteligente)
                                                                                                                                                                                                                                                                --------------------------------------------------------------------------

                                                                                                                                                                                                                                                                function NavidromePlugin:fetchLyrics(artist, title, song_id)
                                                                                                                                                                                                                                                                local debug_info = {}

                                                                                                                                                                                                                                                                -- 1. Intentar Navidrome buscando EXACTAMENTE el archivo por ID (Navidrome 0.51+)
                                                                                                                                                                                                                                                                if song_id then
                                                                                                                                                                                                                                                                local resp1, err1 = self:apiRequest("getLyricsBySongId.view", { { "id", song_id } })
                                                                                                                                                                                                                                                                if resp1 then
                                                                                                                                                                                                                                                                local l = self:safeList(resp1.lyricsList and resp1.lyricsList.lyrics)[1]
                                                                                                                                                                                                                                                                if l and type(l.value) == "string" and l.value ~= "" then return l.value, "Navidrome (Por ID)" end

                                                                                                                                                                                                                                                                -- Variación de la API a veces devuelve lyrics suelto
                                                                                                                                                                                                                                                                if resp1.lyrics and type(resp1.lyrics.value) == "string" and resp1.lyrics.value ~= "" then
                                                                                                                                                                                                                                                                return resp1.lyrics.value, "Navidrome (Por ID)"
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                table.insert(debug_info, "Navidrome ID: Sin letra asociada a este audio.")
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                table.insert(debug_info, "Navidrome ID Falló: " .. tostring(err1))
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- 2. Intentar API clásica Navidrome
                                                                                                                                                                                                                                                                local resp2, err2 = self:apiRequest("getLyrics.view", { { "artist", artist }, { "title", title } })
                                                                                                                                                                                                                                                                if resp2 then
                                                                                                                                                                                                                                                                local l = self:safeList(resp2.lyricsList and resp2.lyricsList.lyrics)[1]
                                                                                                                                                                                                                                                                if l and type(l.value) == "string" and l.value ~= "" then return l.value, "Navidrome (Por Nombre)" end
                                                                                                                                                                                                                                                                table.insert(debug_info, "Navidrome Nombre: No encontró coincidencias exactas.")
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                table.insert(debug_info, "Navidrome Nombre Falló: " .. tostring(err2))
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- 3. Si Navidrome falla, descarga desde internet usando buscador difuso inteligente de LRCLIB
                                                                                                                                                                                                                                                                if https then
                                                                                                                                                                                                                                                                -- LIMPIEZA INTELIGENTE DE TÍTULOS PARA LRCLIB
                                                                                                                                                                                                                                                                local clean_title = title
                                                                                                                                                                                                                                                                -- a. Eliminar contenido entre paréntesis o corchetes (ej: "(Remastered)", "[Live]")
                                                                                                                                                                                                                                                                clean_title = clean_title:gsub("%s*%b()", ""):gsub("%s*%b[]", "")
                                                                                                                                                                                                                                                                -- b. Eliminar subtítulos o versiones tras un guion (ej: "- 2005 Remaster")
                                                                                                                                                                                                                                                                clean_title = clean_title:gsub("%s*%-.+", "")
                                                                                                                                                                                                                                                                -- c. Eliminar explícitamente marcas de explicit (ej: "🅴" o "") que rompen la búsqueda
                                                                                                                                                                                                                                                                clean_title = clean_title:gsub("🅴", ""):gsub("", "")
                                                                                                                                                                                                                                                                -- d. Limpiar espacios extra
                                                                                                                                                                                                                                                                clean_title = clean_title:gsub("^%s+", ""):gsub("%s+$", "")

                                                                                                                                                                                                                                                                -- Si por limpiar demasiado nos quedamos sin título, restauramos el original
                                                                                                                                                                                                                                                                if clean_title == "" then clean_title = title end

                                                                                                                                                                                                                                                                local query = artist .. " " .. clean_title
                                                                                                                                                                                                                                                                local url = "https://lrclib.net/api/search?q=" .. self:urlEncode(query)
                                                                                                                                                                                                                                                                local response_body = {}

                                                                                                                                                                                                                                                                pcall(function() http.TIMEOUT = 5 end)
                                                                                                                                                                                                                                                                if socketutil and socketutil.set_timeout then pcall(function() socketutil:set_timeout(3, 5) end) end

                                                                                                                                                                                                                                                                local ok, result, code = pcall(https.request, {
                                                                                                                                                                                                                                                                url = url,
                                                                                                                                                                                                                                                                method = "GET",
                                                                                                                                                                                                                                                                headers = {
                                                                                                                                                                                                                                                                ["User-Agent"] = "KOReader-Navidrome-Plugin/1.0",
                                                                                                                                                                                                                                                                ["Connection"] = "close"
                                                                                                                                                                                                                                                                },
                                                                                                                                                                                                                                                                sink = ltn12.sink.table(response_body)
                                                                                                                                                                                                                                                                })

                                                                                                                                                                                                                                                                if socketutil and socketutil.reset_timeout then pcall(function() socketutil:reset_timeout() end) end

                                                                                                                                                                                                                                                                if ok and tonumber(code) == 200 then
                                                                                                                                                                                                                                                                local decoded_ok, data = pcall(rapidjson.decode, table.concat(response_body))
                                                                                                                                                                                                                                                                if decoded_ok and type(data) == "table" and #data > 0 then
                                                                                                                                                                                                                                                                -- LRCLIB devuelve un array con los mejores resultados ordenados, agarramos el #1
                                                                                                                                                                                                                                                                local best = data[1]
                                                                                                                                                                                                                                                                local synced = best.syncedLyrics
                                                                                                                                                                                                                                                                local plain = best.plainLyrics

                                                                                                                                                                                                                                                                if type(synced) == "string" and synced ~= "" then return synced, "Internet (LRCLIB)" end
                                                                                                                                                                                                                                                                if type(plain) == "string" and plain ~= "" then return plain, "Internet (LRCLIB)" end

                                                                                                                                                                                                                                                                table.insert(debug_info, "LRCLIB: Resultado encontrado pero venía sin letra.")
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                table.insert(debug_info, "LRCLIB: Búsqueda sin coincidencias en internet.")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                table.insert(debug_info, "LRCLIB HTTP Error: " .. tostring(code or result))
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                table.insert(debug_info, "LRCLIB: KOReader no tiene el módulo HTTPS cargado (limitación del sistema/AppImage).")
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- Retorna nil y todo el historial de por qué falló cada cosa
                                                                                                                                                                                                                                                                return nil, table.concat(debug_info, "\n\n")
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:cleanLyrics(raw_lyrics)
                                                                                                                                                                                                                                                                local lines = {}
                                                                                                                                                                                                                                                                for line in (raw_lyrics .. "\n"):gmatch("(.-)\n") do
                                                                                                                                                                                                                                                                line = line:gsub("\r", "")
                                                                                                                                                                                                                                                                -- Omitir líneas que sean puramente metadatos LRC ocultos, ej: [ti:Título]
                                                                                                                                                                                                                                                                if not line:match("^%s*%[%a+:[^%]]+%]%s*$") then
                                                                                                                                                                                                                                                                -- Limpiar TODAS las marcas de tiempo LRC de la línea, ej: [00:12.34]
                                                                                                                                                                                                                                                                line = line:gsub("%[%d+:%d+%.?%d*%]", "")
                                                                                                                                                                                                                                                                -- Limpiar espacios residuales en los bordes
                                                                                                                                                                                                                                                                line = line:gsub("^%s+", ""):gsub("%s+$", "")
                                                                                                                                                                                                                                                                table.insert(lines, line)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                -- Unir todo y quitar saltos de línea sobrantes al inicio/fin
                                                                                                                                                                                                                                                                return table.concat(lines, "\n"):gsub("^\n+", ""):gsub("\n+$", "")
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:showLyrics()
                                                                                                                                                                                                                                                                local state, err = self:getJukeboxState()
                                                                                                                                                                                                                                                                if not state then
                                                                                                                                                                                                                                                                self:showError(err)
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if not state.song then
                                                                                                                                                                                                                                                                self:showMessage("No hay ninguna canción en reproducción.")
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local artist = state.song.artist
                                                                                                                                                                                                                                                                local title = state.song.title
                                                                                                                                                                                                                                                                local song_id = state.song.id

                                                                                                                                                                                                                                                                if not artist or not title or artist == "" or title == "" then
                                                                                                                                                                                                                                                                self:showMessage("La canción actual no tiene artista o título identificados para poder buscar la letra.")
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- Muestra el mensaje de cargando
                                                                                                                                                                                                                                                                local loading_msg = self:showMessage("Buscando letra...\n" .. title .. "\n" .. artist)
                                                                                                                                                                                                                                                                UIManager:forceRePaint()

                                                                                                                                                                                                                                                                UIManager:nextTick(function()
                                                                                                                                                                                                                                                                local raw_lyrics, source_or_err = self:fetchLyrics(artist, title, song_id)

                                                                                                                                                                                                                                                                -- Cierra el cartel de cargando
                                                                                                                                                                                                                                                                UIManager:close(loading_msg)

                                                                                                                                                                                                                                                                if not raw_lyrics or raw_lyrics == "" then
                                                                                                                                                                                                                                                                local fail_msg = "No se encontró la letra de esta canción.\n\n[DETALLES DE LA BÚSQUEDA]\n\n" .. tostring(source_or_err)
                                                                                                                                                                                                                                                                UIManager:show(TextViewer:new{
                                                                                                                                                                                                                                                                title = "Error buscando letra",
                                                                                                                                                                                                                                                                text = fail_msg,
                                                                                                                                                                                                                                                                })
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local clean_lyrics = self:cleanLyrics(raw_lyrics)

                                                                                                                                                                                                                                                                if clean_lyrics == "" then
                                                                                                                                                                                                                                                                self:showMessage("La letra obtenida no contiene texto visible.")
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local note = "\n\n---\n(Fuente: " .. tostring(source_or_err) .. ")\n(Nota: KOReader actúa como mando a distancia del servidor. Al no reproducir el audio internamente, no es posible sincronizar ni resaltar la letra a tiempo real)."

                                                                                                                                                                                                                                                                local textviewer = TextViewer:new{
                                                                                                                                                                                                                                                                title = title .. " — " .. artist,
                                                                                                                                                                                                                                                                text = clean_lyrics .. note,
                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                UIManager:show(textviewer)
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                --------------------------------------------------------------------------
                                                                                                                                                                                                                                                                -- Listas de Reproducción (Playlists)
                                                                                                                                                                                                                                                                --------------------------------------------------------------------------

                                                                                                                                                                                                                                                                function NavidromePlugin:showPlaylists()
                                                                                                                                                                                                                                                                local config, cfg_err = self:validateConfig()
                                                                                                                                                                                                                                                                if not config then self:showError(cfg_err); return end

                                                                                                                                                                                                                                                                local response, err = self:apiRequest("getPlaylists.view", {})
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end

                                                                                                                                                                                                                                                                local playlists_container = response.playlists
                                                                                                                                                                                                                                                                local playlists = self:safeList(playlists_container and playlists_container.playlist)

                                                                                                                                                                                                                                                                if #playlists == 0 then
                                                                                                                                                                                                                                                                self:showMessage("No tienes listas de reproducción creadas en tu servidor Navidrome.")
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local items = {}
                                                                                                                                                                                                                                                                for _, pl in ipairs(playlists) do
                                                                                                                                                                                                                                                                if pl.id then
                                                                                                                                                                                                                                                                local name = self:safeStr(pl.name, "Lista sin nombre")
                                                                                                                                                                                                                                                                local count = tonumber(pl.songCount) or 0
                                                                                                                                                                                                                                                                table.insert(items, {
                                                                                                                                                                                                                                                                text = ICONS.playlist .. "  " .. name .. " (" .. count .. " canciones)",
                                                                                                                                                                                                                                                                callback = function() self:showPlaylist(tostring(pl.id), name) end,
                                                                                                                                                                                                                                                                })
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                UIManager:show(Menu:new{ title = "Mis Listas", item_table = items })
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:showPlaylist(id, name)
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("getPlaylist.view", {{ "id", id }})
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end

                                                                                                                                                                                                                                                                local pl = response.playlist or {}
                                                                                                                                                                                                                                                                local songs = self:safeList(pl.entry)
                                                                                                                                                                                                                                                                local items = {}
                                                                                                                                                                                                                                                                local playable_ids = {}

                                                                                                                                                                                                                                                                for _, song in ipairs(songs) do
                                                                                                                                                                                                                                                                if song.id then table.insert(playable_ids, tostring(song.id)) end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if #playable_ids > 0 then
                                                                                                                                                                                                                                                                table.insert(items, { text = ICONS.play .. "  Reproducir lista ahora", callback = function() self:playSongs(playable_ids, name) end })
                                                                                                                                                                                                                                                                table.insert(items, { text = ICONS.add .. "  Añadir lista a la cola", callback = function() self:addSongs(playable_ids, name) end })
                                                                                                                                                                                                                                                                table.insert(items, { text = "— CANCIONES —", callback = function() end })
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                for _, song in ipairs(songs) do
                                                                                                                                                                                                                                                                if song.id then
                                                                                                                                                                                                                                                                local title = self:safeStr(song.title, "Sin título")
                                                                                                                                                                                                                                                                local artist = self:safeStr(song.artist, "Artista desconocido")
                                                                                                                                                                                                                                                                table.insert(items, {
                                                                                                                                                                                                                                                                text = title .. " — " .. artist,
                                                                                                                                                                                                                                                                callback = function() self:playSongs({ tostring(song.id) }, title) end
                                                                                                                                                                                                                                                                })
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if #items == 0 then
                                                                                                                                                                                                                                                                self:showMessage("Esta lista de reproducción está vacía.")
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                UIManager:show(Menu:new{ title = "Lista: " .. name, item_table = items })
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                --------------------------------------------------------------------------
                                                                                                                                                                                                                                                                -- Configuración en una sola ventana (Servidor, Usuario, Contraseña)
                                                                                                                                                                                                                                                                --------------------------------------------------------------------------

                                                                                                                                                                                                                                                                function NavidromePlugin:showConfigDialog()
                                                                                                                                                                                                                                                                local config = self:getConfig()
                                                                                                                                                                                                                                                                if MultiInputDialog then
                                                                                                                                                                                                                                                                local dialog
                                                                                                                                                                                                                                                                dialog = MultiInputDialog:new{
                                                                                                                                                                                                                                                                title = "Configurar servidor y cuenta",
                                                                                                                                                                                                                                                                fields = {
                                                                                                                                                                                                                                                                { text = config.url, hint = "http://192.168.1.100:4533", description = "Servidor (URL):" },
                                                                                                                                                                                                                                                                { text = config.user, hint = "Nombre de usuario", description = "Usuario:" },
                                                                                                                                                                                                                                                                { text = config.pass, hint = "Contraseña de tu cuenta", description = "Contraseña:", type = "password" },
                                                                                                                                                                                                                                                                },
                                                                                                                                                                                                                                                                buttons = {
                                                                                                                                                                                                                                                                {
                                                                                                                                                                                                                                                                { text = "Cancelar", id = "close", callback = function() UIManager:close(dialog) end },
                                                                                                                                                                                                                                                                { text = "Probar conexión", callback = function()
                                                                                                                                                                                                                                                                local f1, f2, f3 = self:extractDialogFields(dialog)
                                                                                                                                                                                                                                                                self:testConnectionWithParams(f1, f2, f3)
                                                                                                                                                                                                                                                                end },
                                                                                                                                                                                                                                                                { text = "Guardar", is_enter_default = true, callback = function()
                                                                                                                                                                                                                                                                local f1, f2, f3 = self:extractDialogFields(dialog)
                                                                                                                                                                                                                                                                f1 = f1:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
                                                                                                                                                                                                                                                                if f1 ~= "" and not f1:match("^https?://") then f1 = "http://" .. f1 end
                                                                                                                                                                                                                                                                f2 = f2:gsub("^%s+", ""):gsub("%s+$", "")
                                                                                                                                                                                                                                                                self:saveSetting("url", f1)
                                                                                                                                                                                                                                                                self:saveSetting("user", f2)
                                                                                                                                                                                                                                                                self:saveSetting("pass", f3)
                                                                                                                                                                                                                                                                UIManager:close(dialog)
                                                                                                                                                                                                                                                                self:showMessage("Configuración guardada correctamente.")
                                                                                                                                                                                                                                                                end },
                                                                                                                                                                                                                                                                },
                                                                                                                                                                                                                                                                },
                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                UIManager:show(dialog)
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                self:showConfigFallback()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:extractDialogFields(dialog)
                                                                                                                                                                                                                                                                if not dialog then return "", "", "" end
                                                                                                                                                                                                                                                                if dialog.getFields then
                                                                                                                                                                                                                                                                local ok, res = pcall(function() return dialog:getFields() end)
                                                                                                                                                                                                                                                                if ok and type(res) == "table" then return tostring(res[1] or ""), tostring(res[2] or ""), tostring(res[3] or "") end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                local fl = dialog._fields or dialog.fields or dialog.input_fields
                                                                                                                                                                                                                                                                if fl and type(fl) == "table" then
                                                                                                                                                                                                                                                                local f1 = fl[1] and fl[1].getText and fl[1]:getText() or ""
                                                                                                                                                                                                                                                                local f2 = fl[2] and fl[2].getText and fl[2]:getText() or ""
                                                                                                                                                                                                                                                                local f3 = fl[3] and fl[3].getText and fl[3]:getText() or ""
                                                                                                                                                                                                                                                                return tostring(f1 or ""), tostring(f2 or ""), tostring(f3 or "")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                return "", "", ""
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:testConnectionWithParams(url, user, pass)
                                                                                                                                                                                                                                                                url = url:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
                                                                                                                                                                                                                                                                if url ~= "" and not url:match("^https?://") then url = "http://" .. url end
                                                                                                                                                                                                                                                                user = user:gsub("^%s+", ""):gsub("%s+$", "")
                                                                                                                                                                                                                                                                if url == "" or user == "" or pass == "" then self:showError("Completa Servidor, Usuario y Contraseña para probar."); return end

                                                                                                                                                                                                                                                                self:showMessage("Probando conexión con Navidrome...\n" .. url)
                                                                                                                                                                                                                                                                UIManager:nextTick(function()
                                                                                                                                                                                                                                                                local orig_url, orig_user, orig_pass = self:getSetting("url", ""), self:getSetting("user", ""), self:getSetting("pass", "")
                                                                                                                                                                                                                                                                self:saveSetting("url", url); self:saveSetting("user", user); self:saveSetting("pass", pass)
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("ping.view", {})
                                                                                                                                                                                                                                                                if not response then
                                                                                                                                                                                                                                                                self:saveSetting("url", orig_url); self:saveSetting("user", orig_user); self:saveSetting("pass", orig_pass)
                                                                                                                                                                                                                                                                self:showError("Fallo de conexión:\n" .. tostring(err))
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                local ver = response.version or API_VERSION
                                                                                                                                                                                                                                                                self:showMessage("¡Conexión exitosa con Navidrome!\nSubsonic API v" .. tostring(ver))
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:showConfigFallback()
                                                                                                                                                                                                                                                                local config = self:getConfig()
                                                                                                                                                                                                                                                                local items = {
                                                                                                                                                                                                                                                                { text = "Servidor (URL): " .. (config.url ~= "" and config.url or "(sin configurar)"), callback = function() self:inputSetting("url", "Servidor Navidrome", "http://192.168.1.100:4533") end },
                                                                                                                                                                                                                                                                { text = "Usuario: " .. (config.user ~= "" and config.user or "(sin configurar)"), callback = function() self:inputSetting("user", "Usuario de Navidrome", "usuario") end },
                                                                                                                                                                                                                                                                { text = "Contraseña: " .. (config.pass ~= "" and "********" or "(sin configurar)"), callback = function() self:inputSetting("pass", "Contraseña de Navidrome", "contraseña", true) end },
                                                                                                                                                                                                                                                                { text = "Probar conexión", callback = function() local c = self:getConfig(); self:testConnectionWithParams(c.url, c.user, c.pass) end },
                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                UIManager:show(Menu:new{ title = "Configurar servidor y cuenta", item_table = items, show_parent = self.ui })
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:inputSetting(key, title, hint, is_password)
                                                                                                                                                                                                                                                                local val = self:getSetting(key, "")
                                                                                                                                                                                                                                                                local dialog
                                                                                                                                                                                                                                                                dialog = InputDialog:new{
                                                                                                                                                                                                                                                                title = title, input = val, input_hint = hint, input_type = is_password and "password" or nil,
                                                                                                                                                                                                                                                                buttons = {
                                                                                                                                                                                                                                                                {
                                                                                                                                                                                                                                                                { text = "Cancelar", callback = function() UIManager:close(dialog) end },
                                                                                                                                                                                                                                                                { text = "Guardar", is_enter_default = true, callback = function()
                                                                                                                                                                                                                                                                local new_val = dialog:getInputText() or ""
                                                                                                                                                                                                                                                                UIManager:close(dialog); self:saveSetting(key, new_val)
                                                                                                                                                                                                                                                                self:showMessage(title .. " guardado."); self:showConfigFallback()
                                                                                                                                                                                                                                                                end },
                                                                                                                                                                                                                                                                },
                                                                                                                                                                                                                                                                },
                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                UIManager:show(dialog)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:configure() self:showConfigDialog() end

                                                                                                                                                                                                                                                                --------------------------------------------------------------------------
                                                                                                                                                                                                                                                                -- Jukebox: control básico
                                                                                                                                                                                                                                                                --------------------------------------------------------------------------

                                                                                                                                                                                                                                                                function NavidromePlugin:jukeboxAction(action)
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("jukeboxControl.view", {{ "action", action }})
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                local messages = { start = "Reproducción iniciada.", stop = "Reproducción detenida.", skip = "Pasando a la siguiente canción.", clear = "Cola vaciada." }
                                                                                                                                                                                                                                                                self:showMessage(messages[action] or "Listo.")
                                                                                                                                                                                                                                                                self:refreshHome()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:jukeboxWithIds(action, ids)
                                                                                                                                                                                                                                                                local params = {{ "action", action }}
                                                                                                                                                                                                                                                                for _, id in ipairs(ids or {}) do table.insert(params, { "id", id }) end
                                                                                                                                                                                                                                                                return self:apiRequest("jukeboxControl.view", params)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:playSongs(ids, label)
                                                                                                                                                                                                                                                                if not ids or #ids == 0 then self:showMessage("No hay canciones para reproducir."); return end
                                                                                                                                                                                                                                                                local response, err = self:jukeboxWithIds("set", ids)
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                response, err = self:apiRequest("jukeboxControl.view", {{ "action", "start" }})
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                self:showMessage("Reproduciendo ahora:\n" .. tostring(label or "Selección"))
                                                                                                                                                                                                                                                                self:refreshHome()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:addSongs(ids, label)
                                                                                                                                                                                                                                                                if not ids or #ids == 0 then self:showMessage("No hay canciones para añadir."); return end
                                                                                                                                                                                                                                                                local response, err = self:jukeboxWithIds("add", ids)
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                self:showMessage("Añadido a la cola:\n" .. tostring(label or "Selección"))
                                                                                                                                                                                                                                                                self:refreshHome()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                --------------------------------------------------------------------------
                                                                                                                                                                                                                                                                -- Búsqueda
                                                                                                                                                                                                                                                                --------------------------------------------------------------------------

                                                                                                                                                                                                                                                                function NavidromePlugin:showSearch()
                                                                                                                                                                                                                                                                local config, cfg_err = self:validateConfig()
                                                                                                                                                                                                                                                                if not config then self:showError(cfg_err); return end
                                                                                                                                                                                                                                                                local dialog
                                                                                                                                                                                                                                                                dialog = InputDialog:new{
                                                                                                                                                                                                                                                                title = "Buscar en Navidrome", input_hint = "Artista, álbum o canción",
                                                                                                                                                                                                                                                                buttons = {
                                                                                                                                                                                                                                                                {
                                                                                                                                                                                                                                                                { text = "Cancelar", callback = function() UIManager:close(dialog) end },
                                                                                                                                                                                                                                                                { text = "Buscar", is_enter_default = true, callback = function()
                                                                                                                                                                                                                                                                local query = dialog:getInputText() or ""
                                                                                                                                                                                                                                                                UIManager:close(dialog); query = query:gsub("^%s+", ""):gsub("%s+$", "")
                                                                                                                                                                                                                                                                if query == "" then self:showMessage("Escribe algo para buscar."); return end
                                                                                                                                                                                                                                                                self:performSearch(query)
                                                                                                                                                                                                                                                                end },
                                                                                                                                                                                                                                                                },
                                                                                                                                                                                                                                                                },
                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                UIManager:show(dialog)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:performSearch(query)
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("search3.view", { { "query", query }, { "artistCount", 10 }, { "albumCount", 10 }, { "songCount", 20 } })
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                local result = response.searchResult3 or {}
                                                                                                                                                                                                                                                                local items = {}
                                                                                                                                                                                                                                                                local artists = self:safeList(result.artist)
                                                                                                                                                                                                                                                                local albums = self:safeList(result.album)
                                                                                                                                                                                                                                                                local songs = self:safeList(result.song)

                                                                                                                                                                                                                                                                if #artists > 0 then
                                                                                                                                                                                                                                                                table.insert(items, { text = "— ARTISTAS —", callback = function() end })
                                                                                                                                                                                                                                                                for _, artist in ipairs(artists) do
                                                                                                                                                                                                                                                                if artist.id then
                                                                                                                                                                                                                                                                local name = self:safeStr(artist.name, "Artista desconocido")
                                                                                                                                                                                                                                                                table.insert(items, { text = ICONS.artist .. "  " .. name, callback = function() self:showArtist(tostring(artist.id), name) end })
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if #albums > 0 then
                                                                                                                                                                                                                                                                table.insert(items, { text = "— ÁLBUMES —", callback = function() end })
                                                                                                                                                                                                                                                                for _, album in ipairs(albums) do
                                                                                                                                                                                                                                                                if album.id then
                                                                                                                                                                                                                                                                local name = self:safeStr(album.name or album.title, "Álbum sin nombre")
                                                                                                                                                                                                                                                                local art = self:safeStr(album.artist, "Varios")
                                                                                                                                                                                                                                                                table.insert(items, { text = ICONS.album .. "  " .. name .. " — " .. art, callback = function() self:showAlbum(tostring(album.id), name) end })
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if #songs > 0 then
                                                                                                                                                                                                                                                                table.insert(items, { text = "— CANCIONES —", callback = function() end })
                                                                                                                                                                                                                                                                for _, song in ipairs(songs) do
                                                                                                                                                                                                                                                                if song.id then
                                                                                                                                                                                                                                                                local title = self:safeStr(song.title, "Canción sin título")
                                                                                                                                                                                                                                                                local art = self:safeStr(song.artist, "Artista desconocido")
                                                                                                                                                                                                                                                                table.insert(items, { text = ICONS.play .. "  " .. title .. " — " .. art, callback = function() self:playSongs({ tostring(song.id) }, title) end })
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if #items == 0 then self:showMessage("No se encontraron resultados."); return end
                                                                                                                                                                                                                                                                UIManager:show(Menu:new{ title = "Resultados: " .. query, item_table = items })
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:showArtist(id, name)
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("getArtist.view", {{ "id", id }})
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                local items = {}
                                                                                                                                                                                                                                                                for _, album in ipairs(self:safeList((response.artist or {}).album)) do
                                                                                                                                                                                                                                                                if album.id then
                                                                                                                                                                                                                                                                local album_name = self:safeStr(album.name or album.title, "Álbum sin nombre")
                                                                                                                                                                                                                                                                local year = self:safeStr(album.year, "")
                                                                                                                                                                                                                                                                local label = ICONS.album .. "  " .. album_name
                                                                                                                                                                                                                                                                if year ~= "" then label = label .. " (" .. year .. ")" end
                                                                                                                                                                                                                                                                table.insert(items, { text = label, callback = function() self:showAlbum(tostring(album.id), album_name) end })
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if #items == 0 then self:showMessage("Este artista no tiene álbumes."); return end
                                                                                                                                                                                                                                                                UIManager:show(Menu:new{ title = "Álbumes: " .. name, item_table = items })
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:showAlbum(id, title)
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("getAlbum.view", {{ "id", id }})
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                local album = response.album or {}
                                                                                                                                                                                                                                                                local songs = self:safeList(album.song)
                                                                                                                                                                                                                                                                local items = {}
                                                                                                                                                                                                                                                                local playable_ids = {}
                                                                                                                                                                                                                                                                for _, song in ipairs(songs) do if song.id then table.insert(playable_ids, tostring(song.id)) end end

                                                                                                                                                                                                                                                                table.insert(items, { text = ICONS.cover .. "  Ver portada", callback = function() self:showCoverArt(album.coverArt or id, title) end })
                                                                                                                                                                                                                                                                if #playable_ids > 0 then
                                                                                                                                                                                                                                                                table.insert(items, { text = ICONS.play .. "  Reproducir álbum ahora", callback = function() self:playSongs(playable_ids, title) end })
                                                                                                                                                                                                                                                                table.insert(items, { text = ICONS.add .. "  Añadir álbum a la cola", callback = function() self:addSongs(playable_ids, title) end })
                                                                                                                                                                                                                                                                table.insert(items, { text = "— CANCIONES —", callback = function() end })
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                for _, song in ipairs(songs) do
                                                                                                                                                                                                                                                                if song.id then
                                                                                                                                                                                                                                                                local song_title = self:safeStr(song.title, "Sin título")
                                                                                                                                                                                                                                                                local track = self:safeStr(song.track, "")
                                                                                                                                                                                                                                                                local label = (track ~= "" and (track .. ". ") or "") .. song_title
                                                                                                                                                                                                                                                                table.insert(items, { text = label, callback = function() self:playSongs({ tostring(song.id) }, song_title) end })
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if #items == 0 then self:showMessage("Este álbum no tiene canciones disponibles."); return end
                                                                                                                                                                                                                                                                UIManager:show(Menu:new{ title = "Álbum: " .. title, item_table = items })
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                --------------------------------------------------------------------------
                                                                                                                                                                                                                                                                -- Listas: recientes / aleatorios / top artistas / descubrir
                                                                                                                                                                                                                                                                --------------------------------------------------------------------------

                                                                                                                                                                                                                                                                function NavidromePlugin:showAlbumList(title, list_type, size)
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("getAlbumList2.view", { { "type", list_type }, { "size", size or 20 } })
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                local items = {}
                                                                                                                                                                                                                                                                for _, album in ipairs(self:safeList((response.albumList2 or {}).album)) do
                                                                                                                                                                                                                                                                if album.id then
                                                                                                                                                                                                                                                                local name = self:safeStr(album.name or album.title, "Álbum sin nombre")
                                                                                                                                                                                                                                                                local artist = self:safeStr(album.artist, "Varios")
                                                                                                                                                                                                                                                                local year = self:safeStr(album.year, "")
                                                                                                                                                                                                                                                                local label = name .. " — " .. artist
                                                                                                                                                                                                                                                                if year ~= "" then label = label .. " (" .. year .. ")" end
                                                                                                                                                                                                                                                                table.insert(items, { text = label, callback = function() self:showAlbum(tostring(album.id), name) end })
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if #items == 0 then self:showMessage("No se encontraron álbumes."); return end
                                                                                                                                                                                                                                                                UIManager:show(Menu:new{ title = title, item_table = items })
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:showRecentAlbums() self:showAlbumList(ICONS.recent .. "  Álbumes recién añadidos", "newest", 25) end
                                                                                                                                                                                                                                                                function NavidromePlugin:showRandomAlbums() self:showAlbumList(ICONS.random .. "  Álbumes aleatorios", "random", 25) end

                                                                                                                                                                                                                                                                function NavidromePlugin:showTopArtists()
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("getAlbumList2.view", { { "type", "frequent" }, { "size", 50 } })
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end

                                                                                                                                                                                                                                                                local artist_data = {}
                                                                                                                                                                                                                                                                local order = {}
                                                                                                                                                                                                                                                                for _, album in ipairs(self:safeList((response.albumList2 or {}).album)) do
                                                                                                                                                                                                                                                                local artist_name = self:safeStr(album.artist, "Desconocido")
                                                                                                                                                                                                                                                                local artist_id = album.artistId and tostring(album.artistId)
                                                                                                                                                                                                                                                                local key = artist_id or ("name:" .. artist_name)
                                                                                                                                                                                                                                                                if not artist_data[key] then
                                                                                                                                                                                                                                                                artist_data[key] = { id = artist_id, name = artist_name, score = 0 }
                                                                                                                                                                                                                                                                table.insert(order, key)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                artist_data[key].score = artist_data[key].score + (tonumber(album.playCount) or 1)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                table.sort(order, function(a, b) return artist_data[a].score > artist_data[b].score end)

                                                                                                                                                                                                                                                                local items = {}
                                                                                                                                                                                                                                                                for _, key in ipairs(order) do
                                                                                                                                                                                                                                                                local data = artist_data[key]
                                                                                                                                                                                                                                                                table.insert(items, {
                                                                                                                                                                                                                                                                text = ICONS.artist .. "  " .. data.name .. "  (≈" .. data.score .. " reproducciones)",
                                                                                                                                                                                                                                                                callback = function()
                                                                                                                                                                                                                                                                if data.id then self:showArtist(data.id, data.name) else self:performSearch(data.name) end
                                                                                                                                                                                                                                                                end,
                                                                                                                                                                                                                                                                })
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if #items == 0 then self:showMessage("Aún no hay suficiente historial de reproducción en el servidor."); return end
                                                                                                                                                                                                                                                                UIManager:show(Menu:new{ title = ICONS.top .. "  Artistas más escuchados", item_table = items })
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:showRecommendedArtists()
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("getArtists.view", {})
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                local all_artists = {}
                                                                                                                                                                                                                                                                for _, group in ipairs(self:safeList(response.artists and response.artists.index)) do
                                                                                                                                                                                                                                                                for _, artist in ipairs(self:safeList(group.artist)) do if artist.id then table.insert(all_artists, artist) end end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if #all_artists == 0 then self:showMessage("No se encontraron artistas."); return end

                                                                                                                                                                                                                                                                math.randomseed(os.time())
                                                                                                                                                                                                                                                                for i = #all_artists, 2, -1 do local j = math.random(i); all_artists[i], all_artists[j] = all_artists[j], all_artists[i] end
                                                                                                                                                                                                                                                                local items = {}
                                                                                                                                                                                                                                                                for i = 1, math.min(15, #all_artists) do
                                                                                                                                                                                                                                                                local artist = all_artists[i]
                                                                                                                                                                                                                                                                local name = self:safeStr(artist.name, "Artista desconocido")
                                                                                                                                                                                                                                                                table.insert(items, { text = ICONS.discover .. "  " .. name, callback = function() self:showArtist(tostring(artist.id), name) end })
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                UIManager:show(Menu:new{ title = ICONS.discover .. "  Descubre artistas (selección aleatoria)", item_table = items })
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                --------------------------------------------------------------------------
                                                                                                                                                                                                                                                                -- Reproductor visual (Now Playing)
                                                                                                                                                                                                                                                                --------------------------------------------------------------------------

                                                                                                                                                                                                                                                                function NavidromePlugin:getCachedCoverPath(cover_id, size)
                                                                                                                                                                                                                                                                if not cover_id or cover_id == "" then return nil end
                                                                                                                                                                                                                                                                local filename = self.cover_cache_dir .. "/" .. tostring(cover_id) .. "_" .. tostring(tonumber(size) or 300) .. ".jpg"
                                                                                                                                                                                                                                                                if util.fileExists(filename) then return filename end
                                                                                                                                                                                                                                                                return nil
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:closeNowPlaying()
                                                                                                                                                                                                                                                                if self.player_dialog then UIManager:close(self.player_dialog); self.player_dialog = nil end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:showNowPlaying()
                                                                                                                                                                                                                                                                local config, cfg_err = self:validateConfig()
                                                                                                                                                                                                                                                                if not config then self:showError(cfg_err); return end
                                                                                                                                                                                                                                                                self:closeNowPlaying()
                                                                                                                                                                                                                                                                self.player_dialog = PlayerDialog:new{ plugin = self, title_text = "Cargando...", subtitle_text = "Consultando el servidor", is_playing = false }
                                                                                                                                                                                                                                                                UIManager:show(self.player_dialog)
                                                                                                                                                                                                                                                                UIManager:nextTick(function() self:refreshNowPlaying() end)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:getJukeboxState()
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("jukeboxControl.view", {{ "action", "get" }})
                                                                                                                                                                                                                                                                if not response then return nil, err end
                                                                                                                                                                                                                                                                local playlist = response.jukeboxPlaylist or {}
                                                                                                                                                                                                                                                                local entries = self:safeList(playlist.entry)
                                                                                                                                                                                                                                                                local current_index = tonumber(playlist.currentIndex)
                                                                                                                                                                                                                                                                if current_index == nil then current_index = -1 end
                                                                                                                                                                                                                                                                local is_playing = (playlist.playing == true or playlist.playing == "true")
                                                                                                                                                                                                                                                                local current_song = entries[current_index + 1]

                                                                                                                                                                                                                                                                self.player_current_index = current_index
                                                                                                                                                                                                                                                                self.player_queue_length = #entries

                                                                                                                                                                                                                                                                local cover_id, title_text, subtitle_text = nil, "Nada en reproducción", "Añade canciones, álbumes o radios desde el menú"
                                                                                                                                                                                                                                                                if current_song then
                                                                                                                                                                                                                                                                cover_id = current_song.coverArt
                                                                                                                                                                                                                                                                title_text = self:safeStr(current_song.title, "Sin título")
                                                                                                                                                                                                                                                                subtitle_text = self:safeStr(current_song.artist, "Artista desconocido") .. "  —  " .. self:safeStr(current_song.album, "")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                self.last_track_title, self.last_is_playing = title_text, is_playing

                                                                                                                                                                                                                                                                return { song = current_song, is_playing = is_playing, cover_id = cover_id, title = title_text, subtitle = subtitle_text }
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:refreshNowPlaying()
                                                                                                                                                                                                                                                                local state, err = self:getJukeboxState()
                                                                                                                                                                                                                                                                if not state then
                                                                                                                                                                                                                                                                if not self.player_dialog then
                                                                                                                                                                                                                                                                self.player_dialog = PlayerDialog:new{ plugin = self, title_text = "Nada en reproducción", subtitle_text = "Añade canciones o álbumes desde Buscar / Álbumes", is_playing = false }
                                                                                                                                                                                                                                                                UIManager:show(self.player_dialog)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                self:showError(err); return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local cover_id, title_text, subtitle_text, is_playing = state.cover_id, state.title, state.subtitle, state.is_playing
                                                                                                                                                                                                                                                                if not self.player_dialog then
                                                                                                                                                                                                                                                                self.player_dialog = PlayerDialog:new{ plugin = self, cover_id = cover_id, title_text = title_text, subtitle_text = subtitle_text, is_playing = is_playing }
                                                                                                                                                                                                                                                                UIManager:show(self.player_dialog)
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                self.player_dialog:setText(title_text, subtitle_text, is_playing)
                                                                                                                                                                                                                                                                self.player_dialog:setCover(cover_id)
                                                                                                                                                                                                                                                                UIManager:setDirty(self.player_dialog, "ui")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                UIManager:forceRePaint()

                                                                                                                                                                                                                                                                if cover_id and cover_id ~= "" and not self:getCachedCoverPath(cover_id, 400) then
                                                                                                                                                                                                                                                                UIManager:nextTick(function()
                                                                                                                                                                                                                                                                if not self.player_dialog then return end
                                                                                                                                                                                                                                                                if self:getCoverArtPath(cover_id, 400) then
                                                                                                                                                                                                                                                                self.player_dialog:setCover(cover_id); UIManager:setDirty(self.player_dialog, "ui"); UIManager:forceRePaint()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:playerToggle(is_playing)
                                                                                                                                                                                                                                                                local response, err = self:apiRequest("jukeboxControl.view", {{ "action", is_playing and "stop" or "start" }})
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                self:refreshNowPlaying()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                function NavidromePlugin:playerSkip(direction)
                                                                                                                                                                                                                                                                local current, length = self.player_current_index or 0, self.player_queue_length or 0
                                                                                                                                                                                                                                                                if length == 0 then self:showMessage("La cola está vacía."); return end
                                                                                                                                                                                                                                                                local new_index = current + direction
                                                                                                                                                                                                                                                                if new_index < 0 then new_index = 0 end
                                                                                                                                                                                                                                                                if new_index > length - 1 then new_index = length - 1 end

                                                                                                                                                                                                                                                                local response, err = self:apiRequest("jukeboxControl.view", { { "action", "skip" }, { "index", new_index }, { "offset", 0 } })
                                                                                                                                                                                                                                                                if not response then self:showError(err); return end
                                                                                                                                                                                                                                                                self:refreshNowPlaying()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                return NavidromePlugin
