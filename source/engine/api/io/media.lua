--! @defgroup std
--! @{
--! @defgroup media
--! @{
--! @details streamming videos and music
--! @pre require @c media.video
--! @cond
--! @note You can also use @c mock.video and @c mock.music when the platform does not yet have support,@n
--! or you want the media to be optional and keep the api.
--! @endcond
--!
--! @page media_video Video
--! @par Example
--! @code
--! std.media.video()
--!     :src('http://t.gamely.com.br/rick.mpg')
--!     :play()
--! @endcode
--!
--! @page media_stream Stream
--! can play @b hls and @b dash,
--! also can use @c std.media.stream()
--! @pre in @ref html5 cores need flag @c --videojs
--! @par Example
--! @code
--! std.media.video()
--!     :src('https://dash.akamaized.net/dash264/TestCasesIOP33/adapatationSetSwitching/5/manifest.mpd')
--!     :play()
--! @endcode
--!
--! @page media_youtube Youtube
--! @pre only avaliable in @ref html5 cores
--! also     can use @c std.media.youtube()
--! @par Example
--! @code
--! std.media.video()
--!     :src('https://www.youtube.com/watch?v=dVYl5ImNjow&list=PL4Gr5tOAPttKUXrXjulSCYa-L4xIwDyTi')
--!     :play()
--! @endcode

--! @fakefunc src(url)

--! @fakefunc play()

--! @fakefunc pause()

--! @fakefunc resume()

--! @fakefunc stop()

--! @fakefunc resize(width, height)

--! @fakefunc position(pos_x, pos_y)

--! @}
--! @}

local function media_create(node, channels, handler)
    local decorator = function(func)
        func = func or function() end
        return function(self, a, b, c)
            func(0, a, b, c)
            return self
        end
    end
    local self = { 
        -- api
        src = decorator(handler.source),
        play = decorator(handler.play),
        pause = decorator(handler.pause),
        resume = decorator(handler.resume),
        stop = decorator(handler.stop),
        position = decorator(handler.position),
        resize = decorator(handler.resize),
        in_mutex = handler.mutex or function() return false end,
        get_error = handler.error or function() return nil end,
        -- internal
        node = node,
        apply = function() end
    }

    return function()
        return self
    end
end

local function install(std, engine, handler, name)
    std.media = std.media or {}
    local mediatype = name:match('%w+%.(%w+)')
    if handler.install then
        handler.install(std, engine, mediatype, name)
    end
    if not std.media[mediatype] then
        local channels = handler.bootstrap and handler.bootstrap(mediatype)
        if (not channels or channels == 0) and handler.bootstrap then
            error('media '..mediatype..' is not supported!')
        end
        local node = std.node and std.node.load({})
        std.media[mediatype] = media_create(node, channels, handler)
    end
end

local P = {
    install=install
}

return P
