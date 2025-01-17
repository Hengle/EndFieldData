local phaseBase = require_ex('Phase/Core/PhaseBase')
local PHASE_ID = PhaseId.Inventory
PhaseInventory = HL.Class('PhaseInventory', phaseBase.PhaseBase)
PhaseInventory.s_messages = HL.StaticField(HL.Table) << { [MessageConst.OPEN_INVENTORY_PANEL] = { 'OpenInventoryPanel', false }, }
PhaseInventory.m_hidePanelKey = HL.Field(HL.Number) << -1
PhaseInventory.m_invPanel = HL.Field(HL.Forward('InventoryCtrl'))
PhaseInventory.m_inHalfScreen = HL.Field(HL.Boolean) << false
local ReservePanelIds = { PanelId.Inventory, PanelId.LevelCamera, PanelId.BattleDamageText, PanelId.HeadBar, }
PhaseInventory.OpenInventoryPanel = HL.StaticMethod() << function()
    PhaseManager:OpenPhase(PhaseId.Inventory)
end
PhaseInventory.PrepareTransition = HL.Override(HL.Number, HL.Boolean, HL.Opt(HL.Number)) << function(self, transitionType, fastMode, anotherPhaseId)
    if transitionType == PhaseConst.EPhaseState.TransitionIn then
        UIManager:PreloadPanelAsset(PanelId.Inventory)
        self.m_inHalfScreen = not Utils.isInSafeZone()
        if anotherPhaseId == PhaseId.Level then
            local reservePanelIds = self.m_inHalfScreen and ReservePanelIds or { PanelId.Inventory }
            Notify(MessageConst.SET_PHASE_LEVEL_TRANSITION_RESERVE_PANELS, reservePanelIds)
        end
    end
end
PhaseInventory._DoPhaseTransitionIn = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    local reservePanelIds = self.m_inHalfScreen and ReservePanelIds or { PanelId.Inventory }
    self.m_hidePanelKey = UIManager:ClearScreen(reservePanelIds)
    self.m_invPanel = UIManager:AutoOpen(PanelId.Inventory)
    self.m_invPanel:ChangePanelCfg("clearedPanel", true)
    self.m_invPanel:OpenInventoryPanel(self.arg)
    if self.m_inHalfScreen then
        Notify(MessageConst.ENTER_LEVEL_HALF_SCREEN_PANEL_MODE)
    end
end
PhaseInventory._OnActivated = HL.Override() << function(self)
end
PhaseInventory._OnDeActivated = HL.Override() << function(self)
end
PhaseInventory._DoPhaseTransitionOut = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    Notify(MessageConst.HIDE_ITEM_TIPS)
    Notify(MessageConst.EXIT_LEVEL_HALF_SCREEN_PANEL_MODE)
    self.m_invPanel:ChangePanelCfg("clearedPanel", false)
    if not fastMode then
        self.m_inTransition = true
        self.m_invPanel:PlayAnimationOutWithCallback(function()
            self.m_invPanel:ResetOnClose()
            self.m_hidePanelKey = UIManager:RecoverScreen(self.m_hidePanelKey)
            self.m_inTransition = false
        end)
    else
        self.m_invPanel:ResetOnClose()
        self.m_hidePanelKey = UIManager:RecoverScreen(self.m_hidePanelKey)
    end
end
PhaseInventory._DoPhaseTransitionBehind = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    if args.anotherPhaseId == PhaseId.FacDepotSwitching then
        return
    end
    if fastMode then
        self.m_invPanel:Hide()
    else
        self.m_invPanel:PlayAnimationOut(UIConst.PANEL_PLAY_ANIMATION_OUT_COMPLETE_ACTION_TYPE.Hide)
    end
end
PhaseInventory._DoPhaseTransitionBackToTop = HL.Override(HL.Boolean, HL.Opt(HL.Table)) << function(self, fastMode, args)
    if args.anotherPhaseId == PhaseId.FacDepotSwitching then
        return
    end
    self.m_invPanel:Show()
end
HL.Commit(PhaseInventory)