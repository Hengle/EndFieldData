local phaseConfig = require_ex("Phase/PhaseConfig")
PhaseManager = HL.Class("PhaseManager")
PhaseManager.curPhase = HL.Field(HL.Forward("PhaseBase"))
PhaseManager.phaseIds = HL.Field(HL.Table)
PhaseManager.phaseId2Names = HL.Field(HL.Table)
PhaseManager.m_openedPhaseSet = HL.Field(HL.Table)
PhaseManager.m_cfgs = HL.Field(HL.Table)
PhaseManager.m_transCor = HL.Field(HL.Thread)
PhaseManager.m_curState = HL.Field(HL.Number) << 1
PhaseManager.m_phaseStack = HL.Field(HL.Forward("Stack"))
PhaseManager.m_waitingQueue = HL.Field(HL.Forward("Queue"))
PhaseManager.m_waitingDestroyList = HL.Field(HL.Table)
PhaseManager.m_defaultFOV = HL.Field(HL.Number) << -1
PhaseManager.m_cacheTable = HL.Field(HL.Table)
PhaseManager.m_resourceLoader = HL.Field(CS.Beyond.LuaResourceLoader)
PhaseManager.m_cacheRoot = HL.Field(Transform)
PhaseManager.m_isExitingAll = HL.Field(HL.Boolean) << false
PhaseManager.m_effectLodControlBlockers = HL.Field(HL.Table)
PhaseManager.PhaseManager = HL.Constructor() << function(self)
    self.m_curState = Const.PhaseState.Idle
    self.curPhase = nil
    self.m_isExitingAll = false
    self.phaseIds = {}
    self.phaseId2Names = {}
    self.m_openedPhaseSet = {}
    self.m_cfgs = {}
    self.m_waitingDestroyList = {}
    self.m_phaseStack = require_ex("Common/Utils/DataStructure/Stack")()
    self.m_waitingQueue = require_ex("Common/Utils/DataStructure/Queue")()
    self.m_cacheTable = {}
    self.m_effectLodControlBlockers = {}
    self.m_resourceLoader = CS.Beyond.LuaResourceLoader()
    local cacheRoot = GameObject("PhaseCacheRoot")
    GameObject.DontDestroyOnLoad(cacheRoot)
    self.m_cacheRoot = cacheRoot.transform
    Register(MessageConst.OPEN_PHASE_FOR_CS, function(arg)
        local phaseIdName, phaseArgJson = unpack(arg)
        local phaseArg
        if phaseArgJson then
            phaseArg = Utils.stringJsonToTable(phaseArgJson)
        end
        self:OpenPhase(PhaseId[phaseIdName], phaseArg)
    end, self)
    Register(MessageConst.ON_APPLICATION_QUIT, function(arg)
        self:_Dispose()
    end, self)
    Register(MessageConst.ON_DISPOSE_LUA_ENV, function(arg)
        self:_Dispose()
    end, self)
    Register(MessageConst.ON_DO_CLOSE_MAP, function(arg)
        self:ExitAllPhase()
        UIManager:_CloseAllUI(true)
    end, self)
end
PhaseManager.InitPhaseConfigs = HL.Method() << function(self)
    self:_InitConfig()
    self:_InitBackMsgs()
    self.m_defaultFOV = UIManager:GetUICameraFOV()
end
PhaseManager._InitConfig = HL.Method() << function(self)
    local nextId = 1
    for name, data in pairs(phaseConfig.config) do
        local id = nextId
        nextId = nextId + 1
        local filePath
        if data.isSimpleUIPhase then
            filePath = 'Phase/Core/PhaseBase'
        else
            filePath = string.format(PhaseConst.PHASE_FILE_PATH, name, name)
        end
        local check = require_check(filePath)
        if check then
            local cfg = { name = name, id = id, data = data }
            data.name = name
            setmetatable(cfg, { __index = data })
            self.m_cfgs[id] = cfg
            self.phaseIds[name] = id
            self.phaseId2Names[id] = name
        else
            logger.error("No Phase class but in PhaseConst: " .. name)
        end
    end
