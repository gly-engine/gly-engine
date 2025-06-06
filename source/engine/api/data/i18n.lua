local language = 'en-US'
local language_default = 'en-US'

local language_list = {}
local language_inverse_list = {}

local translate = {}

local function update_languages(texts)
    local index = 1

    translate = texts
    language_list = {language_default}
    language_inverse_list = {[language_default]=1}

    repeat
        local lang = next(texts)
        if lang then
            index = index + 1
            language_inverse_list[lang] = index
            language_list[#language_list + 1] = lang
        end
    until lang
end

--! @defgroup std
--! @{
--! @defgroup i18n
--! @details support multi-language games.
--! @pre require @c i18n
--! @details
--! The format of language must be @c aa-AA, respectively <b>ISO 639</b> and <b>ISO 3166</b>,
--! This module is based on the system language,
--! but can also store the last saved language.
--!
--! @par Example
--! @code
--! local function i18n(std, game)
--!     return {
--!         ['pt-BR'] = {
--!             ['hello world'] = 'ola mundo'
--!         },
--!         ['es-ES'] = {
--!             ['hello world'] = 'hola mundo'
--!         }
--!     }
--! end
--!
--! local function draw(std, game)
--!     std.draw.clear(std.color.black)
--!     std.draw.color(std.color.white)
--!     std.draw.text(8, 8, 'hello world')
--! end
--! 
--! local P = {
--!     meta = {
--!         title='Hello'
--!     },
--!     config = {
--!         require='i18n'
--!     },
--!     callbacks = {
--!         i18n=i18n,
--!         draw=draw
--!     }
--! }
--!
--! return P
--! @endcode
--! @{

--! @par Example
--! @code
--! local some_text = std.i18n.get_text('some-text')
--! std.draw.text(8, 8, rot32(some_text))
--! @endcode
local function get_text(old_text)
    local new_text = translate[language] and translate[language][old_text]
    return new_text or old_text
end

--! @par Example
--! @code
--! local language = std.i18n.get_language()
--! std.draw.text(8, 8, language)
--! @endcode
local function get_language()
    return language
end

--! @par Example
--! @code
--! std.i18n.set_langauge('en-US')
--! @endcode
local function set_language(l)
    if language_inverse_list[l] then
        language = l
    else 
        language = language_default
    end
end

--! @renamefunc next
--! @hideparam to
--! @par Example
--! @code
--! if game.state == game.menu_lang then
--!     std.i18n.next(std.key.axis.y)
--! end
--! @endcode
local function next_language(to)
    local index = language_inverse_list[language]
    local incr = to or 1
    if index then
        index = index + incr
        if index > #language_list then
            index = 1
        end
        if index <= 0 then
            index = #language_list
        end
        index = index == 0 and 1 or index
        set_language(language_list[index])
    end
end

--! @renamefunc back
--! @par Example
--! @code
--! if game.state == game.menu_lang and std.key.press.left then
--!     std.i18n.back()
--! end
--! @endcode
local function back_language()
    next_language(-1)
end

--! @}
--! @}

local function decorator_draw_text(func)
    return function (x, y, text, a, b, c)
        return func(x, y, get_text(text), a, b, c)
    end
end

local function install(std, engine, cfg)
    if not (std and std.text and std.text.print) then
        error('missing draw text')
    end

    local old_put = std.text.put
    local old_print = std.text.print
    local old_print_ex = std.text.print_ex

    local callback_lang = function(result)
        update_languages(result)
        if cfg and cfg.get_language then
            set_language(cfg.get_language())
        end
    end

    if not std.node and engine.root.callbacks.i18n then
        callback_lang(engine.root.callbacks.i18n())
    else
        std.bus.listen('ret_i18n', callback_lang)
        std.bus.emit_next('i18n')
    end
    
    std.text.put = decorator_draw_text(old_put)
    std.text.print = decorator_draw_text(old_print)
    std.text.print_ex = decorator_draw_text(old_print_ex)
    std.i18n = {}
    std.i18n.get_text = get_text
    std.i18n.get_language = get_language
    std.i18n.set_language = set_language
    std.i18n.back = back_language
    std.i18n.next = next_language
end

local P = {
    install=install
}

return P
