local str_http = require('source/shared/string/encode/http')
local json = require('source/third_party/rxi_json')

local url = 'https://api.github.com/repos/gly-engine/gly-engine/releases'
local ver_file = io.open('source/version.lua')
local ver_text = ver_file and ver_file:read('*a')
local lmajor, lminor, lpatch = (ver_text or '0.0.0'):match('(%d+)%.(%d+)%.(%d+)')
local version_local = (lmajor * 10000) + (lminor * 100) + lpatch

local cmd = str_http.create_request('GET', url).not_status().to_curl_cmd()
local pid = io.popen(cmd)
local stdout = pid:read('*a')
local github = json.decode(stdout)

pid:close()

local rmajor, rminor, rpatch = github[1]['tag_name']:match('(%d+)%.(%d+)%.(%d+)')
local version_remote = (rmajor * 10000) + (rminor * 100) + rpatch

print('local:', lmajor, lminor, lpatch)
print('remote:', rmajor, rminor, rpatch)

assert(version_local > version_remote, 'bump version!')
