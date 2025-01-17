local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.MapMarkDetailDungeon
MapMarkDetailDungeonCtrl = HL.Class('MapMarkDetailDungeonCtrl', uiCtrl.UICtrl)
MapMarkDetailDungeonCtrl.s_messages = HL.StaticField(HL.Table) << {}
MapMarkDetailDungeonCtrl.m_difficultyList = HL.Field(HL.Forward('UIListCache'))
MapMarkDetailDungeonCtrl.m_type = HL.Field(HL.Any)
MapMarkDetailDungeonCtrl.m_defaultLookDungeonId = HL.Field(HL.Any)
MapMarkDetailDungeonCtrl.m_markInstId = HL.Field(HL.String) << ""
MapMarkDetailDungeonCtrl.m_dungeonSeriesId = HL.Field(HL.String) << ""
MapMarkDetailDungeonCtrl.m_dungeonSeriesData = HL.Field(HL.Any)
MapMarkDetailDungeonCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_difficultyList = UIUtils.genCellCache(self.view.singleDifficulty)
    args = args or {}
    local markInstId = args.markInstId
    self.m_markInstId = markInstId
    local getRuntimeDataSuccess, markRuntimeData = GameInstance.player.mapManager:GetMarkInstRuntimeData(markInstId)
    if getRuntimeDataSuccess == false then
        logger.error("地图详情页获取实例数据失败" .. self.m_instId)
        return
    end
    local templateId = markRuntimeData.templateId
    local getSuccess, templateInfo = Tables.mapMarkTempTable:TryGetValue(templateId)
    self.m_type = templateInfo.markType
    local detailData = markRuntimeData.detail
    local dungeonSeriesId = detailData.dungeonSeriesId
    self.m_dungeonSeriesId = dungeonSeriesId
    local getDungeonSeriesSuccess, dungeonSeriesData = Tables.dungeonSeriesTable:TryGetValue(dungeonSeriesId or "")
    if not getDungeonSeriesSuccess then
        logger.error("地图详情页获取DungeonSeries信息失败" .. dungeonSeriesId)
        return
    end
    self.m_dungeonSeriesData = dungeonSeriesData
    local list = dungeonSeriesData.includeDungeonIds
    local dungeonDifficultyCount = list.Count
    for i = 1, dungeonDifficultyCount do
        local dungeonId = list[CSIndex(i)]
        if not GameInstance.dungeonManager:IsDungeonPassed(dungeonId) then
            self.m_defaultLookDungeonId = dungeonId
            break
        end
    end
    if self.m_defaultLookDungeonId == nil then
        self.m_defaultLookDungeonId = list[CSIndex(dungeonDifficultyCount)]
    end
    self.m_difficultyList:Refresh(dungeonDifficultyCount, function(difficulty, index)
        local dungeonId = list[CSIndex(index)]
        self:_FillSingleDifficulty(difficulty, dungeonId)
    end)
    self:_SetCommonWidget(markRuntimeData.isActive)
end
MapMarkDetailDungeonCtrl._SetCommonWidget = HL.Method(HL.Boolean) << function(self, isActive)
    self.view.detailCommon.gameObject:SetActive(true)
    local commonArgs = {}
    commonArgs.markInstId = self.m_markInstId
    commonArgs.titleText = self.m_dungeonSeriesData.name
    commonArgs.descText = self.m_dungeonSeriesData.desc
    if not isActive or self.m_type ~= GEnums.MarkType.DungeonResource then
        commonArgs.bigBtnActive = true
    else
        commonArgs.leftBtnActive = true
        commonArgs.leftBtnText = Language["ui_mapmarkdetail_button_enter"]
        commonArgs.leftBtnCallback = function()
            PhaseManager:GoToPhase(PhaseId.DungeonEntry, { dungeonSeriesId = self.m_dungeonSeriesId })
        end
        commonArgs.leftBtnIconName = UIConst.MAP_DETAIL_BTN_ICON_NAME.FAST_ENTER
        commonArgs.rightBtnActive = true
    end
    self.view.detailCommon:InitMapMarkDetailCommon(commonArgs)
