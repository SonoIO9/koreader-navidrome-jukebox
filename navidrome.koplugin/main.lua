local WidgetContainer = require("ui/widget/container/widgetcontainer")
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

local NavidromePlugin = WidgetContainer:extend{
    name = "navidrome",
    is_doc_only = false,
}

--------------------------------------------------------------------------
-- Inicializacion
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
    -- NOTE: ffi/util no expone makePath (vive en frontend/util.lua).
    -- Antes se llamaba pcall(ffiUtil.makePath, ...), que fallaba en silencio
    -- y dejaba el directorio sin crear: por eso io.open(...,"wb") fallaba y
    -- la caratula nunca se descargaba.
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
-- Configuracion y ajustes
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
        return nil, "Configura la direccion del servidor y las credenciales primero."
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

    -- Timeouts acotados: sin esto, LuaSocket espera hasta 60 s y la UI
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
        return nil, "El servidor devolvio una respuesta JSON invalida."
    end

    local response = data["subsonic-response"]
    if type(response) ~= "table" then
        return nil, "Respuesta inesperada del servidor."
    end
    if response.status == "failed" then
        local message = response.error and response.error.message
        return nil, "Navidrome: " .. tostring(message or "la solicitud fallo")
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
    -- Algunas respuestas Subsonic envian un objeto cuando solo hay un resultado.
    if value.id or value.name or value.title then return { value } end
    return value
end

function NavidromePlugin:safeStr(value, fallback)
    if type(value) == "string" then return value end
    if type(value) == "number" then return tostring(value) end
    return fallback or ""
end

--------------------------------------------------------------------------
-- Caratulas: descarga + cache en disco
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
    -- caratulas a medias en la cache si la descarga falla.
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
        self:showMessage("Este elemento no tiene caratula disponible.")
        return
    end
    local path = self:getCoverArtPath(cover_id, 600)
    if not path then
        self:showMessage("No se pudo descargar la caratula.")
        return
    end
    UIManager:show(ImageViewer:new{
        file = path,
        fullscreen = true,
        with_title_bar = true,
        title_text = title or "Caratula",
    })
end

--------------------------------------------------------------------------
-- Menu principal
--------------------------------------------------------------------------

function NavidromePlugin:showMainMenu()
    local items = {
        { text = "Reproductor (Now Playing)", callback = function() self:showNowPlaying() end },
        { text = "Buscar musica", callback = function() self:showSearch() end },
        { text = "Albumes recien anadidos", callback = function() self:showRecentAlbums() end },
        { text = "Albumes aleatorios", callback = function() self:showRandomAlbums() end },
        { text = "Artistas mas escuchados", callback = function() self:showTopArtists() end },
        { text = "Descubre artistas", callback = function() self:showRecommendedArtists() end },
        { text = "Controles rapidos del Jukebox", callback = function() self:showQuickControls() end },
        { text = "Configurar servidor y cuenta", callback = function() self:configure(1) end },
    }
    UIManager:show(Menu:new{ title = "Navidrome Jukebox", item_table = items })
end

function NavidromePlugin:showQuickControls()
    local items = {
        { text = "Detener reproduccion", callback = function() self:jukeboxAction("stop") end },
        { text = "Reanudar reproduccion", callback = function() self:jukeboxAction("start") end },
        { text = "Siguiente cancion", callback = function() self:jukeboxAction("skip") end },
        { text = "Vaciar cola", callback = function() self:jukeboxAction("clear") end },
    }
    UIManager:show(Menu:new{ title = "Controles rapidos", item_table = items })
end

function NavidromePlugin:configure(field_index)
    local fields = {
        { key = "url", title = "Servidor Navidrome", hint = "Ejemplo: https://musica.ejemplo.com" },
        { key = "user", title = "Usuario Navidrome", hint = "Nombre de usuario" },
        { key = "pass", title = "Contrasena Navidrome", hint = "Se guarda localmente en KOReader" },
    }
    local field = fields[field_index]
    if not field then
        self:showMessage("Configuracion guardada. Comprueba la conexion desde Buscar musica.")
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
-- Jukebox: control basico
--------------------------------------------------------------------------

