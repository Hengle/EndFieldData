local panelConfig = require_ex("UI/Panels/PanelConfig").config
UIWorldFreezeManager = HL.Class('UIWorldFreezeManager')
do
    UIWorldFreezeManager.m_timeScaleHandle = HL.Field(HL.Number) << -1
    UIWorldFreezeManager.m_activePanelCount = HL.Field(HL.Number) << 0
    UIWorldFreezeManager.m_activeServerFreezerCnt = HL.Field(HL.Number) << 0
    UIWorldFreezeManager.m_activePanels = HL.Field(HL.Table)
end
do
    UIWorldFreezeManager.UIWorldFreezeManager = HL.Constructor() << function(self)
        self.m_activePanels = {}
        self:_RegisterMessages()
    end
    UIWorldFreezeManager.IsUIWorldFreeze = HL.Method().Return(HL.Boolean) << function(self)
        return self.m_timeScaleHandle ~= -1
    end
end
do
    UIWorldFreezeManager._RegisterMessages = HL.Method() << function(self)
        Register(MessageConst.ON_BEFORE_UI_PANEL_OPEN, function(name)
            self:_OnPanelActivate(name)
        end)
        Register(MessageConst.ON_UI_PANEL_CLOSED, function(name)
            self:_OnPanelDeActivate(name)
        end)
        Register(MessageConst.ON_UI_PANEL_SHOW, function(name)
            self:_OnPanelActivate(name)
        end)
        Register(MessageConst.ON_UI_PANEL_HIDE, function(name)
            self:_OnPanelDeActivate(name)
        end)
    end
    UIWorldFreezeManager._OnPanelActivate = HL.Method(HL.String) << function(self, panelName)
        local panelCfg = panelConfig[panelName]
        if not panelCfg or not panelCfg.freezeWorld then
            return
        end
        local freezeServer = not panelCfg.clientOnlyFreezeWorld
        if not self.m_activePanels[panelName] then
            self.m_activePanels[panelName] = true
            self.m_activePanelCount = self.m_activePanelCount + 1
            if freezeServer then
                self.m_activeServerFreezerCnt = self.m_activeServerFreezerCnt + 1
            end
            if self.m_activePanelCount == 1 then
                self:_FreezeWorld(true)
            end
            if freezeServer and self.m_activeServerFreezerCnt == 1 then
                self:_FreezeServerWorld(true)
            end
        end
    end
    UIWorldFreezeManager._OnPanelDeActivate = HL.Method(HL.String) << function(self, panelName)
        if self.m_timeScaleHandle == -1 then
            return
        end
        local panelCfg = panelConfig[panelName]
        if not panelCfg or not panelCfg.freezeWorld then
            return
        end
        local freezeServer = not panelCfg.clientOnlyFreezeWorld
        if self.m_activePanels[panelName] then
            self.m_activePanels[panelName] = nil
            self.m_activePanelCount = self.m_activePanelCount - 1
            if freezeServer then
                self.m_activeServerFreezerCnt = self.m_activeServerFreezerCnt - 1
            end
        end
        if self.m_activePanelCount == 0 then
            self:_FreezeWorld(false)
        end
        if freezeServer and self.m_activeServerFreezerCnt == 0 then
            self:_FreezeServerWorld(false)
        end
    end
    UIWorldFreezeManager._FreezeWorld = HL.Method(HL.Boolean) << function(self, isFrozen)
        if isFrozen then
            self.m_timeScaleHandle = TimeManagerInst:StartChangeTimeScale(0)
            AudioAdapter.PostEvent("au_global_contr_fullscreen_menu_pause")
        else
            if self.m_timeScaleHandle ~= -1 then
                TimeManagerInst:StopChangeTimeScale(self.m_timeScaleHandle)
                self.m_timeScaleHandle = -1
                AudioAdapter.PostEvent("au_global_contr_fullscreen_menu_resume")
            end
        end
        GameInstance.world.cutsceneManager:PauseTimelineByUI(isFrozen)
    end
    UIWorldFreezeManager._FreezeServerWorld = HL.Method(HL.Boolean) << function(self, isFrozen)
        GameInstance.gameplayNetwork:SendPauseWorldByUI(isFrozen)
    end
end
HL.Commit(UIWorldFreezeManager)
return UIWorldFreezeManager