end
PhaseManager._InitBackMsgs = HL.Method() << function(self)
    for _, cfg in pairs(self.m_cfgs) do
        if not cfg.isSimpleUIPhase then
            local name = cfg.name
            local phase = require_ex(string.format(PhaseConst.PHASE_FILE_PATH, name, name))["Phase" .. name]
            local messages = phase.s_messages or {}
            for msg, infos in pairs(messages) do
                local funcName, isForeground = unpack(infos)
                if not isForeground and funcName and not MessageConst.isPhaseMsg(msg) then
                    Register(msg, function(msgArg)
                        if msgArg == nil then
                            phase[funcName]()
                        else
                            phase[funcName](msgArg)
                        end
                    end, self)
                end
            end
        end
    end
end
PhaseManager.GoToPhase = HL.Method(HL.Number, HL.Opt(HL.Any)) << function(self, phaseId, arg)
    if self.m_isExitingAll then
        logger.info("Phase isExitingAll, GotoPhase Fail", phaseId, self:GetPhaseName(phaseId))
        return
    end
    if self:GetTopPhaseId() == phaseId then
        self:ForceRefreshPhase(phaseId, arg)
    elseif self:IsOpen(phaseId) then
        self:ExitPhaseFastTo(phaseId)
        self:ForceRefreshPhase(phaseId, arg)
    else
        self:OpenPhase(phaseId, arg)
    end
end
PhaseManager.OpenPhase = HL.Method(HL.Number, HL.Opt(HL.Any, HL.Function, HL.Boolean)).Return(HL.Boolean) << function(self, phaseId, arg, callback, couldWait)
    if self.m_isExitingAll then
        logger.info("Phase isExitingAll, OpenPhase Fail", phaseId, self:GetPhaseName(phaseId))
        return
    end
    if not self:CheckCanOpenPhaseAndToast(phaseId, arg) then
        return false
    end
    if not couldWait and self.m_transCor then
        if UNITY_EDITOR then
            logger.error("正在进行其他Phase操作，如需等待操作完成后进行，couldWait需为true", phaseId, self:GetPhaseName(phaseId), arg)
        else
            logger.warn("正在进行其他Phase操作，如需等待操作完成后进行，couldWait需为true", phaseId, self:GetPhaseName(phaseId), arg)
        end
        return false
    end
    self.m_waitingQueue:Push({ phaseId, arg, false, callback })
    self:_TryOpenPhase()
    return true
end
PhaseManager.OpenPhaseFast = HL.Method(HL.Number, HL.Opt(HL.Any)).Return(HL.Boolean) << function(self, phaseId, arg)
    if self.m_isExitingAll then
        logger.info("Phase isExitingAll, OpenPhaseFast Fail", phaseId, self:GetPhaseName(phaseId))
        return
    end
    if not self:CheckCanOpenPhaseAndToast(phaseId, arg) then
        return false
    end
    self.m_waitingQueue:Push({ phaseId, arg, true, nil })
    self:_TryOpenPhase()
    return true
end
PhaseManager.PopPhase = HL.Method(HL.Number, HL.Opt(HL.Function)) << function(self, phaseId, callback)
    if not self:CanPopPhase(phaseId) then
        return
    end
    self:_DoPopPhase(callback)
end
PhaseManager.CanPopPhase = HL.Method(HL.Number).Return(HL.Boolean) << function(self, phaseId)
    if self.m_isExitingAll then
        logger.info("Phase isExitingAll, PopPhase Fail", phaseId, self:GetPhaseName(phaseId))
        return false
    end
    local top = self.m_phaseStack:Peek()
    if not top or top.phaseId ~= phaseId then
        logger.error("PopPhase Error, No Top or PhaseId Mismatch", phaseId, top and top.phaseId, self.phaseId2Names[phaseId], top and self.phaseId2Names[top.phaseId])
        return false
    end
    if self.m_curState == Const.PhaseState.Pop then
        if UNITY_EDITOR then
            logger.error("正在退出 Phase，不能再次调用退出 Phase", phaseId, self.phaseId2Names[phaseId])
        else
            logger.warn("正在退出 Phase，不能再次调用退出 Phase", phaseId, self.phaseId2Names[phaseId])
        end
        return false
    elseif self.m_curState == Const.PhaseState.Push then
        if UNITY_EDITOR then
            logger.error("正在进入 Phase，不能调用退出 Phase", phaseId, self.phaseId2Names[phaseId])
        else
            logger.warn("正在进入 Phase，不能调用退出 Phase", phaseId, self.phaseId2Names[phaseId])
        end
        return false
    end
    return true
