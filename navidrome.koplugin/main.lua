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
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
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
local socketutil = require("socketutil")
local ltn12 = require("ltn12")

local API_VERSION = "1.12.0"
local CLIENT_NAME = "koreader-navidrome"

--------------------------------------------------------------------------
-- Diálogo del reproductor (Now Playing)
--
-- Es un InputContainer de pantalla completa: consume los toques que no van
-- a un botón (para que no se filtren al menú de debajo) y, al cerrarse,
-- fuerza un repintado. Sin ese repintado el diálogo desaparecía de la
-- pila de ventanas pero sus píxeles quedaban "fantasma" en la pantalla, y
-- se iban borrando a trozos con cada toque posterior.
--------------------------------------------------------------------------

local PlayerDialog = InputContainer:extend{
    plugin = nil,
    is_playing = false,
    cover_id = nil,
    title_text = "",
    subtitle_text = "",
    -- Modal: se apila por encima de cualquier ventana no modal y absorbe
    -- los eventos no consumidos por sus botones.
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

    local btn_size = Screen:scaleBySize(56)
    self.playpause_btn = Button:new{
        text = self.is_playing and "⏹" or "▶",
        width = btn_size,
        callback = function() plugin:playerToggle(self.is_playing) end,
    }
    self.buttons_row = HorizontalGroup:new{
        Button:new{ text = "◀◀", width = btn_size, callback = function() plugin:playerSkip(-1) end },
        self.playpause_btn,
        Button:new{ text = "▶▶", width = btn_size, callback = function() plugin:playerSkip(1) end },
        Button:new{ text = "🔀", width = btn_size, callback = function() plugin:playerShuffle() end },
        Button:new{ text = "⟳", width = btn_size, callback = function() plugin:refreshNowPlaying() end },
        Button:new{ text = "✕", width = btn_size, callback = function() self:onClose() end },
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

    -- Teclas físicas: atrás / inicio cierran el reproductor.
    self.key_events = {
        Close = { { "Back" }, { "Home" } },
    }
    -- Toques en cualquier parte: los consumimos para que no lleguen al
    -- menú que hay debajo. Los botones, al ser hijos, se procesan antes.
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
        self.playpause_btn:setText(is_playing and "⏹" or "▶")
    end
    -- Los contenedores cachean su tamaño; hay que invalidarlo al cambiar
    -- el texto para que el layout se recalcule.
    self.text_group:resetLayout()
    self.content_group:resetLayout()
end

function PlayerDialog:setCover(cover_id)
    local plugin = self.plugin
    self.cover_id = cover_id
    local size = 400
    local path = plugin:getCachedCoverPath(cover_id, size)
    local key = tostring(cover_id or "") .. "|" .. tostring(path or "")
    if self.cover_key == key and self.cover_holder[1] then
        return
    end

    self.cover_holder:clear()
    if path then
        table.insert(self.cover_holder, ImageWidget:new{
            file = path,
            width = self.cover_size,
            height = self.cover_size,
        })
    else
        table.insert(self.cover_holder, TextWidget:new{
            text = "🎵",
            face = Font:getFace("cfont", 60),
        })
    end
    self.cover_key = key
    self.content_group:resetLayout()
end

function PlayerDialog:onTapAnywhere()
    -- Consumimos el toque: no cierra y no se propaga hacia abajo.
    return true
end

function PlayerDialog:onClose()
    UIManager:close(self)
    return true
end

function PlayerDialog:onCloseWidget()
    -- Evita que el plugin siga usando un diálogo ya cerrado.
    if self.plugin and self.plugin.player_dialog == self then
        self.plugin.player_dialog = nil
    end
    -- Repinta lo que quedaba debajo. Esto es lo que arregla el "fantasma".
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
    if ok and path then
        base = path .. "/cache/navidrome_covers"
    else
        base = "/tmp/navidrome_covers"
    end
    -- makePath vive en frontend/util.lua, NO en ffi/util. El original
    -- llamaba ffiUtil.makePath, que no existe: el pcall lo ocultaba, la
    -- carpeta nunca se creaba y por eso no se descargaba la carátula.
    local created_ok = pcall(util.makePath, base)
    if not created_ok or not util.pathExists(base) then
        base = "/tmp/navidrome_covers"
        pcall(util.makePath, base)
    end
    self.cover_cache_dir = base
end

function NavidromePlugin:addToMainMenu(menu_items)
    menu_items.navidrome = {
        text = "Navidrome Jukebox",
        sorting_hint = "tools",
        callback = function() self:showMainMenu() end,
    }
end

--------------------------------------------------------------------------
-- Configuración y ajustes
--------------------------------------------------------------------------

function NavidromePlugin:getSetting(key, default)
    if G_reader_settings then
        local value = G_reader_settings:readSetting("navidrome_" .. key)
        if value ~= nil then return value end
    end
    return default
end

function NavidromePlugin:saveSetting(key, value)
    if G_reader_settings then
        G_reader_settings:saveSetting("navidrome_" .. key, value)
    end
end

function NavidromePlugin:getConfig()
    return {
        url = tostring(self:getSetting("url", "")):gsub("/+$", ""),
        user = tostring(self:getSetting("user", "")),
        pass = tostring(self:getSetting("pass", "")),
    }
end

--------------------------------------------------------------------------
-- Utilidades HTTP / Subsonic API
--------------------------------------------------------------------------

function NavidromePlugin:urlEncode(value)
    local str = tostring(value or "")
    str = str:gsub("\n", "\r\n")
    str = str:gsub("([^%w%-%_%.%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return str
end

function NavidromePlugin:makeQuery(params)
    local encoded = {}
    for _, pair in ipairs(params or {}) do
        if pair[2] ~= nil then
            table.insert(encoded, self:urlEncode(pair[1]) .. "=" .. self:urlEncode(pair[2]))
        end
    end
    return table.concat(encoded, "&")
end

-- Devuelve el JSON decodificado o nil y un mensaje de error legible.
function NavidromePlugin:apiRequest(endpoint, params)
    local config = self:getConfig()
    if config.url == "" or config.user == "" or config.pass == "" then
        return nil, "Configura la dirección del servidor y las credenciales primero."
    end

    local query_params = {
        { "u", config.user },
        { "p", config.pass },
        { "v", API_VERSION },
        { "c", CLIENT_NAME },
        { "f", "json" },
    }
    for _, pair in ipairs(params or {}) do
        table.insert(query_params, pair)
    end

    local url = config.url .. "/rest/" .. endpoint .. "?" .. self:makeQuery(query_params)
    local response_body = {}

    -- Timeouts acotados: sin esto LuaSocket espera hasta 60 s y la UI
    -- parece "colgada" hasta que el usuario toca la pantalla.
    socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
    local ok, result, code, _, status = pcall(http.request, {
        url = url,
        method = "GET",
        sink = ltn12.sink.table(response_body),
        redirect = true,
    })
    socketutil:reset_timeout()

    if not ok then
        local desc = socketutil.describe_error(result)
        return nil, "No se pudo conectar: " .. tostring(desc or result)
    end
    if result ~= 1 or tonumber(code) ~= 200 then
        local desc = socketutil.describe_error(result)
        return nil, tostring(desc or status or ("Error HTTP " .. tostring(code or "desconocido")))
    end

    local decoded_ok, data = pcall(rapidjson.decode, table.concat(response_body))
    if not decoded_ok or type(data) ~= "table" then
        return nil, "El servidor devolvió una respuesta JSON inválida."
    end

    local response = data["subsonic-response"]
    if type(response) ~= "table" then
        return nil, "Respuesta inesperada del servidor."
    end
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
    UIManager:show(InfoMessage:new{ text = text })
end

function NavidromePlugin:showError(err)
    self:showMessage("Navidrome\n" .. tostring(err or "Error desconocido"))
end

function NavidromePlugin:safeList(value)
    if type(value) ~= "table" then return {} end
    -- Algunas respuestas Subsonic envían un objeto cuando solo hay un resultado.
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

    if util.fileExists(filename) then
        return filename
    end

    local query = self:makeQuery({
        { "u", config.user }, { "p", config.pass }, { "v", API_VERSION }, { "c", CLIENT_NAME },
        { "id", cover_id }, { "size", size },
    })
    local url = config.url .. "/rest/getCoverArt.view?" .. query

    -- Descargamos a un fichero temporal y renombramos, para no dejar
    -- carátulas a medias en la caché si la descarga falla.
    local tmp_filename = filename .. ".part"
    local out_file = io.open(tmp_filename, "wb")
    if not out_file then return nil end

    socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
    local ok, result, code = pcall(http.request, {
        url = url,
        method = "GET",
        sink = ltn12.sink.file(out_file),
    })
    socketutil:reset_timeout()

    if not ok or result ~= 1 or tonumber(code) ~= 200 then
        os.remove(tmp_filename)
        return nil
    end

    os.remove(filename)
    local renamed = os.rename(tmp_filename, filename)
    if not renamed then
        os.remove(tmp_filename)
        return nil
    end

    return filename
end

function NavidromePlugin:showCoverArt(cover_id, title)
    if not cover_id or cover_id == "" then
        self:showMessage("Este elemento no tiene carátula disponible.")
        return
    end
    local path = self:getCoverArtPath(cover_id, 600)
    if not path then
        self:showMessage("No se pudo descargar la carátula.")
        return
    end
    UIManager:show(ImageViewer:new{
        file = path,
        fullscreen = true,
        with_title_bar = true,
        title_text = title or "Carátula",
    })
end

--------------------------------------------------------------------------
-- Menú principal
--------------------------------------------------------------------------

function NavidromePlugin:showMainMenu()
    local items = {
        { text = "▶  Reproductor (Now Playing)", callback = function() self:showNowPlaying() end },
        { text = "🔎  Buscar música", callback = function() self:showSearch() end },
        { text = "🆕  Álbumes recién añadidos", callback = function() self:showRecentAlbums() end },
        { text = "🎲  Álbumes aleatorios", callback = function() self:showRandomAlbums() end },
        { text = "🔥  Artistas más escuchados", callback = function() self:showTopArtists() end },
        { text = "✨  Descubre artistas", callback = function() self:showRecommendedArtists() end },
        { text = "⚙  Controles rápidos del Jukebox", callback = function() self:showQuickControls() end },
        { text = "🔧  Configurar servidor y cuenta", callback = function() self:configure(1) end },
    }
    UIManager:show(Menu:new{ title = "Navidrome Jukebox", item_table = items })
end

function NavidromePlugin:showQuickControls()
    local items = {
        { text = "⏹  Detener reproducción", callback = function() self:jukeboxAction("stop") end },
        { text = "▶  Reanudar reproducción", callback = function() self:jukeboxAction("start") end },
        { text = "⏭  Siguiente canción", callback = function() self:jukeboxAction("skip") end },
        { text = "🗑  Vaciar cola", callback = function() self:jukeboxAction("clear") end },
    }
    UIManager:show(Menu:new{ title = "Controles rápidos", item_table = items })
end

function NavidromePlugin:configure(field_index)
    local fields = {
        { key = "url", title = "Servidor Navidrome", hint = "Ejemplo: https://musica.ejemplo.com" },
        { key = "user", title = "Usuario Navidrome", hint = "Nombre de usuario" },
        { key = "pass", title = "Contraseña Navidrome", hint = "Se guarda localmente en KOReader" },
    }
    local field = fields[field_index]
    if not field then
        self:showMessage("Configuración guardada. Comprueba la conexión desde Buscar música.")
        return
    end

    local config = self:getConfig()
    local dialog
    dialog = InputDialog:new{
        title = field.title,
        input = config[field.key],
        input_hint = field.hint,
        buttons = {
            {
                { text = "Cancelar", callback = function() UIManager:close(dialog) end },
                { text = field_index == #fields and "Guardar" or "Siguiente", is_enter_default = true,
                    callback = function()
                        local value = dialog:getInputText() or ""
                        UIManager:close(dialog)
                        if field.key == "url" then
                            value = value:gsub("%s+$", ""):gsub("^%s+", ""):gsub("/+$", "")
                        end
                        self:saveSetting(field.key, value)
                        self:configure(field_index + 1)
                    end },
            },
        },
    }
    UIManager:show(dialog)
end

--------------------------------------------------------------------------
-- Jukebox: control básico
--------------------------------------------------------------------------

function NavidromePlugin:jukeboxAction(action)
    local response, err = self:apiRequest("jukeboxControl.view", {{ "action", action }})
    if not response then self:showError(err); return end
    local messages = {
        start = "Reproducción iniciada.", stop = "Reproducción detenida.",
        skip = "Pasando a la siguiente canción.", clear = "Cola vaciada.",
    }
    self:showMessage(messages[action] or "Listo.")
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
end

function NavidromePlugin:addSongs(ids, label)
    if not ids or #ids == 0 then self:showMessage("No hay canciones para añadir."); return end
    local response, err = self:jukeboxWithIds("add", ids)
    if not response then self:showError(err); return end
    self:showMessage("Añadido a la cola:\n" .. tostring(label or "Selección"))
end

--------------------------------------------------------------------------
-- Búsqueda
--------------------------------------------------------------------------

function NavidromePlugin:showSearch()
    local dialog
    dialog = InputDialog:new{
        title = "Buscar en Navidrome",
        input_hint = "Artista, álbum o canción",
        buttons = {
            {
                { text = "Cancelar", callback = function() UIManager:close(dialog) end },
                { text = "Buscar", is_enter_default = true, callback = function()
                    local query = dialog:getInputText() or ""
                    UIManager:close(dialog)
                    query = query:gsub("^%s+", ""):gsub("%s+$", "")
                    if query == "" then self:showMessage("Escribe algo para buscar."); return end
                    self:performSearch(query)
                end },
            },
        },
    }
    UIManager:show(dialog)
end

function NavidromePlugin:performSearch(query)
    local response, err = self:apiRequest("search3.view", {
        { "query", query }, { "artistCount", 10 }, { "albumCount", 10 }, { "songCount", 20 },
    })
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
                local id = tostring(artist.id)
                local name = self:safeStr(artist.name, "Artista desconocido")
                table.insert(items, { text = "🎤  " .. name,
                    callback = function() self:showArtist(id, name) end })
            end
        end
    end
    if #albums > 0 then
        table.insert(items, { text = "— ÁLBUMES —", callback = function() end })
        for _, album in ipairs(albums) do
            if album.id then
                local id = tostring(album.id)
                local name = self:safeStr(album.name or album.title, "Álbum sin nombre")
                local artist = self:safeStr(album.artist, "Varios")
                table.insert(items, { text = "💿  " .. name .. " — " .. artist,
                    callback = function() self:showAlbum(id, name) end })
            end
        end
    end
    if #songs > 0 then
        table.insert(items, { text = "— CANCIONES —", callback = function() end })
        for _, song in ipairs(songs) do
            if song.id then
                local id = tostring(song.id)
                local title = self:safeStr(song.title, "Canción sin título")
                local artist = self:safeStr(song.artist, "Artista desconocido")
                table.insert(items, { text = "▶  " .. title .. " — " .. artist,
                    callback = function() self:playSongs({ id }, title) end })
            end
        end
    end

    if #items == 0 then self:showMessage("No se encontraron resultados."); return end
    UIManager:show(Menu:new{ title = "Resultados: " .. query, item_table = items })
end

function NavidromePlugin:showArtist(id, name)
    local response, err = self:apiRequest("getArtist.view", {{ "id", id }})
    if not response then self:showError(err); return end
    local artist = response.artist or {}
    local albums = self:safeList(artist.album)
    local items = {}
    for _, album in ipairs(albums) do
        if album.id then
            local album_id = tostring(album.id)
            local album_name = self:safeStr(album.name or album.title, "Álbum sin nombre")
            local year = self:safeStr(album.year, "")
            local label = "💿  " .. album_name
            if year ~= "" then label = label .. " (" .. year .. ")" end
            table.insert(items, { text = label,
                callback = function() self:showAlbum(album_id, album_name) end })
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
    for _, song in ipairs(songs) do
        if song.id then table.insert(playable_ids, tostring(song.id)) end
    end

    local cover_id = album.coverArt or id
    table.insert(items, { text = "🖼  Ver portada",
        callback = function() self:showCoverArt(cover_id, title) end })

    if #playable_ids > 0 then
        table.insert(items, { text = "▶  Reproducir álbum ahora",
            callback = function() self:playSongs(playable_ids, title) end })
        table.insert(items, { text = "➕  Añadir álbum a la cola",
            callback = function() self:addSongs(playable_ids, title) end })
        table.insert(items, { text = "— CANCIONES —", callback = function() end })
    end
    for _, song in ipairs(songs) do
        if song.id then
            local song_id = tostring(song.id)
            local song_title = self:safeStr(song.title, "Sin título")
            local track = self:safeStr(song.track, "")
            local label = (track ~= "" and (track .. ". ") or "") .. song_title
            table.insert(items, { text = label,
                callback = function() self:playSongs({ song_id }, song_title) end })
        end
    end
    if #items == 0 then self:showMessage("Este álbum no tiene canciones disponibles."); return end
    UIManager:show(Menu:new{ title = "Álbum: " .. title, item_table = items })
end

--------------------------------------------------------------------------
-- Listas: recientes / aleatorios / top artistas / descubrir
--------------------------------------------------------------------------

function NavidromePlugin:showAlbumList(title, list_type, size)
    local response, err = self:apiRequest("getAlbumList2.view", {
        { "type", list_type }, { "size", size or 20 },
    })
    if not response then self:showError(err); return end
    local list = response.albumList2 or {}
    local albums = self:safeList(list.album)
    local items = {}
    for _, album in ipairs(albums) do
        if album.id then
            local id = tostring(album.id)
            local name = self:safeStr(album.name or album.title, "Álbum sin nombre")
            local artist = self:safeStr(album.artist, "Varios")
            local year = self:safeStr(album.year, "")
            local label = name .. " — " .. artist
            if year ~= "" then label = label .. " (" .. year .. ")" end
            table.insert(items, {
                text = label,
                callback = function() self:showAlbum(id, name) end,
            })
        end
    end
    if #items == 0 then self:showMessage("No se encontraron álbumes."); return end
    UIManager:show(Menu:new{ title = title, item_table = items })
end

function NavidromePlugin:showRecentAlbums()
    self:showAlbumList("🆕  Álbumes recién añadidos", "newest", 25)
end

function NavidromePlugin:showRandomAlbums()
    self:showAlbumList("🎲  Álbumes aleatorios", "random", 25)
end

-- Aproximación de "artistas más escuchados": no existe un endpoint oficial
-- para esto en la API Subsonic, así que agregamos el playCount de los
-- álbumes más frecuentes (type=frequent) agrupados por artista.
function NavidromePlugin:showTopArtists()
    local response, err = self:apiRequest("getAlbumList2.view", {
        { "type", "frequent" }, { "size", 50 },
    })
    if not response then self:showError(err); return end
    local list = response.albumList2 or {}
    local albums = self:safeList(list.album)

    local artist_data = {}
    local order = {}
    for _, album in ipairs(albums) do
        local artist_name = self:safeStr(album.artist, "Desconocido")
        local artist_id = album.artistId and tostring(album.artistId)
        local key = artist_id or ("name:" .. artist_name)
        if not artist_data[key] then
            artist_data[key] = { id = artist_id, name = artist_name, score = 0 }
            table.insert(order, key)
        end
        local play_count = tonumber(album.playCount) or 1
        artist_data[key].score = artist_data[key].score + play_count
    end

    table.sort(order, function(a, b) return artist_data[a].score > artist_data[b].score end)

    local items = {}
    for _, key in ipairs(order) do
        local data = artist_data[key]
        table.insert(items, {
            text = "🎤  " .. data.name .. "  (≈" .. data.score .. " reproducciones)",
            callback = function()
                if data.id then
                    self:showArtist(data.id, data.name)
                else
                    self:performSearch(data.name)
                end
            end,
        })
    end
    if #items == 0 then
        self:showMessage("Aún no hay suficiente historial de reproducción en el servidor.")
        return
    end
    UIManager:show(Menu:new{ title = "🔥  Artistas más escuchados", item_table = items })
end

-- "Recomendación" real: la API Subsonic/Navidrome no ofrece un motor de
-- recomendaciones genérico, así que mostramos una selección aleatoria de
-- tu biblioteca para descubrir cosas que quizá tengas olvidadas.
function NavidromePlugin:showRecommendedArtists()
    local response, err = self:apiRequest("getArtists.view", {})
    if not response then self:showError(err); return end

    local index = self:safeList(response.artists and response.artists.index)
    local all_artists = {}
    for _, group in ipairs(index) do
        for _, artist in ipairs(self:safeList(group.artist)) do
            if artist.id then table.insert(all_artists, artist) end
        end
    end
    if #all_artists == 0 then self:showMessage("No se encontraron artistas."); return end

    math.randomseed(os.time())
    for i = #all_artists, 2, -1 do
        local j = math.random(i)
        all_artists[i], all_artists[j] = all_artists[j], all_artists[i]
    end

    local items = {}
    local limit = math.min(15, #all_artists)
    for i = 1, limit do
        local artist = all_artists[i]
        local id = tostring(artist.id)
        local name = self:safeStr(artist.name, "Artista desconocido")
        table.insert(items, {
            text = "✨  " .. name,
            callback = function() self:showArtist(id, name) end,
        })
    end
    UIManager:show(Menu:new{ title = "✨  Descubre artistas (selección aleatoria)", item_table = items })
end

--------------------------------------------------------------------------
-- Reproductor visual (Now Playing)
--------------------------------------------------------------------------

-- Devuelve la ruta en caché si la carátula ya está descargada (sin red).
function NavidromePlugin:getCachedCoverPath(cover_id, size)
    if not cover_id or cover_id == "" then return nil end
    size = tonumber(size) or 300
    local filename = self.cover_cache_dir .. "/" .. tostring(cover_id) .. "_" .. tostring(size) .. ".jpg"
    if util.fileExists(filename) then return filename end
    return nil
end

function NavidromePlugin:closeNowPlaying()
    if self.player_dialog then
        UIManager:close(self.player_dialog)
        self.player_dialog = nil
    end
end

-- Muestra el reproductor al instante (estado "cargando") y deja la
-- consulta al servidor para el siguiente tick de la UI. Así la pantalla
-- nunca se queda "colgada" esperando a la red.
function NavidromePlugin:showNowPlaying()
    local config = self:getConfig()
    if config.url == "" or config.user == "" or config.pass == "" then
        self:showError("Configura la dirección del servidor y las credenciales primero.")
        return
    end
    self:closeNowPlaying()
    self.player_dialog = PlayerDialog:new{
        plugin = self,
        title_text = "Cargando...",
        subtitle_text = "Consultando el servidor",
        is_playing = false,
    }
    UIManager:show(self.player_dialog)
    UIManager:nextTick(function() self:refreshNowPlaying() end)
end

function NavidromePlugin:refreshNowPlaying()
    local response, err = self:apiRequest("jukeboxControl.view", {{ "action", "get" }})
    if not response then
        if not self.player_dialog then
            self.player_dialog = PlayerDialog:new{
                plugin = self,
                title_text = "Nada en reproducción",
                subtitle_text = "Añade canciones o álbumes desde Buscar / Álbumes",
                is_playing = false,
            }
            UIManager:show(self.player_dialog)
        end
        self:showError(err)
        return
    end

    local playlist = response.jukeboxPlaylist or {}
    local entries = self:safeList(playlist.entry)
    local current_index = tonumber(playlist.currentIndex)
    if current_index == nil then current_index = -1 end
    local is_playing = (playlist.playing == true or playlist.playing == "true")
    local current_song = entries[current_index + 1]

    self.player_current_index = current_index
    self.player_queue_length = #entries

    local cover_id = nil
    local title_text = "Nada en reproducción"
    local subtitle_text = "Añade canciones o álbumes desde Buscar / Álbumes"
    if current_song then
        cover_id = current_song.coverArt
        title_text = self:safeStr(current_song.title, "Sin título")
        subtitle_text = self:safeStr(current_song.artist, "Artista desconocido") ..
            "  —  " .. self:safeStr(current_song.album, "")
    end

    if not self.player_dialog then
        self.player_dialog = PlayerDialog:new{
            plugin = self,
            cover_id = cover_id,
            title_text = title_text,
            subtitle_text = subtitle_text,
            is_playing = is_playing,
        }
        UIManager:show(self.player_dialog)
    else
        -- Texto y carátula en caché ya mismo; si la carátula no está,
        -- se descarga en su propio tick para no bloquear la UI.
        self.player_dialog:setText(title_text, subtitle_text, is_playing)
        self.player_dialog:setCover(cover_id)
        UIManager:setDirty(self.player_dialog, "ui")
    end
    UIManager:forceRePaint()

    if cover_id and cover_id ~= "" and not self:getCachedCoverPath(cover_id, 400) then
        UIManager:nextTick(function()
            if not self.player_dialog then return end
            local path = self:getCoverArtPath(cover_id, 400)
            if path then
                self.player_dialog:setCover(cover_id)
                UIManager:setDirty(self.player_dialog, "ui")
                UIManager:forceRePaint()
            end
        end)
    end
end

function NavidromePlugin:playerToggle(is_playing)
    local action = is_playing and "stop" or "start"
    local response, err = self:apiRequest("jukeboxControl.view", {{ "action", action }})
    if not response then self:showError(err); return end
    self:refreshNowPlaying()
end

function NavidromePlugin:playerSkip(direction)
    local current = self.player_current_index or 0
    local length = self.player_queue_length or 0
    if length == 0 then self:showMessage("La cola está vacía."); return end

    local new_index = current + direction
    if new_index < 0 then new_index = 0 end
    if new_index > length - 1 then new_index = length - 1 end

    local response, err = self:apiRequest("jukeboxControl.view", {
        { "action", "skip" }, { "index", new_index }, { "offset", 0 },
    })
    if not response then self:showError(err); return end
    self:refreshNowPlaying()
end

function NavidromePlugin:playerShuffle()
    local response, err = self:apiRequest("jukeboxControl.view", {{ "action", "shuffle" }})
    if not response then self:showError(err); return end
    self:refreshNowPlaying()
end

return NavidromePlugin
