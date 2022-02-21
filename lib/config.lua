local config = {}
config.params_mt = {
    __index = function(table, index)
        table[index] = {
            get=function() return params:get(index) end,
            set=function(v) params:set(index, v) end,
            delta=function(d) params:delta(index, d) end,
            string=function() return params:string(index) end,
            set_action=function(action) params:set_action(index, action) end,
            range=function()
                local min = params:get(index.."_min")
                local max = params:get(index.."_max")
                return math.min(min, max), math.max(min, max)
            end
        }
        return table[index]
    end,
}

function config.init()
    config.params = setmetatable({}, config.params_mt)

    config.FPS = 10
    config.alt = false
    config.play_bar = {
        x=1, y=18, w=127, h=21
    }
    config.max_grains = 6       -- Max number of concurent grains, limited by softcut to 6
    config.grains = {}

    config.grain_speeds = {1/4, 1/3, 1/2, 1, 2, 3, 4}

    config.setup_params()
end

function config.setup_params()
    params:add_separator("SOFTCUT GRAINS")
    params:add_binary("running", "Running", "toggle", 1)

    params:add_group("Sample", 2)
    params:add_file("sample_path", "Sample path", "")
    params:add_trigger("clear_sample", "Clear sample")

    params:add_group("Recording", 4)
    params:add_control("rec_pre_level", "Pre level", controlspec.new(0,1,'lin',0.05,0.25), function(p) return (p:get()*100).." %" end)
    params:add_binary("rec_freeze", "Freeze", "toggle", 0)
    params:add_trigger("rec_clear", "Clear", "toggle", 0)
    params:add_number("rec_length", "Length", 1, 60, 30, function(p) return p:get().." s" end)

    params:add_group("Emitter", 2)
    params:add_control("emitter_speed", "Speed", controlspec.new(-5, 5, 'lin', 0.1, 0.25))
    params:add_control("emitter_frequency", "Frequency", controlspec.new(0.01, 10, 'exp', 0.01, 4))

    params:add_group("Grains", 12)
    params:add_option("speed_min", "Speed min", config.grain_speeds, 1)
    params:add_option("speed_max", "Speed min", config.grain_speeds, #config.grain_speeds)
    params:add_control("reverse_prob", "Reverse prob", controlspec.new(0,1,'lin',0.05,0.25), function(p) return (p:get()*100).." %" end)
    params:add_control("duration_min", "Duration min", controlspec.new(0.01, 10, 'exp', 0.01, 0.2))
    params:add_control("duration_max", "Duration max", controlspec.new(0.01, 10, 'exp', 0.01, 1.5))
    params:add_control("pan_min", "Pan min", controlspec.new(-1, 1, 'lin', 0.1, -1))
    params:add_control("pan_max", "Pan max", controlspec.new(-1, 1, 'lin', 0.1, 1))
    params:add_control("level_min", "Level min", controlspec.new(0, 1, 'lin', 0.1, 0.25))
    params:add_control("level_max", "Level max", controlspec.new(0, 1, 'lin', 0.1, 1.0))
    params:add_control("rate_slew", "Rate slew", controlspec.new(0.01,5,'exp',0.01,0.01))
    params:add_control("fade_time", "Fade time", controlspec.new(0.01,5,'exp',0.01,0.25))
    params:add_control("pan_slew", "Pan slew", controlspec.new(0.01,5,'exp',0.01,0.1))
end

return config
