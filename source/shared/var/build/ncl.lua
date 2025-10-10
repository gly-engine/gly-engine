local settings = {
    'genre.age',
    'genre.genre',
    'genre.location',
    'si.channelNumber',
    'si.numberOfPartialServices',
    'si.numberOfServices',
    'system.CPU',
    'system.GingaJ.version',
    'system.GingaNCL.version',
    'system.audioType',
    'system.caption',
    'system.classNumber',
    'system.devNumber',
    'system.gingaJ.version',
    'system.gingaNCL.version',
    'system.gingaNCLProfile',
    'system.gingaReceiverProfile',
    'system.hasActiveNetwork',
    'system.hasNetworkConnectivity',
    'system.info',
    'system.javaConfiguration',
    'system.javaProfile',
    'system.language',
    'system.luaSupportedEventClasses',
    'system.luaVersion',
    'system.macAddress',
    'system.markerId',
    'system.maxNetworkBitRate',
    'system.memory',
    'system.modelId',
    'system.ncl.version',
    'system.nclversion',
    'system.operatingSystem',
    'system.persistent',
    'system.returnBitRate',
    'system.screenGraphicSize',
    'system.screenSize',
    'system.serialNumber',
    'system.subtitle',
    'system.versionId'
}

local screens = {
    {left=0, top=0, width=1280, height=720},
    {left=0, top=0, width=1024, height=576}
}

return {
    settings = settings,
    screens = screens
}
