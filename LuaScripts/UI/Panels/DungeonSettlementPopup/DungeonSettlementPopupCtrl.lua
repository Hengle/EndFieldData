local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.DungeonSettlementPopup
local LevelScriptTaskType = CS.Beyond.Gameplay.LevelScriptTaskType
local PanelState = { ShowResult = 1, ShowRewards = 2, }
local GameMechanicsType = { Race = "dungeon_rpg", Char = "dungeon_char", Challenge = "dungeon_challenge", }
DungeonSettlementPopupCtrl = HL.Class('DungeonSettlementPopupCtrl', uiCtrl.UICtrl)
DungeonSettlementPopupCtrl.s_messages = HL.StaticField(HL.Table) << { [MessageConst.ON_STAMINA_CHANGED] = 'OnStaminaChanged', }
DungeonSettlementPopupCtrl.s_cachedCompleteResult = HL.StaticField(HL.Table)
DungeonSettlementPopupCtrl.OnDungeonComplete = HL.StaticMethod(HL.Any) << function(args)
    local isNewTimeRecord, curGameTimeRecord = unpack(args)
    if DungeonSettlementPopupCtrl.s_cachedCompleteResult == nil then
        DungeonSettlementPopupCtrl.s_cachedCompleteResult = {}
    end
    DungeonSettlementPopupCtrl.s_cachedCompleteResult.isNewTimeRecord = isNewTimeRecord
    DungeonSettlementPopupCtrl.s_cachedCompleteResult.curGameTimeRecord = curGameTimeRecord
end
DungeonSettlementPopupCtrl.OnShowDungeonResult = HL.StaticMethod(HL.Any) << function(args)
    LuaSystemManager.commonTaskTrackSystem:AddRequest("DungeonSettlement", function()
        if not Utils.isInDungeon() then
            logger.error(ELogChannel.Dungeon, "error, try to open settlement out of dungeon")
            return
        end
        PhaseManager:ExitPhaseFastTo(PhaseId.Level)
        local dungeonId, leaveTimestamp = unpack(args)
        local ctrl = UIManager:AutoOpen(PANEL_ID)
        ctrl:StartSettlement(dungeonId, leaveTimestamp)
    end, function()
        UIManager:Close(PANEL_ID)
    end)
end
DungeonSettlementPopupCtrl.m_panelState = HL.Field(HL.Number) << -1
DungeonSettlementPopupCtrl.m_dungeonId = HL.Field(HL.String) << ""
DungeonSettlementPopupCtrl.m_leaveTimestamp = HL.Field(HL.Number) << -1
DungeonSettlementPopupCtrl.m_mainCellCache = HL.Field(HL.Forward("UIListCache"))
DungeonSettlementPopupCtrl.m_extraCellCache = HL.Field(HL.Forward("UIListCache"))
DungeonSettlementPopupCtrl.m_getRewardItemCellFunc = HL.Field(HL.Function)
DungeonSettlementPopupCtrl.m_items = HL.Field(HL.Table)
DungeonSettlementPopupCtrl.m_animWrapper = HL.Field(HL.Any)
DungeonSettlementPopupCtrl.m_canCloseSelf = HL.Field(HL.Boolean) << false
DungeonSettlementPopupCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnEmpty.onClick:AddListener(function()
        self:_OnBtnEmptyClick()
    end)
    self.view.btnClose.onClick:AddListener(function()
        self:_OnBtnCloseClick()
    end)
    self.view.btnLeaveDungeon.onClick:AddListener(function()
        self:_OnBtnLeaveDungeonClick()
    end)
    self.view.btnRestartDungeon.onClick:AddListener(function()
        self:_OnBtnRestartDungeonClick()
    end)
    self.m_animWrapper = self:GetAnimationWrapper()
    self.m_mainCellCache = UIUtils.genCellCache(self.view.mainCell)
    self.m_extraCellCache = UIUtils.genCellCache(self.view.extraCell)
    self.m_getRewardItemCellFunc = UIUtils.genCachedCellFunction(self.view.rewardsScrollList)
    self.view.rewardsScrollList.onUpdateCell:AddListener(function(gameObject, csIndex)
        self:_OnUpdateCell(gameObject, csIndex)
    end)
    self.view.rewardsScrollList.onGraduallyShowFinish:AddListener(function()
        self.view.btnEmpty.gameObject:SetActive(false)
        self:_CheckCanCloseSelf()
    end)
