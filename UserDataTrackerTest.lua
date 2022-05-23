

local tracker = require 'UserDataTracker'
local mri = require 'MemoryReferenceInfo'

local container = tracker.CreateObjectReferenceInfoContainer()
tracker.CollectObjectReferenceInMemory('tracker', tracker, container)
tracker.DumpContainer(container)

print('------------------')

tracker.config.searchFunction=true
tracker.config.searchThread=true

-- local container = tracker.CreateObjectReferenceInfoContainer()
-- tracker.CollectObjectReferenceInMemory('mri', nil, container)
-- tracker.DumpContainer(container)

tracker.DumpMemorySnapshot('./', 'trackerTest', -1, 'mri', nil)
