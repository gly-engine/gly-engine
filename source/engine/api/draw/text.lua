local util_decorator = require('src/lib/util/decorator')

--! @defgroup std
--! @{
--! @defgroup text
--! @{
--! @par Align text
--! @code{.java}
--! std.text.print_ex(240, 80, 'center', 0)
--! std.text.print_ex(240, 80, 'right', -1)
--! std.text.print_ex(240, 80, 'left', 1)
--! @endcode
--! @par Print and Mensure
--! @code{.java}
--! local w = std.text.print_ex(240, 80, 'foo')
--! std.text.print(240, 80 + w, 'bar')
--! @endcode
--! 

--! @short std.text.font_size
--! @par Example
--! @code{.java}
--! std.text.font_size(8)
--! @endcode
--! @fakefunc font_size(size)

--! @short std.text.font_name
--! @par Example
--! @code{.java}
--! std.text.font_name('Comic Sans')
--! @endcode
--! @fakefunc font_name(name)

--! @short std.text.font_default
--! @par List
--! @li @b 1 [Noto Sans](https://fonts.google.com/noto/specimen/Noto+Sans)
--! @li @b 2 [IBM Plex Sans](https://fonts.google.com/specimen/IBM+Plex+Sans)
--!
--! @par Example
--! @code{.java}
--! std.text.font_default(1)
--! @endcode
--! @fakefunc font_default(id)

--! @short std.text.mensure
--! @fakefunc mensure(text)

--! @short std.text.print
--! @par Alternatives
--! @li @b std.text.print_ex returning @ref mensure and can align @b -1, @b 0 or @b 1
--! @par Example
--! @code{.java}
--! std.text.put((std.app.width/4) * 3, 8, '1/4 text')
--! @endcode
--! @fakefunc print(pos_x, pos_y, text)

--! @short std.text.put
--! @renamefunc put
--! @hideparam std
--! @hideparam engine
--! @hideparam font_previous
--! @brief print text grid in based 80x24
--! @par Example
--! @code{.java}
--! std.text.put(20, 1, '1/4 text')
--! @endcode
local function text_put(std, engine, font_previous, pos_x, pos_y, text, size)
    size = size or 2
    local hem = engine.current.data.width / 80
    local vem = engine.current.data.height / 24
    local font_size = hem * size

    std.text.font_default(0)
    std.text.font_size(font_size)
    std.text.print(pos_x * hem, pos_y * vem, text)
    font_previous()
end

--! @cond
local function text_print_ex(std, engine, x, y, text, align_x, align_y)
    local w, h = std.text.mensure(text)
    local aligns_x, aligns_y = {w, w/2, 0}, {h, h/2, 0}
    std.text.print(x - aligns_x[(align_x or 1) + 2], y - aligns_y[(align_y or 1) + 2], text)
    return w, h
end
--! @endcond

--! @}
--! @}

local function install(std, engine, config)
    std.text.print_ex = util_decorator.prefix2(std, engine, text_print_ex)
    std.text.put = util_decorator.prefix3(std, engine, config.font_previous, text_put)
end

local P = {
    install=install
}

return P
