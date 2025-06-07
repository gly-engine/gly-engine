local pipeline = require ('source/shared/functional/pipeline')
local test = require('tests/framework/microtest')

function test_pipe()
    local test_obj = {
        run_called = false,
        run = function(self)
            self.run_called = true
        end
    }
    local task = pipeline.pipe(test_obj)
    task()
    assert(test_obj.run_called == true)
end

function test_stop_pipe()
    local test_obj = {
        pipeline = true,
        pipeline2 = false
    }
    pipeline.stop(test_obj)
    assert(test_obj.pipeline2 == true)
    assert(test_obj.pipeline == nil)
end

function test_resume_pipe()
    local test_obj = {
        pipeline = false,
        pipeline2 = true,
        run = function(self)
            self.pipeline = true
        end
    }
    pipeline.resume(test_obj)
    assert(test_obj.pipeline == true)
end

function test_reset_pipe()
    local test_obj = {
        pipeline_current = 1,
        pipeline = 1,
        pipeline2 = 1,
    }
    pipeline.reset(test_obj)
    assert(test_obj.pipeline_current == nil)
    assert(test_obj.pipeline2 == nil)
    assert(test_obj.pipeline == 1)  
end

function test_run_pipe()
    local test_obj = {
        pipeline_current = nil,
        pipeline = {
            function() end,
            function() end,
            function() end
        }
    }
    pipeline.run(test_obj)
    assert(test_obj.pipeline_current == 4)
end


function test_clear_pipe()
    
    local test_obj = {
        pipeline_current = 1,
        pipeline2 = 1,
        pipeline = 1,
    }
    pipeline.clear(test_obj)
    assert(test_obj.pipeline_current == nil)
    assert(test_obj.pipeline == nil)
    assert(test_obj.pipeline2 == nil)
    
end

test.unit(_G)