end
PhaseManager.ExitPhaseFast = HL.Method(HL.Number) << function(self, phaseId)
    if self.m_isExitingAll then
        logger.info("Phase isExitingAll, ExitPhaseFast Fail", phaseId, self:GetPhaseName(phaseId))
        return
    end
    if self.m_phaseStack:Empty() then
        logger.error("Phase Stack Is Empty", phaseId, self.phaseId2Names[phaseId])
        return
    end
    local phase = self.m_openedPhaseSet[phaseId]
    if phase then
        self.m_curState = Const.PhaseState.Pop
        local isExitTopPhase = phase == self.m_phaseStack:Peek()
        self.m_openedPhaseSet[phaseId] = nil
        self:_DoFinishPhase(phase, true)
        if isExitTopPhase then
            local newPhase = self.m_phaseStack:Peek()
            self.curPhase = newPhase
            self:_DoPopTransition(nil, newPhase, true)
        end
        self.m_curState = Const.PhaseState.Idle
    else
        logger.error("Phase Not Found", phaseId, self.phaseId2Names[phaseId])
    end
end
PhaseManager.ExitPhaseFastTo = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, targetPhaseId, forceExit)
    if self.m_isExitingAll then
        logger.info("Phase isExitingAll, ExitPhaseFastTo Fail", phaseId, self:GetPhaseName(phaseId))
        return
    end
    if self.m_phaseStack:Empty() then
        logger.error("Phase Stack Is Empty", phaseId, self.phaseId2Names[phaseId])
        return
    end
    if self.m_transCor and not forceExit then
        logger.error("PhaseManager.ExitPhaseFast self.m_transCor not nil", phaseId, self.phaseId2Names[phaseId])
        return
    end
    self.m_curState = Const.PhaseState.Pop
    local isTop = true
    for _ = self.m_phaseStack:Count(), 1, -1 do
        local phase = self.m_phaseStack:Peek()
        self.curPhase = phase
        local phaseId = phase.phaseId
        if phaseId == targetPhaseId then
            if not isTop then
                self:_DoPopTransition(nil, phase, true)
            end
            self.m_curState = Const.PhaseState.Idle
            return
        end
        self.m_openedPhaseSet[phaseId] = nil
        self:_DoFinishPhase(phase, true)
        isTop = false
    end
    logger.error("ExitPhaseFastTo: No Target Phase", targetPhaseId)
    self.curPhase = nil
    self.m_curState = Const.PhaseState.Idle
end
PhaseManager.IsPhaseRepeated = HL.Method(HL.Number).Return(HL.Boolean) << function(self, phaseId)
    if self:IsInWaitingQueue(phaseId) then
        return true
    end
    local isOpen, phase = self:IsOpen(phaseId)
    if isOpen and phase ~= nil then
        local peekPhase = self.m_phaseStack:Peek()
        local isPeek = phase == peekPhase
        return isPeek and phase.state ~= PhaseConst.EPhaseState.TransitionOut and phase.state ~= PhaseConst.EPhaseState.WaitRelease
    end
    return false
end
PhaseManager.ForceRefreshPhase = HL.Method(HL.Number, HL.Any) << function(self, phaseId, arg)
    if phaseId == nil then
        return
    end
    local phase = self.m_openedPhaseSet[phaseId]
    if phase == nil then
        return
    end
    phase:Refresh(arg)
end
PhaseManager.GetTopPhaseId = HL.Method().Return(HL.Opt(HL.Number)) << function(self)
    local topPhase = self.m_phaseStack:Peek()
    if not topPhase then
        return
    end
    return topPhase.phaseId
end
PhaseManager.GetTopOpenAndValidPhaseId = HL.Method().Return(HL.Opt(HL.Number)) << function(self)
    local stack = self.m_phaseStack
    for i = stack.m_topIndex, stack.m_bottomIndex, -1 do
        local topPhase = stack:Get(i)
        local isValid = self:IsOpenAndValid(topPhase.phaseId)
        if isValid then
            return topPhase.phaseId
        end
    end
