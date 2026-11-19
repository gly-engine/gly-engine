local test = require('tests/framework/microtest')
local desktop = require('source/shared/string/decode/desktop')

function test_desktop_not_entry()
    assert(pcall(desktop.decode, 'TITLE=foo') == false)
    assert(pcall(desktop.decode, '[Other]\nName=foo') == false)
    assert(pcall(desktop.decode, '') == false)
    assert(pcall(desktop.decode, 'name,age\nfoo,1') == false)
end

function test_desktop_invalid_line()
    assert(pcall(desktop.decode, '[Desktop Entry]\nName=foo\nnot a key') == false)
    assert(pcall(desktop.decode, '[Desktop Entry]\nName=a\n[Desktop Entry]\nName=b') == false)
end

function test_desktop_entry()
    local out = desktop.decode(table.concat({
        '\239\187\191# comment',
        '',
        '[Desktop Entry]',
        'Type=Application',
        'Name=Pong Game',
        'Name[pt_BR]=Jogo Pong',
        'Comment = line one\\nline\\stwo',
        'Exec=pong %U',
        'Categories=Game;ArcadeGame;',
        'Actions=new;',
        '',
        '[Desktop Action new]',
        'Name=New Game',
        'Exec=pong --new'
    }, '\r\n'))
    local entry = out['Desktop Entry']
    assert(entry.Type == 'Application')
    assert(entry.Name == 'Pong Game')
    assert(entry['Name[pt_BR]'] == 'Jogo Pong')
    assert(entry.Comment == 'line one\nline two')
    assert(entry.Exec == 'pong %U')
    assert(entry.Categories == 'Game;ArcadeGame;')
    assert(out['Desktop Action new'].Name == 'New Game')
    assert(out['Desktop Action new'].Exec == 'pong --new')
end

test.unit(_G)
