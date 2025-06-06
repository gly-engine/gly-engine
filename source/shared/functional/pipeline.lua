local function pipe(self)
    return function()
        self:run()
    end
end

local function stop(self)
    if self.pipeline and not self.pipeline2 then
        self.pipeline2 = self.pipeline
        self.pipeline = nil
    end
end

local function resume(self)
    if not self.pipeline and self.pipeline2 then
        self.pipeline = self.pipeline2
        self.pipeline2 = nil
        self:run()
    end
end

local function run(self)
    self.pipeline_current = self.pipeline_current or 1
    while self.pipeline and self.pipeline_current and self.pipeline_current <= #self.pipeline do
        self.pipeline[self.pipeline_current]()
        if self.pipeline_current then
            self.pipeline_current = self.pipeline_current + 1
        end
    end
    return self
end

local function reset(self)
    self.pipeline = self.pipeline or self.pipeline2
    self.pipeline2 = nil
    self.pipeline_current = nil
end

local function clear(self)
    self.pipeline_current = nil
    self.pipeline2 = nil
    self.pipeline = nil
end

local P = {
    reset=reset,
    clear=clear,
    pipe=pipe,
    stop=stop,
    resume=resume,
    run=run
}

return P
