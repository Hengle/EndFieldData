local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.RemoteComm
PhaseRemoteComm = HL.Class('PhaseRemoteComm', phaseBase.PhaseBase)
PhaseRemoteComm.s_messages = HL.StaticField(HL.Table) << { [MessageConst.SHOW_REMOTE_COMM] = { 'ShowRemoteComm', false }, [MessageConst.P_REMOTE_COMM_NEXT] = { 'Next' }, [MessageConst.P_REMOTE_COMM_SKIP_END] = { 'RemoteCommSkipEnd' }, }
PhaseRemoteComm.m_timer = HL.Field(HL.Number) << -1
PhaseRemoteComm.m_remoteCommId = HL.Field(HL.String) << ""
PhaseRemoteComm.m_remoteCommData = HL.Field(Cfg.Types.RemoteCommonData)
PhaseRemoteComm.m_panelItem = HL.Field(HL.Forward("PhasePanelItem"))
PhaseRemoteComm.m_hudPanelItem = HL.Field(HL.Forward("PhasePanelItem"))
PhaseRemoteComm.m_bgPanelItem = HL.Field(HL.Forward("PhasePanelItem"))
PhaseRemoteComm.m_index = HL.Field(HL.Number) << 0
PhaseRemoteComm.ShowRemoteComm = HL.StaticMethod(HL.Opt(HL.Table)) << function(data)
    PhaseRemoteComm.AutoOpen(PHASE_ID, data or {})
end
PhaseRemoteComm._OnInit = HL.Override() << function(self)
    PhaseRemoteComm.Super._OnInit(self)
    local remoteCommId = unpack(self.arg)
    self.m_remoteCommId = remoteCommId
    local res, data = Tables.remoteCommonTable:TryGetValue(remoteCommId)
    if res then
        self.m_remoteCommData = data
    else
        logger.error(string.format("RemoteCommData error: %s !!!", remoteCommId))
    end
    self.m_index = 1
end
PhaseRemoteComm._InitAllPhaseItems = HL.Override() << function(self)
    PhaseRemoteComm.Super._InitAllPhaseItems(self)
    self.m_panelItem = self:_GetPanelPhaseItem(PanelId.RemoteComm)
    self.m_hudPanelItem = self:_GetPanelPhaseItem(PanelId.RemoteCommHud)
    self.m_bgPanelItem = self:_GetPanelPhaseItem(PanelId.RemoteCommBG)
end
PhaseRemoteComm.RemoteCommSkipEnd = HL.Method() << function(self)
    self:RemoteCommEnd(true)
end
PhaseRemoteComm.RemoteCommEnd = HL.Method(HL.Boolean) << function(self, skip)
    self.m_hudPanelItem.uiCtrl:PlayAnimationOut(UIConst.PANEL_PLAY_ANIMATION_OUT_COMPLETE_ACTION_TYPE.Hide)
    self.m_bgPanelItem.uiCtrl:PlayAnimationOut(UIConst.PANEL_PLAY_ANIMATION_OUT_COMPLETE_ACTION_TYPE.Hide)
    self.m_panelItem.uiCtrl:PlayAnimationOutWithCallback(function()
        self:ExitSelfFast()
        if self.m_timer > 0 then
            self:_ClearTimer()
        end
    end)
    self:_ClearTimer()
    self.m_timer = TimerManager:StartTimer(0.1, function()
        GameAction.EndRemoteComm(skip)
        self:_ClearTimer()
    end)
end
PhaseRemoteComm._ClearTimer = HL.Method() << function(self)
    if self.m_timer > 0 then
        TimerManager:ClearTimer(self.m_timer)
    end
    self.m_timer = -1
end
PhaseRemoteComm.Next = HL.Method() << function(self)
    self.m_index = self.m_index + 1
    if self.m_index > self.m_remoteCommData.remoteCommSingleDataList.Count then
        self:RemoteCommEnd(false)
    else
        self:_RefreshSingleRemoteComm()
    end
end
PhaseRemoteComm._RefreshSingleRemoteComm = HL.Method() << function(self)
    local singleData = self.m_remoteCommData.remoteCommSingleDataList[CSIndex(self.m_index)]
    self.m_panelItem.uiCtrl:RefreshInfo(singleData)
    self.m_hudPanelItem.uiCtrl:RefreshText(self.m_remoteCommId, singleData)
end
PhaseRemoteComm._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local forceAutoPlay = self.m_remoteCommData.autoPlay
    if forceAutoPlay then
        self.m_hudPanelItem.uiCtrl:SetForceAuto(forceAutoPlay)
    end
    self:_RefreshSingleRemoteComm()
end
PhaseRemoteComm._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end
PhaseRemoteComm._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end
PhaseRemoteComm._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
end
PhaseRemoteComm._OnActivated = HL.Override() << function(self)
end
PhaseRemoteComm._OnDeActivated = HL.Override() << function(self)
end
PhaseRemoteComm._OnDestroy = HL.Override() << function(self)
end
HL.Commit(PhaseRemoteComm)