end
PhaseManager.SendMessageToOpenedPhase = HL.Method(HL.Number, HL.Number, HL.Opt(HL.Table)) << function(self, phaseId, msgId, arg)
    local phase = self.m_openedPhaseSet[phaseId]
    if phase == nil then
        return
    end
    phase.messageMgr:Send(msgId, arg)
end
PhaseManager.TryCacheGOByName = HL.Method(HL.Number, HL.String, HL.Opt(HL.Function)) << function(self, phaseId, name, callback)
    if not self.m_cfgs[phaseId] then
        logger.error("PhaseManager.TryCacheGOByName Error: wrong phaseId ", phaseId, self.phaseId2Names[phaseId])
        return
    end
    local key = phaseId .. name
    if not self.m_cacheTable[key] then
        local phaseName = self.m_cfgs[phaseId].name
        local path = string.format(PhaseConst.PHASE_GAME_OBJECT_FILE_PATH, phaseName, name)
        self.m_resourceLoader:LoadGameObjectAsync(path, function(goAsset)
            if goAsset then
                local goObj = CSUtils.CreateObject(goAsset)
                self.m_cacheTable[key] = goObj
                goObj.transform:SetParent(self.m_cacheRoot)
                goObj:SetActive(false)
                if callback then
                    callback(goObj)
                end
            end
        end)
    elseif callback then
        if callback then
            callback(self.m_cacheTable[key])
        end
    end
end
PhaseManager.TryCacheGo = HL.Method(HL.Number, HL.String, CS.UnityEngine.GameObject) << function(self, phaseId, name, go)
    local key = phaseId .. name
    if self.m_cacheTable[key] or not go then
        logger.error("PhaseManager TryCacheGo error: already cached, " .. name)
    else
        self.m_cacheTable[key] = go
        self.m_cacheTable[key]:SetActive(false)
    end
end
PhaseManager.GetCachedGameObject = HL.Method(HL.Number, HL.String).Return(CS.UnityEngine.GameObject) << function(self, phaseId, name)
    local key = phaseId .. name
    local res
    if self.m_cacheTable[key] then
        res = self.m_cacheTable[key]
        self.m_cacheTable[key] = nil
    end
    return res
end
PhaseManager.ReleaseCache = HL.Method(HL.Number, HL.String) << function(self, phaseId, name)
    local key = phaseId .. name
    local obj = self.m_cacheTable[key]
    if obj then
        CSUtils.ClearUIComponents(obj)
        GameObject.Destroy(obj)
        self.m_cacheTable[key] = nil
    end
end
PhaseManager.ReleaseAllCache = HL.Method() << function(self)
    for k, obj in pairs(self.m_cacheTable) do
        CSUtils.ClearUIComponents(obj)
        GameObject.Destroy(obj)
    end
    self.m_cacheTable = {}
end
PhaseManager.IsOpen = HL.Method(HL.Number).Return(HL.Boolean, HL.Opt(HL.Forward("PhaseBase"))) << function(self, phaseId)
    local phase = self.m_openedPhaseSet[phaseId]
    return phase ~= nil, phase
end
PhaseManager.IsOpenAndValid = HL.Method(HL.Number).Return(HL.Boolean, HL.Opt(HL.Forward("PhaseBase"))) << function(self, phaseId)
    local phase = self.m_openedPhaseSet[phaseId]
    if phase and not self.m_waitingDestroyList[phase] then
        return true, phase
    end
    return false
end
PhaseManager.IsEmptyPhase = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_phaseStack:Empty()
end
PhaseManager.IsInWaitingQueue = HL.Method(HL.Number).Return(HL.Boolean) << function(self, phaseId)
    local queue = self.m_waitingQueue
    if not queue:Empty() then
        for k = 1, queue:Count() do
            local item = queue:AtIndex(k)
            local id = unpack(item)
            if id == phaseId then
                return true
            end
        end
    end
    return false
