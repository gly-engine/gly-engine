local App = {
    title = 'PIP Grid',
    version = '1.0.0'
}

function App.draw(self, std)
    std.image.draw('assets/lines.png', 0, 0)
end

function App.key(self, std)
    if std.key.press.up or std.key.press.left or std.key.press.right or std.key.press.down then
        std.media.pip(500, 13, 387, 218)
    end
end

return App
