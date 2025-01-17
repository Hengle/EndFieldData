local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
PRTSRadio = HL.Class('PRTSRadio', UIWidgetBase)
PRTSRadio.m_genGotoBtnCells = HL.Field(HL.Forward("UIListCache"))
PRTSRadio.m_gotoBtnCallback = HL.Field(HL.Function)
PRTSRadio.m_getRadioTextCellFunc = HL.Field(HL.Function)
PRTSRadio.m_gotoBtnNameList = HL.Field(HL.Table)
PRTSRadio.m_radioBasicInfos = HL.Field(HL.Table)
PRTSRadio.m_radioPlayInfos = HL.Field(HL.Table)
PRTSRadio._OnFirstTimeInit = HL.Override() << function(self)
    self.m_genGotoBtnCells = UIUtils.genCellCache(self.view.gotoBtnCell)
    self.m_getRadioTextCellFunc = UIUtils.genCachedCellFunction(self.view.radioTextList)
    self.view.radioTextList.onUpdateCell:AddListener(function(obj, csIndex)
        local cell = self.m_getRadioTextCellFunc(obj)
        self:_OnRefreshRadioTextCell(cell, LuaIndex(csIndex))
    end)
    self.view.radioTextList.onDrag:AddListener(function(_)
        self:_OnManualDragRadioTextList()
    end)
end
PRTSRadio.InitPRTSRadio = HL.Method(HL.String, HL.String) << function(self, radioId, title)
    self:_FirstTimeInit()
    self:_StopRadio()
    self:_InitRadioData(radioId, title)
    self:_InitRadio()
    self.view.gotoBtnListState:SetState("Hide")
    self:_PlayRadio()
end
PRTSRadio.SetPlayRadio = HL.Method(HL.Boolean) << function(self, isPlay)
    if isPlay then
        self:_PlayRadio()
    else
        self:_StopRadio()
    end
end
PRTSRadio.SetGotoBtn = HL.Method(HL.Table, HL.Function) << function(self, btnNameList, gotoBtnCallback)
    local count = #btnNameList
    if count <= 0 then
        self.view.gotoBtnListState:SetState("Hide")
        return
    end
    self.m_gotoBtnCallback = gotoBtnCallback
    self.m_gotoBtnNameList = btnNameList
    self.view.gotoBtnListState:SetState("Show")
    self.m_genGotoBtnCells:Refresh(count, function(cell, luaIndex)
        cell.nameTxt.text = self.m_gotoBtnNameList[luaIndex]
        cell.gotoBtn.onClick:RemoveAllListeners()
        cell.gotoBtn.onClick:AddListener(function()
            self:_OnClickGotoBtn(luaIndex)
        end)
    end)
end
PRTSRadio._OnEnable = HL.Override() << function(self)
    self:_PlayRadio()
end
PRTSRadio._OnDisable = HL.Override() << function(self)
    self:_StopRadio()
end
PRTSRadio._OnDestroy = HL.Override() << function(self)
    self:_StopRadio()
end
PRTSRadio._InitRadioData = HL.Method(HL.String, HL.String) << function(self, radioId, title)
    local radioCfg = Utils.tryGetTableCfg(Tables.radioTable, radioId)
    if radioCfg == nil then
        return
    end
    self.m_radioBasicInfos = { radioId = radioId, radioTitle = title, totalDuration = 0, infos = {} }
    local infosRef = self.m_radioBasicInfos
    for _, radioData in pairs(radioCfg.radioSingleDataList) do
        local voiceId = "au_" .. radioData.id
        if not string.isEmpty(radioData.audioOverride) then
            voiceId = radioData.audioOverride
        end
        local hasVoice, duration = VoiceUtils.TryGetVoiceDuration(voiceId)
        if not hasVoice then
            voiceId = ""
            duration = UIUtils.getTextShowDuration(radioData.radioText)
        end
        local newInfo = { actorName = radioData.actorName, radioTxt = radioData.radioText, voiceId = voiceId, audioEffect = radioData.audioEffect, duration = duration, startTime = infosRef.totalDuration, }
        infosRef.totalDuration = infosRef.totalDuration + duration
        table.insert(infosRef.infos, newInfo)
    end
