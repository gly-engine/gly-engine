local version = require('source/version')

local function version_message()
  return true, version
end

local function meta()
  return {
    meta={
      title='gly-cli',
      version=version,
      author='RodrigoDornelles',
      description='not implemented!'
    }
  }
end

local P = {
  meta = meta,
  version = version_message
}

return P
