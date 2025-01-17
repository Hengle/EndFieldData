local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SettlementDefenseInGameHud
SettlementDefenseInGameHudCtrl = HL.Class('SettlementDefenseInGameHudCtrl', uiCtrl.UICtrl)
local ENEMY_COUNT_FORMAT = "%d/%d"
local CORE_NUMBER_TEXT_FORMAT = "%d"
local CORE_HP_TEXT_FORMAT = "%d%%"
local CORE_INITIAL_HP_PERCENT = 100
local HP_CHANGE_TWEEN_DURATION = 0.2
local CORE_ATTACKED_IN_ANIMATION_NAME = "defense_hud_core_attacked_in"
local RETREAT_CONFIRM_POP_UP_TEXT_ID = "ui_fac_settlement_defence_retreat_pop_up"
SettlementDefenseInGameHudCtrl.m_towerDefenseSystem = HL.Field(HL.Userdata)
SettlementDefenseInGameHudCtrl.m_towerDefenseGame = HL.Field(HL.Userdata)
SettlementDefenseInGameHudCtrl.m_coreDataList = HL.Field(HL.Table)
SettlementDefenseInGameHudCtrl.m_coreInfoCells = HL.Field(HL.Forward("UIListCache"))
SettlementDefenseInGameHudCtrl.m_updateThread = HL.Field(HL.Thread)
SettlementDefenseInGameHudCtrl.m_coreHpImageWidth = HL.Field(HL.Number) << -1
SettlementDefenseInGameHudCtrl.m_updateTick = HL.Field(HL.Number) << -1
SettlementDefenseInGameHudCtrl.m_taskTrackCtrl = HL.Field(HL.Forward("UICtrl"))
SettlementDefenseInGameHudCtrl.m_hpChangeCallbackList = HL.Field(HL.Table)
SettlementDefenseInGameHudCtrl.s_messages = HL.StaticField(HL.Table) << { [MessageConst.ON_TOWER_DEFENSE_DEFENDING_ENEMY_KILLED] = '_RefreshEnemyCount', }
SettlementDefenseInGameHudCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_towerDefenseSystem = GameInstance.player.towerDefenseSystem
    self.m_towerDefenseGame = GameInstance.player.towerDefenseSystem.towerDefenseGame
    self.m_hpChangeCallbackList = {}
    self:BindInputPlayerAction("common_open_map", function()
        PhaseManager:OpenPhase(PhaseId.SettlementDefenseMainMap)
    end)
    self.view.retreatButton.onClick:AddListener(function()
        self:_OnTowerDefenseRetreatButtonClicked()
    end)
    self.m_coreInfoCells = UIUtils.genCellCache(self.view.coreInfoCell)
    self:_InitCoreInfo()
    self:_InitEnemyCount()
    self.m_updateTick = LuaUpdate:Add("LateTick", function(deltaTime)
        self:_RefreshCoreInfoListPosition()
    end)
end
SettlementDefenseInGameHudCtrl.OnClose = HL.Override() << function(self)
    for index = 1, self.m_coreInfoCells:GetCount() do
        local cell = self.m_coreInfoCells:Get(index)
        if cell ~= nil then
            cell.animationWrapper:ClearTween()
        end
    end
    self.m_updateTick = LuaUpdate:Remove(self.m_updateTick)
    if self.m_towerDefenseGame ~= nil then
        local coreAbilitySystems = self.m_towerDefenseGame.tdCoreAbilitySystems
        for coreAbilityIndex = 0, coreAbilitySystems.Count - 1 do
            local coreAbilitySystem = coreAbilitySystems[coreAbilityIndex]
            coreAbilitySystem.onHpChange:Remove(self.m_hpChangeCallbackList[coreAbilityIndex])
        end
    end
end
SettlementDefenseInGameHudCtrl._OnTowerDefenseRetreatButtonClicked = HL.Method() << function(self)
    Notify(MessageConst.SHOW_POP_UP, {
        content = Language[RETREAT_CONFIRM_POP_UP_TEXT_ID],
        onConfirm = function()
            self.m_towerDefenseSystem:LeaveDefendingPhase()
        end,
        freezeWorld = true,
    })