end
PhaseManager.IsPhaseUnlocked = HL.Method(HL.Number).Return(HL.Boolean) << function(self, phaseId)
    local cfg = self.m_cfgs[phaseId]
    if cfg.isUnlocked then
        return cfg.isUnlocked()
    end
    if cfg.unlockSystemType and cfg.unlockSystemType ~= GEnums.UnlockSystemType.None then
        return Utils.isSystemUnlocked(cfg.unlockSystemType)
    end
    if not string.isEmpty(cfg.systemId) then
        return Utils.isGameSystemUnlocked(cfg.systemId)
    end
    return true
end
PhaseManager.IsPhaseForbidden = HL.Method(HL.Number).Return(HL.Boolean) << function(self, phaseId)
    local cfg = self.m_cfgs[phaseId]
    return GameInstance.player.forbidSystem:IsPhaseForbidden(cfg.name)
end
PhaseManager.GetPhaseRedDotName = HL.Method(HL.Number).Return(HL.String) << function(self, phaseId)
    local cfg = self.m_cfgs[phaseId]
    local invalidName = ""
    if cfg == nil then
        return invalidName
    end
    if not string.isEmpty(cfg.redDotName) then
        return cfg.redDotName
    end
    if not cfg.systemId then
        return invalidName
    end
    local success, systemConfigData = Tables.gameSystemConfigTable:TryGetValue(cfg.systemId)
    if not success then
        return invalidName
    end
    return systemConfigData.redDotName
end
PhaseManager.GetPhaseSystemViewConfig = HL.Method(HL.Number).Return(HL.Table) << function(self, phaseId)
    local cfg = self.m_cfgs[phaseId]
    if cfg == nil then
        return nil
    end
    local success, systemConfigData = Tables.gameSystemConfigTable:TryGetValue(cfg.systemId)
    if not success then
        return nil
    end
    return { ["systemName"] = systemConfigData.systemName, ["systemIcon"] = systemConfigData.systemIcon, ["systemDesc"] = systemConfigData.systemDesc, }
end
PhaseManager.CheckCanOpenPhaseAndToast = HL.Method(HL.Number, HL.Opt(HL.Any)).Return(HL.Boolean) << function(self, phaseId, arg)
    local rst, toast, errorInfo = self:CheckCanOpenPhase(phaseId, arg, true)
    if rst then
        return true
    end
    if toast then
        Notify(MessageConst.SHOW_TOAST, toast)
    end
    if errorInfo then
        logger.error("CheckCanOpenPhase errorInfo: " .. errorInfo)
    end
    return false
end
PhaseManager.CheckIsInTransition = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_transCor ~= nil
end
PhaseManager.CheckCanOpenPhase = HL.Method(HL.Number, HL.Opt(HL.Any, HL.Boolean)).Return(HL.Boolean, HL.Opt(HL.String, HL.String)) << function(self, phaseId, arg, considerIsOpen)
    if not self:IsPhaseUnlocked(phaseId) then
        return false, Language.LUA_SYSTEM_LOCK
    end
    if self:IsPhaseForbidden(phaseId) then
        return false, Language.LUA_SYSTEM_FORBIDDEN
    end
    local cfg = self.m_cfgs[phaseId]
    if cfg.checkCanOpen then
        local rst, toast = cfg.checkCanOpen(arg)
        if not rst then
            return false, toast
        end
    end
    local rst = true
    local errorInfo = ""
    if self.m_cfgs[phaseId] == nil then
        errorInfo = "PhaseManager OpenPhase error, not in config, phase: " .. phaseId .. " " .. tostring(self.phaseId2Names[phaseId])
        rst = false
    end
    if considerIsOpen then
        if self:IsOpen(phaseId) then
            local phase = self.m_openedPhaseSet[phaseId]
            if phase and (phase.state == PhaseConst.EPhaseState.TransitionOut or phase.state == PhaseConst.EPhaseState.WaitRelease) then
                rst = true
            else
                errorInfo = "PhaseManager already opened phase: " .. phaseId .. " " .. tostring(self.phaseId2Names[phaseId])
                rst = false
            end
        elseif self:IsInWaitingQueue(phaseId) then
            errorInfo = "PhaseManager OpenPhase error, IsInWaitingQueue, phase: " .. phaseId .. " " .. tostring(self.phaseId2Names[phaseId])
            rst = false
        end
    end
    return rst, nil, errorInfo
