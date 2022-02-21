-- Softcut grains
-- Simple grain / delay effect
-- using softcut

-- TODO
-- Connect buttons and encoders to controls when on script page
-- Add control for per-grain filter
-- Add control for position jitter
-- Draw play head and record head differently
-- Cleanup code

config = include('lib/config')
Grain = include('lib/grain')

update_metro =metro.init()

max_grains = 0
sample_length = 0
emitter_head = {
    position = 0,           -- Position in sample, in seconds
    last_emit_time = 100,   -- How long ago was the last grain emitted, in seconds
}
recorder_head = {
    position = 0            -- Record head position, in seconds
}
recording = false

function init()
    config.init()
    max_grains = config.max_grains
    set_actions()
    init_grains()

    params:default()

    norns.enc.sens(1, 12)
    update_metro.event = update
    update_metro:start(1 / config.FPS)
end

function set_actions()
    -- Sample
    config.params.sample_path.set_action(function()
        softcut.buffer_clear()
        recording = config.params.sample_path.get() == ""
        if recording then
            max_grains = config.max_grains - 2
            sample_length = config.params.rec_length.get()
            recording_position = util.clamp(recorder_head.position, 0, sample_length)
            init_grains()
            for i=1,2 do
                local index=i+max_grains
                softcut.rec_level(index, 1-config.params.rec_freeze.get())
                softcut.pre_level(index, config.params.rec_pre_level.get())
                softcut.position(index, recorder_head.position)
            end
            for i=1,config.max_grains do
                softcut.loop_end(i, sample_length)
            end
        else
            max_grains = config.max_grains
            init_grains()
            load_file()
        end
    end)
    config.params.clear_sample.set_action(function() config.params.sample_path.set("") end)

    -- Record
    config.params.rec_freeze.set_action(function()
        if recording then
            for i=1,2 do
                local index=i+max_grains
                softcut.rec(index, 1-config.params.rec_freeze.get())
            end
        end
    end)
    config.params.rec_clear.set_action(function() if recording then softcut.buffer_clear() end end)
    config.params.rec_pre_level.set_action(function()
        if recording then
            for i=1,2 do
                local index=i+max_grains
                softcut.pre_level(index, config.params.rec_pre_level.get())
            end
        end
    end)
    config.params.rec_length.set_action(function()
        if recording then
            sample_length = config.params.rec_length.get()
            recorder_head.position = util.clamp(recorder_head.position, 0, sample_length)
            for i=1,2 do
                local index=i+max_grains
                softcut.position(index, recorder_head.position)
            end
            for i=1,config.max_grains do
                softcut.loop_end(i, sample_length)
            end
        end
    end)
end

function load_file()
    local ch, samples, sample_rate = audio.file_info(config.params.sample_path.get())
    sample_length = samples / sample_rate
    emitter_head.position = 0
    softcut.buffer_read_stereo(config.params.sample_path.get(), 0, 0, -1, 0, 1)
    for i=1,max_grains do
        softcut.loop_end(i, sample_length)
    end
    print("file loaded ("..sample_length.." s, "..ch.." channels)")
end

function init_grains()
    if recording then
        sample_length = config.params.rec_length.get()
        audio.level_adc_cut(1)
        for i=1,2 do
            local index=i+max_grains
            softcut.enable(index, 1)
            softcut.position(index, recorder_head.position)
            softcut.level(index, 0)
            softcut.loop(index, 1)
            softcut.loop_start(index, 0)
            softcut.loop_end(index, sample_length)
            softcut.rate(index, 1)
            softcut.level_input_cut(i, index, 1.0)
            softcut.rec_level(index, 1.0)
            softcut.pre_level(index, config.params.rec_pre_level.get())
            softcut.rec_offset(index, 0)
            softcut.rec(index, 1-config.params.rec_freeze.get())
            softcut.play(index, 1)
        end
    end

    for i=1,#config.grains do
        config.grains[i]:free()
    end

    config.grains = {}
    for i=1,max_grains do
        config.grains[i] = Grain.new(i, config)
    end

    softcut.event_position(update_grain)
end

function emit_grain()
    local grain_index = 0
    for i=1,max_grains do
        if not config.grains[i].running then
            grain_index = i
            break
        end
    end
    if grain_index > 0 then
        local min, max = config.params.speed.range()
        local speed = config.grain_speeds[math.random(min, max)]
        min, max = config.params.duration.range()
        -- Faster grains are shorter, grains are also shorter when more frequent
        local duration = util.linlin(0, 1, min, max, math.random()) * sample_length / math.max(1, speed) / config.params.emitter_frequency.get()
        if math.random() < config.params.reverse_prob.get() then speed = speed * -1 end
        min, max = config.params.pan.range()
        local pan = util.linlin(0, 1, min, max, math.random())
        min, max = config.params.level.range()
        local level = util.linlin(0, 1, min, max, math.random())
        config.grains[grain_index]:start(
            emitter_head.position, speed, duration, pan, level, math.random(1, 2)
        )
    end
end

function update_grain(index, position)
    if index <= max_grains then
        if config.grains[index].running then
            config.grains[index].position = position
        end
    elseif recording and index == max_grains+1 then
        recorder_head.position = position
    end
end

function key(index, state)
    if index == 1 then
        config.alt = state == 1
    elseif index == 2 and state == 1 then
        emit_grain()
    end
end

function enc(index, delta)
end

function update()
    if config.params.running.get() == 1 then
        local p = emitter_head.position
        p = p + config.params.emitter_speed.get() / config.FPS
        if p < 0 then
            p = sample_length + p
        elseif p > sample_length then
            p = p - sample_length
        end
        emitter_head.position = p

        if emitter_head.last_emit_time > (1/config.params.emitter_frequency.get()) then
            emitter_head.last_emit_time = 0
            emit_grain()
        else
            emitter_head.last_emit_time = emitter_head.last_emit_time + (1 / config.FPS)
        end
    end

    -- Update grain positions for drawing
    for i=1,max_grains do softcut.query_position(i) end
    if recording then softcut.query_position(max_grains+1) end
    redraw()
end

function redraw()
    screen.clear()
    screen.fill()

    screen.aa(0)
    screen.line_width(1)
    screen.level(5)
    for i=1,max_grains do
        if config.grains[i].running then
            screen.move(
                config.play_bar.x + (config.play_bar.w - config.play_bar.x) * config.grains[i].position / sample_length,
                config.play_bar.y
            )
            screen.line_rel(0, config.play_bar.h)
            screen.stroke()
        end
    end

    screen.level(10)
    screen.move(
        config.play_bar.x + (config.play_bar.w - config.play_bar.x) * emitter_head.position / sample_length,
        config.play_bar.y
    )
    screen.line_rel(0, config.play_bar.h)
    screen.stroke()

    if recording then
        screen.level(15)
        screen.line_width(2)
        screen.move(
            config.play_bar.x + (config.play_bar.w - config.play_bar.x) * recorder_head.position / sample_length,
            config.play_bar.y
        )
        screen.line_rel(0, config.play_bar.h)
        screen.stroke()
        screen.line_width(1)
    end

    screen.rect(
        config.play_bar.x, config.play_bar.y, config.play_bar.w, config.play_bar.h
    )
    screen.stroke()

    screen.aa(1)
    screen.line_width(1)
    screen.move(5, 50)
    screen.text("Test grains")
    screen.update()
end

function r()
    norns.script.load(norns.state.script)
end
