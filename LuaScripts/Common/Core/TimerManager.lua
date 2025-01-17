local minHeapClass = require_ex("Common/Utils/DataStructure/MinHeap")
TimerManager = HL.Class('TimerManager')
TimerManager.m_heap = HL.Field(HL.Forward("MinHeap"))
TimerManager.m_unscaledHeap = HL.Field(HL.Forward("MinHeap"))
TimerManager.m_frameHeap = HL.Field(HL.Forward("MinHeap"))
TimerManager.m_removedTimerKeys = HL.Field(HL.Table)
TimerManager.m_groupTimerKeys = HL.Field(HL.Table)
TimerManager.m_nextTimerKey = HL.Field(HL.Number) << 1
TimerManager.m_frameCount = HL.Field(HL.Number) << 0
TimerManager.m_requestCache = HL.Field(HL.Forward("Stack"))
TimerManager.TimerManager = HL.Constructor() << function(self)
    self.m_heap = minHeapClass()
    self.m_unscaledHeap = minHeapClass()
    self.m_frameHeap = minHeapClass()
    self.m_requestCache = require_ex("Common/Utils/DataStructure/Stack")()
    self.m_removedTimerKeys = {}
    self.m_groupTimerKeys = setmetatable({}, { __mode = "k" })
    self.m_nextTimerKey = 1
    self.m_frameCount = 0
    LuaUpdate:Add("Tick", function(deltaTime)
        self:Tick(deltaTime)
    end)
end
TimerManager.Tick = HL.Method(HL.Number) << function(self, deltaTime)
    self.m_frameCount = self.m_frameCount + 1
    self:_UpdateTimers(self.m_heap, Time.time)
    self:_UpdateTimers(self.m_unscaledHeap, Time.unscaledTime)
    self:_UpdateTimers(self.m_frameHeap, self.m_frameCount)
end
TimerManager._UpdateTimers = HL.Method(HL.Forward("MinHeap"), HL.Number) << function(self, heap, time)
    while heap:Size() > 0 do
        local request, triggerTime = heap:Min()
        if self.m_removedTimerKeys[request.key] then
            self.m_removedTimerKeys[request.key] = nil
            heap:Pop()
            self:_CacheRequest(request)
        else
            if time >= triggerTime then
                heap:Pop()
                local succ, log = xpcall(request.action, debug.traceback)
                if not succ then
                    logger.error("Timer Action Fail\n", log)
                end
                self:_CacheRequest(request)
            else
                break
            end
        end
    end
end
TimerManager.StartFrameTimer = HL.Method(HL.Number, HL.Function, HL.Opt(HL.Any)).Return(HL.Number) << function(self, frameNum, action, groupKey)
    local triggerTime = self.m_frameCount + frameNum
    local heap = self.m_frameHeap
    return self:_StartTimer(heap, triggerTime, action, groupKey)
end
TimerManager.StartTimer = HL.Method(HL.Number, HL.Function, HL.Opt(HL.Boolean, HL.Any)).Return(HL.Number) << function(self, time, action, unscaled, groupKey)
    local triggerTime = (unscaled and Time.unscaledTime or Time.time) + time
    local heap = unscaled and self.m_unscaledHeap or self.m_heap
    return self:_StartTimer(heap, triggerTime, action, groupKey)
end
TimerManager.GetTimerTriggerTime = HL.Method(HL.Number).Return(HL.Number) << function(self, timerId)
    for key, _ in self.m_heap:NodeIter() do
        local request = key.key
        if request.key == timerId then
            return request.triggerTime
        end
    end
    for key, _ in self.m_unscaledHeap:NodeIter() do
        local request = key.key
        if request.key == timerId then
            return request.triggerTime
        end
    end
    return -1
end
TimerManager._StartTimer = HL.Method(HL.Forward("MinHeap"), HL.Number, HL.Function, HL.Opt(HL.Any)).Return(HL.Number) << function(self, heap, triggerTime, action, groupKey)
    local key = self.m_nextTimerKey
    self.m_nextTimerKey = self.m_nextTimerKey + 1
    local request = self:_GetRequest()
    request.key = key
    request.action = action
    request.triggerTime = triggerTime
    request.groupKey = groupKey
    heap:Add(request, triggerTime)
    if groupKey ~= nil then
        local keys = self.m_groupTimerKeys[groupKey]
        if not keys then
            keys = {}
            self.m_groupTimerKeys[groupKey] = keys
        end
        table.insert(keys, key)
    end
    return key
end
TimerManager.ClearTimer = HL.Method(HL.Number) << function(self, key)
    if key then
        self.m_removedTimerKeys[key] = true
    end
end
TimerManager.ClearAllTimer = HL.Method(HL.Any) << function(self, groupKey)
    local keys = self.m_groupTimerKeys[groupKey]
    if keys then
        for _, k in pairs(keys) do
            self:ClearTimer(k)
        end
        self.m_groupTimerKeys[groupKey] = nil
    end
end
TimerManager._GetRequest = HL.Method().Return(HL.Table) << function(self)
    if self.m_requestCache:Empty() then
        return {}
    else
        return self.m_requestCache:Pop()
    end
end
TimerManager._CacheRequest = HL.Method(HL.Table) << function(self, request)
    request.action = nil
    request.groupKey = nil
    self.m_requestCache:Push(request)
end
HL.Commit(TimerManager)
return TimerManager