end
PhaseManager._TryOpenPhase = HL.Method() << function(self)
    if self.m_transCor or self.m_waitingQueue:Empty() then
        return
    end
    self.m_curState = Const.PhaseState.Push
    local infos = self.m_waitingQueue:Pop()
    local phaseId = infos[1]
    local arg = infos[2]
    local fastMode = infos[3]
    local callback = infos[4]
    local newPhase = self:_CreatePhase(phaseId, arg)
    self.m_openedPhaseSet[phaseId] = newPhase
    self.m_phaseStack:Push(newPhase)
    Notify(MessageConst.UPDATE_DEBUG_PHASE_TEXT)
    Notify(MessageConst.ON_UI_PHASE_OPENED, newPhase.cfg.name)
    local oldPhase = self.curPhase
    self.curPhase = newPhase
    if fastMode then
        self:_DoPushTransition(oldPhase, newPhase, true)
        self.m_curState = Const.PhaseState.Idle
        if callback then
            callback()
        end
        self:_TryOpenPhase()
    else
        self.m_transCor = self:_StartCoroutine(function()
            self:_DoPushTransition(oldPhase, newPhase, false)
            self.m_curState = Const.PhaseState.Idle
            if callback then
                callback()
            end
            self:_TryOpenPhase()
        end)
    end
end
PhaseManager._DoFinishPhase = HL.Method(HL.Forward("PhaseBase"), HL.Boolean) << function(self, phase, fastMode)
    Notify(MessageConst.ON_UI_PHASE_EXITED, phase.cfg.name)
    phase:TransitionOut(fastMode)
    self:_ReleasePhase(phase)
    Notify(MessageConst.UPDATE_DEBUG_PHASE_TEXT)
end
PhaseManager._DoPopPhase = HL.Method(HL.Opt(HL.Function)) << function(self, callback)
    self:_ClearTransCor()
    self.m_curState = Const.PhaseState.Pop
    local oldPhase = self.m_phaseStack:Pop()
    if oldPhase then
        self.m_waitingDestroyList[oldPhase] = true
    end
    Notify(MessageConst.UPDATE_DEBUG_PHASE_TEXT)
    Notify(MessageConst.ON_UI_PHASE_EXITED, oldPhase.cfg.name)
    local newTopPhase = self.m_phaseStack:Peek()
    self.curPhase = newTopPhase
    self.m_transCor = self:_StartCoroutine(function()
        self:_DoPopTransition(oldPhase, newTopPhase, false)
        self.m_curState = Const.PhaseState.Idle
        if callback then
            callback()
        end
        self:_TryOpenPhase()
    end)
end
PhaseManager._ClearTransCor = HL.Method() << function(self)
    if self.m_transCor ~= nil then
        self:_ClearCoroutine(self.m_transCor)
        self.m_transCor = nil
    end
end
PhaseManager._CreatePhase = HL.Method(HL.Number, HL.Opt(HL.Any)).Return(HL.Forward("PhaseBase")) << function(self, phaseId, arg)
    local cfg = self.m_cfgs[phaseId]
    local name = cfg.name
    local phase
    if not cfg.isSimpleUIPhase then
        phase = require_ex(string.format(PhaseConst.PHASE_FILE_PATH, name, name))["Phase" .. name](arg)
    else
        phase = require_ex('Phase/Core/PhaseBase').PhaseBase(arg)
    end
    phase.phaseId = phaseId
    local messages = cfg.isSimpleUIPhase and {} or HL.GetType(phase).s_messages
    for msg, infos in pairs(messages) do
        local funcName, isForeground = unpack(infos)
        if MessageConst.isPhaseMsg(msg) then
            if isForeground ~= nil then
                logger.error("Phase msg always is isForeground! So here can`t use True/False:" .. funcName)
            end
            phase.messageMgr:Register(msg, function(msgArg)
                if msgArg == nil then
                    phase[funcName](phase)
                else
                    phase[funcName](phase, msgArg)
                end
            end)
        elseif isForeground then
            Register(msg, function(msgArg)
                if msgArg == nil then
                    phase[funcName](phase)
                else
                    phase[funcName](phase, msgArg)
                end
            end, phase)
        end
    end
    phase:InitWithCfg(cfg.data)
    return phase
