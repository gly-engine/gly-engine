local test = require('tests/framework/microtest')
local m3u8 = require('source/shared/string/decode/m3u8')

function test_m3u8_not_playlist()
    assert(pcall(m3u8.decode, 'TITLE=foo') == false)
    assert(pcall(m3u8.decode, 'name,age\nfoo,1') == false)
end

function test_m3u8_iptv()
    local out = m3u8.decode(table.concat({
        '\239\187\191#EXTM3U url-tvg="http://epg.xml"',
        '#PLAYLIST:My Channels',
        '#EXTINF:-1 tvg-id="news.br" tvg-name="News, BR" group-title="News",Daily News',
        'http://example.com/news.m3u8',
        '',
        '#EXTINF:-1,Sports',
        '#EXTGRP:Sport',
        'http://example.com/sports.ts'
    }, '\r\n'))
    assert(out.title == 'My Channels')
    assert(out.header['url-tvg'] == 'http://epg.xml')
    assert(#out.playlist == 2)
    assert(out.playlist[1].url == 'http://example.com/news.m3u8')
    assert(out.playlist[1].title == 'Daily News')
    assert(out.playlist[1].duration == -1)
    assert(out.playlist[1].group == 'News')
    assert(out.playlist[1].attrs['tvg-id'] == 'news.br')
    assert(out.playlist[1].attrs['tvg-name'] == 'News, BR')
    assert(out.playlist[2].title == 'Sports')
    assert(out.playlist[2].group == 'Sport')
    assert(out.playlist[2].url == 'http://example.com/sports.ts')
end

function test_m3u8_hls_master()
    local out = m3u8.decode(table.concat({
        '#EXTM3U',
        '#EXT-X-VERSION:3',
        '#EXT-X-INDEPENDENT-SEGMENTS',
        '#EXT-X-STREAM-INF:BANDWIDTH=1280000,RESOLUTION=640x360,CODECS="avc1.42e00a,mp4a.40.2"',
        'low/index.m3u8',
        '#EXT-X-STREAM-INF:BANDWIDTH=2560000,RESOLUTION=1280x720',
        'high/index.m3u8'
    }, '\n'))
    assert(out.tags.version == '3')
    assert(out.tags['independent-segments'] == true)
    assert(#out.playlist == 2)
    assert(out.playlist[1].url == 'low/index.m3u8')
    assert(out.playlist[1].attrs.bandwidth == '1280000')
    assert(out.playlist[1].attrs.resolution == '640x360')
    assert(out.playlist[1].attrs.codecs == 'avc1.42e00a,mp4a.40.2')
    assert(out.playlist[2].attrs.resolution == '1280x720')
end

function test_m3u8_hls_media()
    local out = m3u8.decode(table.concat({
        '#EXTM3U',
        '#EXT-X-TARGETDURATION:10',
        '#EXTINF:9.009,',
        'segment0.ts',
        '#EXTINF:3.003,',
        'segment1.ts',
        '#EXT-X-ENDLIST'
    }, '\n'))
    assert(out.tags.targetduration == '10')
    assert(out.tags.endlist == true)
    assert(#out.playlist == 2)
    assert(out.playlist[1].duration == 9.009)
    assert(out.playlist[1].title == nil)
    assert(out.playlist[2].url == 'segment1.ts')
end

test.unit(_G)
