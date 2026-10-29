local cmd = function(c) assert(require('os').execute(c), c) end
local game = arg[1]
local file = './html/game.lua'

if game == '2games' then
    game = 'two_games'
end

if game == 'launcher' then
    cmd('./cli.sh build @'..game..' --core html5 --engine @native --outdir ./html/ --enginecdn')
elseif game == 'gridsystem' or game == 'maze3d' or game == 'two_games' then
    cmd('./cli.sh build @'..game..' --core html5 --engine @native --outdir ./html/ --enginecdn --fengari')
elseif game == 'pong' then
    cmd('./cli.sh build @'..game..' --core html5 --engine @micro --outdir ./html/ --fengari --enginecdn')
elseif game == 'fakestream' then
    cmd('./cli.sh build @stream --core html5 --engine @native --outdir ./html/ --enginecdn --videofake')
elseif game == 'rickstream' then
    cmd('./cli.sh build @stream --core html5 --engine @native --fengari --outdir ./html/ --enginecdn')
    cmd('./cli.sh fs replace ./html/game.lua ./html/game.lua --format medias --replace rick')
elseif game == 'videostream' then
    cmd('./cli.sh build @stream --core html5 --engine @native --outdir ./html/ --fengari --enginecdn --videojs')
else
    cmd('./cli.sh build @'..game..' --core html5 --engine @lite --outdir ./html/ --fengari --enginecdn')
end
