local settings = {
    {env='user_age', ginga={'user.age'}},
    {env='user_location', ginga={'user.location'}},
    {env='user_genre', ginga={'user.genre'}},
    {env='user_name', ginga={'user.name'}},
    {env='system_screen_size', ginga={'system.screenSize'}},
    {env='system_screen_graphics_size', ginga={'system.screenGraphicSize'}},
    {env='system_audio_type', ginga={'system.audioType'}},
    {env='system_class_number', ginga={'system.classNumber'}},
    {env='system_cpu', ginga={'system.CPU'}},
    {env='system_memory', ginga={'system.memory'}},
    {env='system_operating_system', ginga={'system.operatingSystem'}},
    {env='system_memory', ginga={'system.memory'}},
    {env='system_lua_version', ginga={'system.luaVersion', 'system.lua.version'}},
    {env='system_lua_supported_evt_class', ginga={'system.luaSupportedEventClasses'}},
    {env='system_ncl_version', ginga={'system.nclversion', 'system.ncl.version', 'system.GingaNCL.version'}},
    {env='system_maker_id', ginga={'system.makerId'}},
    {env='system_model_id', ginga={'system.modelId'}},
    {env='system_version_id', ginga={'system.VersionId'}},
    {env='system_serial_number', ginga={'system.serialNumber'}},
    -- {env='system_java_configuration', ginga={'system.javaConfiguration'}},
    -- {env='system_java_profile', ginga={'system.javaProfile'}},
    -- {env='system_mac_address', ginga={'system.macAddress'}},
    -- {env='system_language', ginga={'system.language'}},
    -- {env='system_caption', ginga={'system.caption'}},
    -- {env='system_subtitle', ginga={'system.subtitle'}},
    -- {env='system_has_network', ginga={'system.hasActiveNetwork', 'system.hasNetworkConnectivity'}},
    -- {env='system_max_network_bitrate', ginga={'system.maxNetworkBitRate'}},
    -- {env='si_number_of_services', ginga={'si.numberOfServices'}},
    -- {env='si_number_of_partial_services', ginga={'si.numberOfPartialServices'}},
    -- {env='si_channel_number', ginga={'si.channeNumber', 'si.channelNumber'}},
    {env='deafult_focus_border_color', ginga={'default.focusBorderColor'}},
}

local screens = {
    {left=0, top=0, width=1280, height=720},
    {left=0, top=0, width=1024, height=576},
    {left=127, top=0, width=1024, height=576},
    {left=127, top=72, width=1024, height=576}
}

local P = {
    settings = settings,
    screens = screens
}    

return P