end
MapMarkDetailDungeonCtrl._FillSingleDifficulty = HL.Method(HL.Any, HL.Any) << function(self, difficulty, dungeonId)
    difficulty.m_rewardActive = (dungeonId == self.m_defaultLookDungeonId)
    local getDungeonInfoSuccess, dungeonCfg = Tables.dungeonTable:TryGetValue(dungeonId)
    if not getDungeonInfoSuccess then
        logger.error("无法获取到副本数据，dungeonId为" .. dungeonId)
        return
    end
    if not difficulty.m_rewardList then
        difficulty.m_rewardList = UIUtils.genCellCache(difficulty.itemReward)
    end
    difficulty.difficultyText.text = dungeonCfg.dungeonLevelDesc
    local resourceDungeon = (self.m_type == GEnums.MarkType.DungeonResource)
    if resourceDungeon then
        difficulty.accomplishText.gameObject:SetActive(false)
    else
        local curDungeonAccomplish = GameInstance.dungeonManager:IsDungeonPassed(dungeonId)
        difficulty.accomplishText.gameObject:SetActive(curDungeonAccomplish)
    end
    local dungeonMgr = GameInstance.dungeonManager
    local gameMechanicData = Tables.gameMechanicTable[dungeonId]
    local rewardTable = {}
    local hasMainReward = not string.isEmpty(gameMechanicData.rewardId)
    if hasMainReward then
        local mainRewardsTbl = self:_ProcessRewards(gameMechanicData.rewardId, false)
        for i = 1, #mainRewardsTbl do
            table.insert(rewardTable, mainRewardsTbl[i])
        end
    end
    local hasFirstReward = not string.isEmpty(gameMechanicData.firstPassRewardId)
    if hasFirstReward then
        local rewardId = gameMechanicData.firstPassRewardId
        local firstRewardGained = dungeonMgr:IsDungeonPassed(dungeonId)
        local firstRewardsTbl = self:_ProcessRewards(rewardId, firstRewardGained)
        for i = 1, #firstRewardsTbl do
            table.insert(rewardTable, firstRewardsTbl[i])
        end
    end
    local hasExtraReward = not string.isEmpty(gameMechanicData.extraRewardId)
    if hasExtraReward then
        local rewardId = gameMechanicData.extraRewardId
        local gained = dungeonMgr:IsDungeonExtraRewardGained(dungeonId)
        local extraRewardTbl = self:_ProcessRewards(rewardId, gained)
        for i = 1, #extraRewardTbl do
            table.insert(rewardTable, extraRewardTbl[i])
        end
    end
    difficulty.m_rewardList:Refresh(#rewardTable, function(cell, index)
        self:_UpdateRewardCell(cell, rewardTable[index])
    end)
    difficulty.switchBtn.onClick:AddListener(function()
        difficulty.m_rewardActive = not difficulty.m_rewardActive
        self:_RefreshDifficultyFold(difficulty)
    end)
    self:_RefreshDifficultyFold(difficulty)
end
MapMarkDetailDungeonCtrl._RefreshDifficultyFold = HL.Method(HL.Any) << function(self, difficulty)
    difficulty.rewardList.gameObject:SetActive(difficulty.m_rewardActive)
    difficulty.switchIconUp.gameObject:SetActive(difficulty.m_rewardActive)
    difficulty.switchIconDown.gameObject:SetActive(not difficulty.m_rewardActive)
end
MapMarkDetailDungeonCtrl._ProcessRewards = HL.Method(HL.String, HL.Boolean).Return(HL.Table) << function(self, rewardId, gained)
    local rewardsTbl = {}
    local rewardsCfg = Tables.rewardTable[rewardId]
    for _, itemBundle in pairs(rewardsCfg.itemBundles) do
        local itemCfg = Tables.itemTable[itemBundle.id]
        table.insert(rewardsTbl, { id = itemBundle.id, count = itemBundle.count, rarity = itemCfg.rarity, sortId1 = itemCfg.sortId1, sortId2 = itemCfg.sortId2, type = itemCfg.type:ToInt(), gained = gained, })
    end
    table.sort(rewardsTbl, Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS))
    return rewardsTbl
end
MapMarkDetailDungeonCtrl._UpdateRewardCell = HL.Method(HL.Any, HL.Table) << function(self, cell, info)
    cell:InitItem(info, true)
    cell.view.rewardedCover.gameObject:SetActiveIfNecessary(info.gained)
end
HL.Commit(MapMarkDetailDungeonCtrl)