end
DungeonSettlementPopupCtrl.OnShow = HL.Override() << function(self)
    Notify(MessageConst.ON_DUNGEON_SETTLEMENT_OPENED)
    Notify(MessageConst.TOGGLE_COMMON_ITEM_TOAST, false)
end
DungeonSettlementPopupCtrl.OnHide = HL.Override() << function(self)
    Notify(MessageConst.ON_DUNGEON_SETTLEMENT_CLOSED)
    Notify(MessageConst.TOGGLE_COMMON_ITEM_TOAST, true)
end
DungeonSettlementPopupCtrl.OnClose = HL.Override() << function(self)
    Notify(MessageConst.ON_DUNGEON_SETTLEMENT_CLOSED)
    Notify(MessageConst.TOGGLE_COMMON_ITEM_TOAST, true)
end
DungeonSettlementPopupCtrl.OnAnimationInFinished = HL.Override() << function(self)
    local obj = self.view.rewardsScrollList:Get(0)
    if obj then
        local cell = self.m_getRewardItemCellFunc(obj)
        if cell then
            InputManagerInst:MoveVirtualMouseTo(cell.transform, self.uiCamera)
        end
    end
end
DungeonSettlementPopupCtrl._OnBtnEmptyClick = HL.Method() << function(self)
    if self.m_panelState == PanelState.ShowResult then
        self.m_animWrapper:Play("dungeonsettlementpopup_change")
        self.m_panelState = PanelState.ShowRewards
        self:_UpdateRewardsState()
    elseif self.m_panelState == PanelState.ShowRewards then
        self:_OnClickSkip()
    end
end
DungeonSettlementPopupCtrl._OnBtnCloseClick = HL.Method() << function(self)
    if not self.m_canCloseSelf then
        return
    end
    self:PlayAnimationOutWithCallback(function()
        self:Close()
        UIManager:Show(PanelId.DungeonCharTimeHint)
    end)
end
DungeonSettlementPopupCtrl._UpdateRewardsState = HL.Method() << function(self)
    self:_ToggleRewardsState(true)
    self.m_items = self:_GetRewardItems()
    local gameMechanicCfg = Tables.gameMechanicTable[self.m_dungeonId]
    local gameCategory = gameMechanicCfg.gameCategory
    local gameMechanicCategoryCfg = Tables.gameMechanicCategoryTable[gameCategory]
    self.view.staminaNode.gameObject:SetActiveIfNecessary(gameMechanicCfg.costStamina > 0)
    self.view.btnRestartDungeon.gameObject:SetActiveIfNecessary(gameMechanicCategoryCfg.canReChallengeAfterReward)
    local rewardsCount = #self.m_items
    self.view.emptyRewardNode.gameObject:SetActiveIfNecessary(rewardsCount == 0)
    self.view.rewardsScrollList:UpdateCount(rewardsCount)
    self.view.btnNode.gameObject:SetActiveIfNecessary(not self.m_canCloseSelf)
    self.view.infoDeco.gameObject:SetActiveIfNecessary(self.m_canCloseSelf)
    self:_RefreshCostStamina()
end
DungeonSettlementPopupCtrl._RefreshCostStamina = HL.Method() << function(self)
    local gameMechanicCfg = Tables.gameMechanicTable[self.m_dungeonId]
    local costStamina = gameMechanicCfg.costStamina
    local cntStamina = GameInstance.player.inventory.curStamina
    self.view.costStaminaTxt.text = UIUtils.setCountColor(costStamina, cntStamina < costStamina)
end
DungeonSettlementPopupCtrl._ToggleRewardsState = HL.Method(HL.Boolean) << function(self, isRewardState)
    self.view.rewardsNode.gameObject:SetActiveIfNecessary(isRewardState)
    self.view.infoNode.gameObject:SetActiveIfNecessary(not isRewardState)
    self.view.btnNode.gameObject:SetActiveIfNecessary(isRewardState)
    self.view.titleTxt.text = isRewardState and Language.LUA_DUNGEON_SETTLEMENT_REWARDS_TITLE or Language.LUA_DUNGEON_SETTLEMENT_RESULT_TITLE