end
SettlementDefenseInGameHudCtrl._InitCoreInfo = HL.Method() << function(self)
    local tdCoreAbilitySystems = self.m_towerDefenseGame.tdCoreAbilitySystems
    if tdCoreAbilitySystems == nil or tdCoreAbilitySystems.Count == 0 then
        return
    end
    self.m_coreDataList = {}
    for index = 0, tdCoreAbilitySystems.Count - 1 do
        local luaIndex = LuaIndex(index)
        local coreAbilitySystem = tdCoreAbilitySystems[index]
        if coreAbilitySystem ~= nil then
            self.m_coreDataList[luaIndex] = { hp = coreAbilitySystem.hp, maxHp = coreAbilitySystem.maxHp, }
            local callback = function(entity, changedHp)
                self:_OnCoreHpChanged(luaIndex, changedHp)
            end
            self.m_hpChangeCallbackList[index] = callback
            coreAbilitySystem.onHpChange:Add(callback)
        end
    end
    self.m_coreHpImageWidth = self.view.coreInfoCell.hpRect.rect.width
    self.m_coreInfoCells:Refresh(tdCoreAbilitySystems.Count, function(cell, index)
        cell.coreNumber.text = string.format(CORE_NUMBER_TEXT_FORMAT, index)
        cell.hpText.text = string.format(CORE_HP_TEXT_FORMAT, CORE_INITIAL_HP_PERCENT)
    end)
end
SettlementDefenseInGameHudCtrl._OnCoreHpChanged = HL.Method(HL.Number, HL.Number) << function(self, index, changedHp)
    local coreData = self.m_coreDataList[index]
    local cell = self.m_coreInfoCells:Get(index)
    if coreData == nil or cell == nil then
        return
    end
    local hp = coreData.hp + changedHp
    local thresholdHp = coreData.maxHp * self.view.config.HP_RED_THRESHOLD / 100
    local percent = hp / coreData.maxHp
    coreData.hp = hp
    if coreData.hp > thresholdHp and hp <= thresholdHp then
        cell.hp.color = self.view.config.HP_RED_COLOR
    end
    if coreData.hp <= 0 then
        cell.bgLine.gameObject:SetActive(true)
        cell.destroyedIcon.gameObject:SetActive(true)
    end
    local currentWidth = percent * self.m_coreHpImageWidth
    local size = cell.hpRect.sizeDelta
    size.x = currentWidth
    cell.hpRect.sizeDelta = size
    if coreData.hpTween ~= nil then
        coreData.hpTween:Kill(false)
    end
    coreData.hpTween = cell.hpRectTween:DOSizeDelta(size, HP_CHANGE_TWEEN_DURATION)
    cell.hpText.text = string.format(CORE_HP_TEXT_FORMAT, math.floor(percent * 100))
    cell.animationWrapper:ClearTween()
    cell.animationWrapper:PlayWithTween(CORE_ATTACKED_IN_ANIMATION_NAME)
end
SettlementDefenseInGameHudCtrl._RefreshCoreInfoListPosition = HL.Method() << function(self)
    if self.m_taskTrackCtrl == nil then
        local success, taskTrackCtrl = UIManager:IsOpen(PanelId.CommonTaskTrackHud)
        if not success then
            return
        end
        self.m_taskTrackCtrl = taskTrackCtrl
    end
    self.view.coreInfoList.position = self.m_taskTrackCtrl:GetContentBottomFollowPosition()
end
SettlementDefenseInGameHudCtrl._InitEnemyCount = HL.Method() << function(self)
    self:_RefreshEnemyCount()
end
SettlementDefenseInGameHudCtrl._RefreshEnemyCount = HL.Method() << function(self)
    self.view.enemyCountNode.enemyCount.text = string.format(ENEMY_COUNT_FORMAT, self.m_towerDefenseGame.killedEnemyCount, self.m_towerDefenseGame.totalEnemyCount)
end
HL.Commit(SettlementDefenseInGameHudCtrl)