function NavidromePlugin:jukeboxAction(action)
    local response, err = self:apiRequest("jukeboxControl.view", {{ "action", action }})
    if not response then self:showError(err); return end
    local messages = {
        start = "Reproduccion iniciada.", stop = "Reproduccion detenida.",
        skip = "Pasando a la siguiente cancion.", clear = "Cola vaciada.",
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
    self:showMessage("Reproduciendo ahora:\n" .. tostring(label or "Seleccion"))
end

function NavidromePlugin:addSongs(ids, label)
    if not ids or #ids == 0 then self:showMessage("No hay canciones para anadir."); return end
    local response, err = self:jukeboxWithIds("add", ids)
    if not response then self:showError(err); return end
    self:showMessage("Anadido a la cola:\n" .. tostring(label or "Seleccion"))
end

--------------------------------------------------------------------------
-- Busqueda
--------------------------------------------------------------------------

function NavidromePlugin:showSearch()
    local dialog
    dialog = InputDialog:new{
        title = "Buscar en Navidrome",
        input_hint = "Artista, album o cancion",
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
        table.insert(items, { text = "-- ARTISTAS --", callback = function() end })
        for _, artist in ipairs(artists) do
            if artist.id then
                local id = tostring(artist.id)
                local name = self:safeStr(artist.name, "Artista desconocido")
                table.insert(items, { text = "Artista: " .. name,
                    callback = function() self:showArtist(id, name) end })
            end
        end
    end
    if #albums > 0 then
        table.insert(items, { text = "-- ALBUMES --", callback = function() end })
        for _, album in ipairs(albums) do
            if album.id then
                local id = tostring(album.id)
                local name = self:safeStr(album.name or album.title, "Album sin nombre")
                local artist = self:safeStr(album.artist, "Varios")
                table.insert(items, { text = "Album: " .. name .. " - " .. artist,
                    callback = function() self:showAlbum(id, name) end })
            end
        end
    end
    if #songs > 0 then
        table.insert(items, { text = "-- CANCIONES --", callback = function() end })
        for _, song in ipairs(songs) do
            if song.id then
                local id = tostring(song.id)
                local title = self:safeStr(song.title, "Cancion sin titulo")
                local artist = self:safeStr(song.artist, "Artista desconocido")
                table.insert(items, { text = "Reproducir: " .. title .. " - " .. artist,
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
            local album_name = self:safeStr(album.name or album.title, "Album sin nombre")
            local year = self:safeStr(album.year, "")
            local label = "Album: " .. album_name
            if year ~= "" then label = label .. " (" .. year .. ")" end
            table.insert(items, { text = label,
                callback = function() self:showAlbum(album_id, album_name) end })
        end
    end
    if #items == 0 then self:showMessage("Este artista no tiene albumes."); return end
    UIManager:show(Menu:new{ title = "Albumes: " .. name, item_table = items })
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
    table.insert(items, { text = "Ver portada",
        callback = function() self:showCoverArt(cover_id, title) end })

    if #playable_ids > 0 then
        table.insert(items, { text = "Reproducir album ahora",
            callback = function() self:playSongs(playable_ids, title) end })
        table.insert(items, { text = "Anadir album a la cola",
            callback = function() self:addSongs(playable_ids, title) end })
        table.insert(items, { text = "-- CANCIONES --", callback = function() end })
    end
    for _, song in ipairs(songs) do
        if song.id then
            local song_id = tostring(song.id)
            local song_title = self:safeStr(song.title, "Sin titulo")
            local track = self:safeStr(song.track, "")
            local label = (track ~= "" and (track .. ". ") or "") .. song_title
            table.insert(items, { text = label,
                callback = function() self:playSongs({ song_id }, song_title) end })
        end
    end
    if #items == 0 then self:showMessage("Este album no tiene canciones disponibles."); return end
    UIManager:show(Menu:new{ title = "Album: " .. title, item_table = items })
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
            local name = self:safeStr(album.name or album.title, "Album sin nombre")
            local artist = self:safeStr(album.artist, "Varios")
            local year = self:safeStr(album.year, "")
            local label = name .. " - " .. artist
            if year ~= "" then label = label .. " (" .. year .. ")" end
            table.insert(items, {
                text = label,
                callback = function() self:showAlbum(id, name) end,
            })
        end
    end
    if #items == 0 then self:showMessage("No se encontraron albumes."); return end
    UIManager:show(Menu:new{ title = title, item_table = items })
end

function NavidromePlugin:showRecentAlbums()
    self:showAlbumList("Albumes recien anadidos", "newest", 25)
end

function NavidromePlugin:showRandomAlbums()
    self:showAlbumList("Albumes aleatorios", "random", 25)
end

-- Aproximacion de "artistas mas escuchados": no existe un endpoint oficial
-- para esto en la API Subsonic, asi que agregamos el playCount de los
-- albumes mas frecuentes (type=frequent) agrupados por artista.
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
            text = data.name .. "  (aprox. " .. data.score .. " reproducciones)",
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
        self:showMessage("Aun no hay suficiente historial de reproduccion en el servidor.")
        return
    end
    UIManager:show(Menu:new{ title = "Artistas mas escuchados", item_table = items })
end

-- "Recomendacion" real: la API Subsonic/Navidrome no ofrece un motor de
-- recomendaciones generico, asi que mostramos una seleccion aleatoria de
-- tu biblioteca para descubrir cosas que quizas tengas olvidadas.
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
            text = name,
            callback = function() self:showArtist(id, name) end,
        })
    end
    UIManager:show(Menu:new{ title = "Descubre artistas (seleccion aleatoria)", item_table = items })
end

--------------------------------------------------------------------------
-- Reproductor visual (Now Playing)
--------------------------------------------------------------------------

function NavidromePlugin:closeNowPlaying()
    if self.player_dialog then
        UIManager:close(self.player_dialog)
        self.player_dialog = nil
    end
    self.player_cover_holder = nil
    self.player_title_widget = nil
    self.player_subtitle_widget = nil
    self.player_playpause_btn = nil
    self.player_text_group = nil
    self.player_content_group = nil
    self.player_cover_shown_key = nil
end

-- Devuelve la ruta en cache si la caratula ya esta descargada (sin red).
function NavidromePlugin:getCachedCoverPath(cover_id, size)
    if not cover_id or cover_id == "" then return nil end
    size = tonumber(size) or 300
    local filename = self.cover_cache_dir .. "/" .. tostring(cover_id) .. "_" .. tostring(size) .. ".jpg"
    if util.fileExists(filename) then return filename end
    return nil
end

-- Muestra el reproductor al instante (estado "cargando") y deja la
-- consulta al servidor para el siguiente tick de la UI. Asi la pantalla
-- nunca se queda "colgada" esperando a la red.
function NavidromePlugin:showNowPlaying()
    local config = self:getConfig()
    if config.url == "" or config.user == "" or config.pass == "" then
        self:showError("Configura la direccion del servidor y las credenciales primero.")
        return
    end
    self:buildPlayerDialog("Cargando...", "Consultando el servidor", false, nil)
    UIManager:forceRePaint()
    UIManager:nextTick(function() self:refreshNowPlaying() end)
end

function NavidromePlugin:refreshNowPlaying()
    local response, err = self:apiRequest("jukeboxControl.view", {{ "action", "get" }})
    if not response then
        if not self.player_dialog then
            self:buildPlayerDialog("Nada en reproduccion",
                "Anade canciones o albumes desde Buscar / Albumes", false, nil)
            UIManager:forceRePaint()
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
    local title_text = "Nada en reproduccion"
    local subtitle_text = "Anade canciones o albumes desde Buscar / Albumes"
    if current_song then
        cover_id = current_song.coverArt
        title_text = self:safeStr(current_song.title, "Sin titulo")
        subtitle_text = self:safeStr(current_song.artist, "Artista desconocido") ..
            "  -  " .. self:safeStr(current_song.album, "")
    end

    -- 1) Texto, boton y caratula cacheada: todo sin red.
    if not self.player_dialog then
        self:buildPlayerDialog(title_text, subtitle_text, is_playing, cover_id)
    else
        self:setPlayerText(title_text, subtitle_text, is_playing)
        self:setPlayerCover(cover_id, 400)
        UIManager:setDirty(self.player_dialog, "ui")
    end
    UIManager:forceRePaint()

    -- 2) Si la caratula no estaba en cache, se descarga en su propio tick
    --    para no bloquear la UI (esto era lo que parecia "tildar").
    if cover_id and cover_id ~= "" and not self:getCachedCoverPath(cover_id, 400) then
        UIManager:nextTick(function()
            if not self.player_dialog then return end
            local path = self:getCoverArtPath(cover_id, 400)
            if path and self.player_dialog then
                self:setPlayerCover(cover_id, 400)
                UIManager:setDirty(self.player_dialog, "ui")
                UIManager:forceRePaint()
            end
        end)
    end
