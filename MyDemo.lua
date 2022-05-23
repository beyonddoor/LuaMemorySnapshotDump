
-- local _G = _G

local collectgarbage = collectgarbage
local mri = require("MemoryReferenceInfo")
require('TestModule')
local TestModule = TestModule

module('MyDemo', ...)

local function test()
    print("test")
end

-- setmetatable(test, {__call = function(self, ...)
--     print("call")
--     return self(...)
-- end})

-- test()


-- local memoryTool = require 'MemoryReferenceInfo'
-- print(memoryTool.m_cHelpers.FormatDateTimeNow())

TestModule.Show()

-- TestModule._Do()


collectgarbage("collect")
mri.m_cMethods.DumpMemorySnapshot("./", "TestModule", -1, 'TestModule', TestModule)
mri.m_cMethods.DumpMemorySnapshotSingleObject("./", "TestModule", -1, 'TestModule', TestModule)
mri.m_cBases.OutputFilteredResult('./LuaMemRefInfo-All-[20220522-223745]-[TestModule].txt', '\\[function:environment\\]', false, './filter.txt')