end
DungeonSettlementPopupCtrl._OnBtnRestartDungeonClick = HL.Method() << function(self)
    local gameMechanicCfg = Tables.gameMechanicTable[self.m_dungeonId]
    local cntStamina = GameInstance.player.inventory.curStamina
    if cntStamina < gameMechanicCfg.costStamina then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_NOT_ENOUGH_STAMINA_HINT)
        return
    end
    self:PlayAnimationOutWithCallback(function()
        GameInstance.dungeonManager:RestartDungeon(self.m_dungeonId)
        self:Close()
    end)
end
DungeonSettlementPopupCtrl._OnBtnLeaveDungeonClick = HL.Method() << function(self)
    self:Notify(MessageConst.HIDE_ITEM_TIPS)
    GameInstance.dungeonManager:LeaveDungeon()
end
DungeonSettlementPopupCtrl._OnClickSkip = HL.Method() << function(self)
    self.view.luaPanel.animationWrapper:SkipInAnimation()
    self.view.rewardsScrollList:SkipGraduallyShow()
end
DungeonSettlementPopupCtrl._OnUpdateCell = HL.Method(GameObject, HL.Number) << function(self, go, csIndex)
    local cell = self.m_getRewardItemCellFunc(go)
    local index = LuaIndex(csIndex)
    local itemBundle = self.m_items[index]
    cell:InitItem(itemBundle, true)
    UIUtils.setRewardItemRarityGlow(cell, UIUtils.getItemRarity(itemBundle.id))
end
DungeonSettlementPopupCtrl._GetRewardItems = HL.Method().Return(HL.Table) << function(self)
    local rewardPack = GameInstance.player.inventory:ConsumeLatestRewardPackOfType(CS.Beyond.GEnums.RewardSourceType.Dungeon)
    local items = {}
    if rewardPack and rewardPack.rewardSourceType == CS.Beyond.GEnums.RewardSourceType.Dungeon then
        for _, itemBundle in pairs(rewardPack.itemBundleList) do
            local _, itemCfg = Tables.itemTable:TryGetValue(itemBundle.id)
            if itemCfg then
                table.insert(items, { id = itemBundle.id, count = itemBundle.count, sortId1 = itemCfg.sortId1, sortId2 = itemCfg.sortId2, })
            end
        end
        table.sort(items, Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS))
    end
    return items
end
DungeonSettlementPopupCtrl._UpdateResultState = HL.Method() << function(self)
    self:_ToggleRewardsState(false)
    local succ, subGameData = DataManager.subGameInstDataTable:TryGetValue(self.m_dungeonId)
    if not succ then
        return
    end
    local showTimeInfo = subGameData.hasTimer or subGameData.hasTimeLimit
    if showTimeInfo then
        local curGameTimeRecord = DungeonSettlementPopupCtrl.s_cachedCompleteResult.curGameTimeRecord
        local isNewTimeRecord = DungeonSettlementPopupCtrl.s_cachedCompleteResult.isNewTimeRecord
        self.view.curGameTimeTxt.text = UIUtils.getLeftTimeToSecondMS(curGameTimeRecord / 1000)
        self.view.newTimeRecord.gameObject:SetActiveIfNecessary(isNewTimeRecord)
    end
    self.view.timeInfoNode.gameObject:SetActiveIfNecessary(showTimeInfo)
    local trackingMgr = GameInstance.world.levelScriptTaskTrackingManager
    local mainTask = trackingMgr.mainTask
    local mainTaskCount = mainTask ~= nil and mainTask.objectives.Length or 0
    self.m_mainCellCache:Refresh(mainTaskCount, function(cell, luaIndex)
        self:_UpdateGoalCell(cell, luaIndex, LevelScriptTaskType.Main)
    end)
    self.view.mainInfoNode.gameObject:SetActiveIfNecessary(mainTaskCount > 0)
    local extraTask = trackingMgr.extraTask
    local extraTaskCount = extraTask ~= nil and extraTask.objectives.Length or 0
    self.m_extraCellCache:Refresh(extraTaskCount, function(cell, luaIndex)
        self:_UpdateGoalCell(cell, luaIndex, LevelScriptTaskType.Extra)
    end)
    self.view.extraInfoNode.gameObject:SetActiveIfNecessary(extraTaskCount > 0)