end

function NavidromePlugin:buildPlayerDialog(title_text, subtitle_text, is_playing, cover_id)
    self:closeNowPlaying()

    local content_width = Screen:getWidth() * 0.8
    self.player_cover_size = math.floor(Screen:getWidth() * 0.6)

    -- Contenedor de tamano fijo: mantiene el layout estable cuando
    -- pasamos del marcador musical a la caratula real.
    self.player_cover_holder = CenterContainer:new{
        dimen = { w = self.player_cover_size, h = self.player_cover_size },
    }

    self.player_title_widget = TextBoxWidget:new{
        text = title_text or "",
        width = content_width,
        face = Font:getFace("cfont", 20),
        alignment = "center",
    }
    self.player_subtitle_widget = TextBoxWidget:new{
        text = subtitle_text or "",
        width = content_width,
        face = Font:getFace("cfont", 16),
        alignment = "center",
    }

    local btn_size = Screen:scaleBySize(56)
    self.player_playpause_btn = Button:new{
        text = is_playing and "||" or ">",
        width = btn_size,
        callback = function() self:playerToggle(is_playing) end,
    }
    local buttons_row = HorizontalGroup:new{
        Button:new{
            text = "<<",
            width = btn_size,
            callback = function() self:playerSkip(-1) end,
        },
        self.player_playpause_btn,
        Button:new{
            text = ">>",
            width = btn_size,
            callback = function() self:playerSkip(1) end,
        },
        Button:new{
            text = "Shuffle",
            width = btn_size,
            callback = function() self:playerShuffle() end,
        },
        Button:new{
            text = "Refresh",
            width = btn_size,
            callback = function() self:refreshNowPlaying() end,
        },
        Button:new{
            text = "X",
            width = btn_size,
            callback = function() self:closeNowPlaying() end,
        },
    }

    self.player_text_group = VerticalGroup:new{
        align = "center",
        self.player_title_widget,
        self.player_subtitle_widget,
    }
    self.player_content_group = VerticalGroup:new{
        align = "center",
        self.player_cover_holder,
        self.player_text_group,
        buttons_row,
    }

    local dialog = CenterContainer:new{
        dimen = Screen:getSize(),
        modal = true,
        -- Consume los toques que no caigan en un boton, para que no se
        -- filtren al menu que queda por debajo del reproductor.
        onTap = function() return true end,
        FrameContainer:new{
            background = Blitbuffer.COLOR_WHITE,
            radius = Size.radius.window,
            padding = Size.padding.large,
            bordersize = Size.border.window,
            self.player_content_group,
        },
    }

    self.player_dialog = dialog
    UIManager:show(dialog)

    -- Rellena caratula y textos una vez el dialogo ya existe.
    self:setPlayerCover(cover_id, 400)
    self:setPlayerText(title_text, subtitle_text, is_playing)