end
PhaseManager._ReleasePhase = HL.Method(HL.Forward("PhaseBase")) << function(self, phase)
    local cfg = self.m_cfgs[phase.phaseId]
    phase:Destroy()
    if cfg.disableEffectLodControl then
        self:ResumeEffectLodByPhase(phase.phaseId)
    end
    self.m_waitingDestroyList[phase] = nil
    MessageManager:UnregisterAll(phase)
    if self.m_phaseStack:Contains(phase) then
        self.m_phaseStack:Delete(phase)
    end
    self.m_openedPhaseSet[phase.phaseId] = nil
end
PhaseManager._RefreshUIScaler = HL.Method() << function(self)
    local comp = UIManager.worldUICanvas:GetComponent("UICanvasScaleHelper")
    if comp then
        comp:TryUpdateCanvasFitMode()
    end
end
PhaseManager._StartCoroutine = HL.Method(HL.Function).Return(HL.Thread) << function(self, func)
    return CoroutineManager:StartCoroutine(func, self)
end
PhaseManager._ClearCoroutine = HL.Method(HL.Thread) << function(self, coroutine)
    CoroutineManager:ClearCoroutine(coroutine)
end
PhaseManager._Dispose = HL.Method() << function(self)
    for _, phase in pairs(self.m_openedPhaseSet) do
        phase:Destroy()
    end
    self.m_openedPhaseSet = {}
    self.m_phaseStack:Clear()
    self.m_waitingQueue:Clear()
    self:_ClearTransCor()
    self:ReleaseAllCache()
    if self.m_cacheRoot then
        GameObject.DestroyImmediate(self.m_cacheRoot.gameObject)
        self.m_cacheRoot = nil
    end
    UIManager:Dispose()
    if self.m_resourceLoader ~= nil then
        self.m_resourceLoader:DisposeAllHandles()
    end
end
PhaseManager.ExitAllPhase = HL.Method() << function(self)
    logger.info("ExitAllPhase")
    self.m_isExitingAll = true
    self:_ClearTransCor()
    local count = self.m_phaseStack:Count()
    for _ = 1, count do
        local phase = self.m_phaseStack:Pop()
        self:_DoFinishPhase(phase, true)
    end
    for phase, active in pairs(self.m_waitingDestroyList) do
        if active then
            self:_DoFinishPhase(phase, true)
        end
    end
    self.curPhase = nil
    self.m_waitingDestroyList = {}
    self.m_openedPhaseSet = {}
    self.m_phaseStack:Clear()
    self.m_waitingQueue:Clear()
    self.m_isExitingAll = false
end
PhaseManager._DoPopTransition = HL.Method(HL.Forward("PhaseBase"), HL.Forward("PhaseBase"), HL.Boolean) << function(self, popPhase, newTopPhase, fastMode)
    logger.info("PhaseManager._DoPopTransition", popPhase and popPhase.cfg.name, newTopPhase and newTopPhase.cfg.name, fastMode)
    local newTopPhaseId = newTopPhase and newTopPhase.phaseId or nil
    local popPhaseId = popPhase and popPhase.phaseId or nil
    if popPhase then
        popPhase:PrepareTransition(PhaseConst.EPhaseState.TransitionOut, fastMode, newTopPhaseId)
    end
    if newTopPhase then
        newTopPhase:PrepareTransition(PhaseConst.EPhaseState.TransitionBackToTop, fastMode, popPhaseId)
    end
    if popPhase then
        popPhase:TransitionOut(fastMode, { anotherPhaseId = newTopPhaseId })
        if not fastMode then
            coroutine.waitCondition(function()
                return popPhase.state ~= PhaseConst.EPhaseState.TransitionOut
            end)
        end
        self:_ReleasePhase(popPhase)
    end
    if newTopPhase then
        local cfg = newTopPhase.cfg
        local fov = cfg.fov
        if fov and fov > 0 then
            UIManager:SetUICameraFOV(fov)
        else
            local topIndex = self.m_phaseStack:TopIndex()
            local bottomIndex = self.m_phaseStack:BottomIndex()
            local hasFov = false
            for i = topIndex, bottomIndex, -1 do
                local oldCfg = self.m_phaseStack:Get(i).cfg
                local oldFov = oldCfg.fov
                if oldFov and oldFov > 0 then
                    UIManager:SetUICameraFOV(oldFov)
                    hasFov = true
                    break
                end
            end
            if not hasFov then
                logger.error("[PhaseManager._DoPopTransition] 当前Phase栈里没有Phase配置FOV！")
            end
        end
        newTopPhase:TransitionBackToTop(fastMode, { anotherPhaseId = popPhaseId })
        if not fastMode then
            coroutine.waitCondition(function()
                return newTopPhase.state ~= PhaseConst.EPhaseState.TransitionBackToTop
            end)
        end
    end
    if not fastMode then
        self.m_transCor = nil
    end