end
DungeonSettlementPopupCtrl._UpdateGoalCell = HL.Method(HL.Any, HL.Number, CS.Beyond.Gameplay.LevelScriptTaskType) << function(self, cell, luaIndex, taskType)
    local trackingTask = GameInstance.world.levelScriptTaskTrackingManager:GetTaskByType(taskType)
    local csIndex = CSIndex(luaIndex)
    local obj = trackingTask.objectives[csIndex]
    local finished = obj.isCompleted
    local success, descText, progressText = trackingTask:TryGetValueObjectiveDescription(obj)
    cell.finishedIcon.gameObject:SetActiveIfNecessary(finished)
    cell.normalIcon.gameObject:SetActiveIfNecessary(not finished)
    cell.goalTxt.text = descText
    cell.stateTxt.text = progressText
    local succ, objTrackingInfo = trackingTask.extraInfo.trackingInfoDict:TryGetValue(obj.objectiveEnum)
    cell.stateTxt.gameObject:SetActiveIfNecessary(succ and objTrackingInfo.needFormatProgress)
end
DungeonSettlementPopupCtrl._CheckCanCloseSelf = HL.Method() << function(self)
    if not self.m_canCloseSelf then
        return
    end
    self.view.btnClose.gameObject:SetActiveIfNecessary(true)
end
DungeonSettlementPopupCtrl.StartSettlement = HL.Method(HL.String, HL.Number) << function(self, dungeonId, leaveTimestamp)
    self.m_dungeonId = dungeonId
    self.m_leaveTimestamp = leaveTimestamp
    local gameMechanicCfg = Tables.gameMechanicTable[dungeonId]
    local gameCategory = gameMechanicCfg.gameCategory
    local needStamina = gameMechanicCfg.costStamina > 0
    if needStamina then
        self.view.staminaBar:InitWalletBarPlaceholder(UIConst.REGION_MAP_STAMINA_IDS)
    end
    self.view.btnEmpty.gameObject:SetActiveIfNecessary(true)
    self.view.btnClose.gameObject:SetActiveIfNecessary(false)
    self.m_canCloseSelf = gameCategory == GameMechanicsType.Char
    local needShowResult = gameCategory == GameMechanicsType.Challenge
    if needShowResult then
        self.m_panelState = PanelState.ShowResult
    else
        self.m_panelState = PanelState.ShowRewards
    end
    if self.m_panelState == PanelState.ShowResult then
        self.m_animWrapper:Play("dungeonsettlementpopup_in")
        self:_UpdateResultState()
    elseif self.m_panelState == PanelState.ShowRewards then
        self.view.rewardsScrollList.gameObject:SetActiveIfNecessary(false)
        self.m_animWrapper:Play("dungeonsettlementpopup_done")
        self:_UpdateRewardsState()
    end
    if self.m_canCloseSelf then
        UIManager:Open(PanelId.DungeonCharTimeHint, {
            leaveTimestamp = leaveTimestamp,
            endFunc = function()
                GameInstance.dungeonManager:LeaveDungeon()
            end
        })
        UIManager:Hide(PanelId.DungeonCharTimeHint)
    else
        self:_StartCoroutine(function()
            local realLeaveTimestamp = leaveTimestamp
            while true do
                coroutine.step()
                local currentTS = CS.Beyond.DateTimeUtils.GetCurrentTimestampBySeconds()
                local leftTime = math.max(realLeaveTimestamp - currentTS, 0)
                local leaveTxt = tostring(leftTime) .. Language.LUA_LEAVE_DUNGEON_TEXT
                self.view.leaveTxt.text = leaveTxt
                if currentTS - realLeaveTimestamp >= 0 then
                    break
                end
            end
            self:_OnBtnLeaveDungeonClick()
        end)
    end
end
DungeonSettlementPopupCtrl.OnStaminaChanged = HL.Method() << function(self)
    self:_RefreshCostStamina()
end
HL.Commit(DungeonSettlementPopupCtrl)