end

function NavidromePlugin:setPlayerText(title_text, subtitle_text, is_playing)
    if not self.player_dialog then return end
    if self.player_title_widget and title_text then
        self.player_title_widget:setText(title_text)
    end
    if self.player_subtitle_widget and subtitle_text then
        self.player_subtitle_widget:setText(subtitle_text)
    end
    if self.player_playpause_btn then
        self.player_playpause_btn:setText(is_playing and "||" or ">")
    end
    -- Los contenedores cachean su tamano; hay que invalidarlo tras cambiar
    -- el texto para que el layout se recalcule.
    if self.player_text_group then self.player_text_group:resetLayout() end
    if self.player_content_group then self.player_content_group:resetLayout() end
end

-- Actualiza la caratula in-place. Si ya se muestra esa misma imagen no la
-- vuelve a reconstruir (asi no parpadea al refrescar).
function NavidromePlugin:setPlayerCover(cover_id, size)
    local holder = self.player_cover_holder
    if not holder then return end

    size = tonumber(size) or 400
    local path = self:getCachedCoverPath(cover_id, size)
    local key = tostring(cover_id or "") .. "|" .. tostring(path or "")
    if self.player_cover_shown_key == key and holder[1] then
        return
    end

    holder:clear()
    if path then
        table.insert(holder, ImageWidget:new{
            file = path,
            width = self.player_cover_size,
            height = self.player_cover_size,
        })
    else
        table.insert(holder, TextWidget:new{
            text = "Musica",
            face = Font:getFace("cfont", 24),
        })
    end
    self.player_cover_shown_key = key

    if self.player_content_group then self.player_content_group:resetLayout() end
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
    if length == 0 then self:showMessage("La cola esta vacia."); return end

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
