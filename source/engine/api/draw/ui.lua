local browser_ui  = require('source/engine/browser/ui')
local browser_jsx = require('source/engine/browser/jsx')

local function install(std, engine, application)
    browser_ui.install(std, engine)
    browser_jsx.install(std, engine)
end

local P = {
    install = install
}

return P