end
PRTSRadio._InitRadio = HL.Method() << function(self)
    if self.m_radioBasicInfos == nil then
        self.view.title.text = ""
        self.view.radioTextList:UpdateCount(0)
        return
    end
    self.view.title.text = self.m_radioBasicInfos.radioTitle
    self.view.radioTextList:UpdateCount(#self.m_radioBasicInfos.infos, true)
end
PRTSRadio._OnRefreshRadioTextCell = HL.Method(HL.Any, HL.Number) << function(self, cell, luaIndex)
    local info = self.m_radioBasicInfos.infos[luaIndex]
    local actorName = UIUtils.resolveTextCinematic(info.actorName)
    cell.nameTxt.text = UIUtils.removePattern(actorName, UIConst.NARRATIVE_ANONYMITY_PATTERN)
    cell.radioTxt.text = UIUtils.resolveTextCinematic(info.radioTxt)
    local color
    local playInfos = self.m_radioPlayInfos
    if playInfos and playInfos.updateKey > 0 and playInfos.curLuaIndex == luaIndex then
        color = self.view.config.AUDIO_PLAYING_TEXT_COLOR
    else
        color = self.view.config.AUDIO_NORMAL_TEXT_COLOR
    end
    cell.nameTxt.color = color
    cell.radioTxt.color = color
end
PRTSRadio._SetRadioTextHighlight = HL.Method(HL.Number, HL.Boolean) << function(self, luaIndex, isHighlight)
    if luaIndex < 1 or luaIndex > #self.m_radioBasicInfos.infos then
        return
    end
    local obj = self.view.radioTextList:Get(CSIndex(luaIndex))
    local cell = self.m_getRadioTextCellFunc(obj)
    local color
    if isHighlight then
        color = self.view.config.AUDIO_PLAYING_TEXT_COLOR
    else
        color = self.view.config.AUDIO_NORMAL_TEXT_COLOR
    end
    cell.nameTxt.color = color
    cell.radioTxt.color = color
end
PRTSRadio._OnClickGotoBtn = HL.Method(HL.Number) << function(self, luaIndex)
    if self.m_gotoBtnCallback then
        self.m_gotoBtnCallback(luaIndex)
    end
end
PRTSRadio._InitRadioPlayData = HL.Method() << function(self)
    if not self.m_radioPlayInfos then
        self.m_radioPlayInfos = { curTime = 0, curIndexPlayTime = 0, curLuaIndex = 0, updateKey = -1, voiceHandleId = -1, autoScrollText = true, }
    end
    local info = self.m_radioPlayInfos
    info.curTime = 0
    info.curIndexPlayTime = 0
    info.curLuaIndex = 0
    info.updateKey = -1
    info.voiceHandleId = -1
    info.autoScrollText = true
end
PRTSRadio._PlayRadio = HL.Method() << function(self)
    if not self.m_radioBasicInfos or #self.m_radioBasicInfos.infos <= 0 then
        return
    end
    if self.m_radioPlayInfos and self.m_radioPlayInfos.updateKey > 0 then
        return
    end
    self:_InitRadioPlayData()
    self.view.radioTextList:ScrollToIndex(0, true, CS.Beyond.UI.UIScrollList.ScrollAlignType.Bottom)
    self.m_radioPlayInfos.updateKey = LuaUpdate:Add("Tick", function(deltaTime)
        self:_OnUpdateRadio(deltaTime)
    end)
end
PRTSRadio._OnUpdateRadio = HL.Method(HL.Number) << function(self, deltaTime)
    local basicInfos = self.m_radioBasicInfos
    local playInfos = self.m_radioPlayInfos
    local curTime = playInfos.curTime + deltaTime
    local curIndexPlayTime = playInfos.curIndexPlayTime + deltaTime
    playInfos.curTime = curTime
    playInfos.curIndexPlayTime = curIndexPlayTime
    self:_RefreshRadioTimeProgress()
    local curLuaIdx = playInfos.curLuaIndex
    local showNext = curLuaIdx < 1
    if not showNext then
        local singleInfo = basicInfos.infos[curLuaIdx]
        if (curTime >= singleInfo.startTime and curIndexPlayTime > singleInfo.duration) then
            showNext = true
        end
    end
    if showNext then
        self:_EndCurIndexRadio(curLuaIdx)
        local isShow = self:_TryShowCurIndexRadio(curLuaIdx + 1)
        if not isShow then
            self:_StopRadio()
            playInfos.curTime = basicInfos.totalDuration
            self:_RefreshRadioTimeProgress()
            return
        end
    end
end
PRTSRadio._StopRadio = HL.Method() << function(self)
    if not (self.m_radioPlayInfos and self.m_radioPlayInfos.updateKey > 0) then
        return
    end
    if self.m_radioPlayInfos.voiceHandleId > 0 then
        VoiceManager:StopVoice(self.m_radioPlayInfos.voiceHandleId)
        self.m_radioPlayInfos.voiceHandleId = -1
    end
    LuaUpdate:Remove(self.m_radioPlayInfos.updateKey)
    self.m_radioPlayInfos.updateKey = -1
end
PRTSRadio._RefreshRadioTimeProgress = HL.Method() << function(self)
    local duration = self.m_radioBasicInfos.totalDuration
    local curTime = math.min(self.m_radioPlayInfos.curTime, duration)
    local percent = curTime / duration
    self.view.timeTxt.text = UIUtils.getRemainingText(curTime) .. "/" .. UIUtils.getRemainingText(duration)
    self.view.timeBar.size = percent
end
PRTSRadio._TryShowCurIndexRadio = HL.Method(HL.Number).Return(HL.Boolean) << function(self, luaIndex)
    if luaIndex < 1 or luaIndex > #self.m_radioBasicInfos.infos then
        return false
    end
    local playInfos = self.m_radioPlayInfos
    local singleInfo = self.m_radioBasicInfos.infos[luaIndex]
    playInfos.curIndexPlayTime = 0
    playInfos.curTime = singleInfo.startTime
    playInfos.curLuaIndex = luaIndex
    local cfg = CS.Beyond.Gameplay.Audio.NarrativeVoiceConfig(singleInfo.audioEffect, 1)
    playInfos.voiceHandleId = VoiceManager:SpeakNarrative(singleInfo.voiceId, nil, cfg)
    if playInfos.autoScrollText then
        local showRange = self.view.radioTextList:GetShowRange()
        local csIndex = CSIndex(luaIndex)
        if csIndex > showRange.y then
            self.view.radioTextList:ScrollToIndex(csIndex, true, CS.Beyond.UI.UIScrollList.ScrollAlignType.Bottom)
        end
    end
    self:_SetRadioTextHighlight(luaIndex, true)
    return true
end
PRTSRadio._EndCurIndexRadio = HL.Method(HL.Number) << function(self, luaIndex)
    if luaIndex < 1 or luaIndex > #self.m_radioBasicInfos.infos then
        return
    end
    self:_SetRadioTextHighlight(luaIndex, false)
    if self.m_radioPlayInfos.voiceHandleId > 0 then
        VoiceManager:StopVoice(self.m_radioPlayInfos.voiceHandleId)
        self.m_radioPlayInfos.voiceHandleId = -1
    end
end
PRTSRadio._OnManualDragRadioTextList = HL.Method() << function(self)
    if self.m_radioPlayInfos and self.m_radioPlayInfos.updateKey > 0 then
        self.m_radioPlayInfos.autoScrollText = false
    end
end
HL.Commit(PRTSRadio)
return PRTSRadio