local Grain = {}
Grain.__index = Grain

function Grain.new(index, config)
    local self = setmetatable({}, Grain)

    self.index = index
    self.duration = 1
    self.position = 0
    self.running = false
    self.metro = metro.init()

    self.setup_softcut(self, config)
    return self
end

function Grain:setup_softcut(config)
    softcut.enable(self.index, 1)
    softcut.loop(self.index, 1)
    softcut.loop_start(self.index, 0)
    softcut.loop_end(self.index, 1)
    softcut.fade_time(self.index, config.params.fade_time.get())
    softcut.rate_slew_time(self.index, config.params.rate_slew.get())
    softcut.pan_slew_time(self.index, config.params.pan_slew.get())
    softcut.level_slew_time(self.index, 0)
    softcut.level(self.index, 0)
    softcut.buffer(self.index, 1)
    softcut.position(self.index, 0)
    softcut.rec_level(self.index, 0.0)
    softcut.pre_level(self.index, 1.0)
    softcut.rec_offset(self.index, 0)
    softcut.rec(self.index, 0)
    softcut.play(self.index, 1)
end

function Grain:start(position, speed, duration, pan, level, channel)
    self.duration = duration or 10
    self.position = position or 0
    softcut.position(self.index, position or 0)
    softcut.buffer(self.index, channel or 1)
    softcut.level_slew_time(self.index, self.duration)
    softcut.rate(self.index, speed or 1)
    softcut.pan(self.index, pan or 0)
    softcut.level(self.index, level or 1.0)

    self.running = true
    self.metro.event = function() self:mute() end
    self.metro:start(self.duration * 0.5, 1)
end

function Grain:mute()
    softcut.level_slew_time(self.index, self.duration * 0.5)
    softcut.level(self.index, 0)
    self.metro.event = function() self:stop() end
    self.metro:start(self.duration * 0.5, 1)
end

function Grain:stop()
    softcut.level_slew_time(self.index, 0)
    softcut.level(self.index, 0)
    self.metro:stop()
    self.running = false
end

function Grain:free()
    metro.free(self.metro.props.id)
end

return Grain
