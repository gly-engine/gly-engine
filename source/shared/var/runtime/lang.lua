local os = require('os')

local function get_sys_lang()
    if not os then
        return 'en-US'
    end
    
    local lang, country = (os.setlocale() or ''):match('LC_CTYPE=(%a%a).(%a%a)')

    if not lang then
        lang, country = (os.getenv('LANG') or ''):match('(%a%a).(%a%a)')
    end

    if not lang then
        lang, country = 'en', 'US'
    end
    
    return string.lower(lang)..'-'..string.upper(country)
end

local P = {
    get_sys_lang = get_sys_lang
}

return P