local bases = {'source', 'samples'}
local found_error = false

for _, base in ipairs(bases) do
    for file in io.popen('find '..base..'/ -name "*.lua"'):lines() do
        local f = io.open(file, "r")
        local line_num = 0
        for line in f:lines() do
            line_num = line_num + 1
            if line:match("[^\x00-\x7F]") then
                print("Non-ASCII characters found in: " .. file .. " at line " .. line_num)
                found_error = true
            end
        end
        f:close()
    end
end

if found_error then
    error("Non-ASCII characters detected. Please fix them.", 0)
end
