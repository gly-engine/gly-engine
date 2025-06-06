local bases = {'source'}
local found_error = false

for _, base in ipairs(bases) do
    for file in io.popen('find '..base..'/ -name "*.lua"'):lines() do
        local f = io.open(file, "r")
        local line_num = 0
        for line in f:lines() do
            line_num = line_num + 1
            if line:match("^[^%d]*%d+%.%d+[^%d]*$") and not line:match("%d+%.%d+%.") and not line:match("--!.*%d+%.%d+")  then
                print("Float number found in: " .. file .. " at line " .. line_num)
                found_error = true
            end
        end
        f:close()
    end
end

if found_error then
    error("Non-Integer numbers detected. Please fix them.", 0)
end
