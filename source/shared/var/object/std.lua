--! @short standard library object
--! @brief can be used as mock

local P = {
    milis = 0,
    delta = 0,
    math = {

    },
    draw = {
        image = function() end,
        clear = function () end,
        color = function () end,
        rect = function () end,
        line = function () end,
        poly = function () end,
        tui_text = function() end
    },
    text = {
        put = function() end,
        print = function() end,
        mensure = function() end,
        font_size = function() end,
        font_name = function() end,
        font_default = function() end
    },
    image = {
        load = function() end,
        draw = function() end
    },
    app = {
        width = 1280,
        height = 720,
        title = function() end,
        reset = function () end,
        load = function() end,
        exit = function () end
    },
    key = {
        axis = {
            x = 0,
            y = 0,
            menu=0,
            up=0,
            down=0,
            left=0,
            right=0,
            a = 0,
            b = 0, 
            c = 0,
            d = 0
        },
        press = {
            menu=false,
            up=false,
            down=false,
            left=false,
            right=false,
            a=false,
            b=false,
            c=false,
            d=false,
            any=false
        }
    }
}

return P;
