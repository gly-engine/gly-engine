local math = require('math')

local function fps_counter(fps_limit, fps_tracker, current_time)
    if current_time >= fps_tracker.last_check + 1000 then
        fps_tracker.last_check = current_time
        fps_tracker.total_fps = fps_tracker.frame_count
        fps_tracker.frame_count = 0

        if fps_tracker.drop_count == 0 then
            return true
        end

        if fps_tracker.total_fps + fps_tracker.drop_count > fps_limit then
            fps_tracker.fall_streak = 0
            return true
        end

        fps_tracker.fall_streak = fps_tracker.fall_streak + 1
        
        if fps_tracker.fall_streak >= fps_tracker.allowed_falls then
            fps_tracker.fall_streak = 0
            return false
        end
    end
    
    fps_tracker.frame_count = fps_tracker.frame_count + 1
    fps_tracker.time_delta = current_time - fps_tracker.last_frame_time
    fps_tracker.last_frame_time = current_time

    return true
end

local function install(std, engine, config_fps)
    local index = 1
    local fps_obj = {total_fps=0,frame_count=0,last_check=0,last_frame_time=0,time_delta=0,fall_streak=0}

    config_fps.inverse_list = {}
    fps_obj.allowed_falls = engine.root.config.fps_time
    fps_obj.drop_count = engine.root.config.fps_drop

    while index <= #config_fps.list do
        config_fps.inverse_list[config_fps.list[index]] = index
        index = index + 1
    end

    std.bus.listen('pre_loop', function()
        local fpsmax = engine.root.config.fps_max
        local milis = config_fps.uptime()
        local index = config_fps.inverse_list[fpsmax]
        engine.fps = fps_obj.total_fps
        std.delta = fps_obj.time_delta 
        std.milis = milis
        if not fps_counter(fpsmax, fps_obj, milis) then
            if index < #config_fps.list then
                engine.root.config.fps_max = config_fps.list[index + 1]
            end
        end

        local delay = config_fps.time[index]
        engine.delay = math.max(1, delay - math.max(0, fps_obj.time_delta - delay))
    end)
end

local P = {
    install=install
}

return P