end
PhaseManager._DoPushTransition = HL.Method(HL.Forward("PhaseBase"), HL.Forward("PhaseBase"), HL.Boolean) << function(self, oldTopPhase, pushPhase, fastMode)
    logger.info("PhaseManager._DoPushTransition", oldTopPhase and oldTopPhase.cfg.name, pushPhase and pushPhase.cfg.name, fastMode)
    local oldTopPhaseId = oldTopPhase and oldTopPhase.phaseId or nil
    local pushPhaseId = pushPhase and pushPhase.phaseId or nil
    if oldTopPhase then
        oldTopPhase:PrepareTransition(PhaseConst.EPhaseState.TransitionBehind, fastMode, pushPhaseId)
    end
    if pushPhase then
        pushPhase:PrepareTransition(PhaseConst.EPhaseState.TransitionIn, fastMode, oldTopPhaseId)
        if not fastMode and pushPhase.cfg.panels then
            for _, panelId in ipairs(pushPhase.cfg.panels) do
                UIManager:PreloadPanelAsset(panelId)
            end
        end
    end
    if oldTopPhase then
        oldTopPhase:TransitionBehind(fastMode, { anotherPhaseId = pushPhaseId })
        if not fastMode then
            coroutine.waitCondition(function()
                return oldTopPhase.state ~= PhaseConst.EPhaseState.TransitionBehind
            end)
        end
    end
    if pushPhase then
        local cfg = pushPhase.cfg
        local fov = cfg.fov
        if fov and fov > 0 then
            UIManager:SetUICameraFOV(fov)
        end
        self:_RefreshUIScaler()
        if cfg.disableEffectLodControl then
            self:DisableEffectLodByPhase(pushPhaseId)
        end
        pushPhase:TransitionIn(fastMode, { anotherPhaseId = oldTopPhaseId })
        if not fastMode then
            coroutine.waitCondition(function()
                return pushPhase.state ~= PhaseConst.EPhaseState.TransitionIn
            end)
        end
    end
    if not fastMode then
        self.m_transCor = nil
    end
end
PhaseManager.DisableEffectLodByPhase = HL.Method(HL.Number) << function(self, phaseId)
    if next(self.m_effectLodControlBlockers) == nil then
        GameInstance.effectManager:SetIsCheckDistanceLod(false)
    end
    self.m_effectLodControlBlockers[phaseId] = true
end
PhaseManager.ResumeEffectLodByPhase = HL.Method(HL.Number) << function(self, phaseId)
    self.m_effectLodControlBlockers[phaseId] = nil
    if next(self.m_effectLodControlBlockers) == nil then
        GameInstance.effectManager:SetIsCheckDistanceLod(true)
    end
end
PhaseManager.GetPhaseStack = HL.Method().Return(HL.Forward("Stack")) << function(self)
    return self.m_phaseStack
end
PhaseManager.GetPhaseCfgs = HL.Method().Return(HL.Table) << function(self)
    return self.m_cfgs
end
PhaseManager.GetPhaseName = HL.Method(HL.Number).Return(HL.String) << function(self, phaseId)
    local cfg = self.m_cfgs[phaseId]
    return cfg and cfg.name or ""
end
HL.Commit(PhaseManager)
return PhaseManager