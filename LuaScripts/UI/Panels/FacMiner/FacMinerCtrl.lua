local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local FactoryGlobalUnlockIndex = FacCoreNS.FactoryGlobalUnlockIndex
local MinerOutputMode = FacCoreNS.MinerOutputMode
local PANEL_ID = PanelId.FacMiner
FacMinerCtrl = HL.Class('FacMinerCtrl', uiCtrl.UICtrl)
local MAX_MINE_PROGRESS_EFFICIENCY = 100
local ARROW_ANIMATION_NAME = "facmac_decoarrow_loop"
FacMinerCtrl.s_messages = HL.StaticField(HL.Table) << {}
FacMinerCtrl.m_nodeId = HL.Field(HL.Any)
FacMinerCtrl.m_uiInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_Collector)
FacMinerCtrl.m_wirelessModeValid = HL.Field(HL.Boolean) << false
FacMinerCtrl.m_itemDepotMaxStackCount = HL.Field(HL.Number) << -1
FacMinerCtrl.m_isBlocked = HL.Field(HL.Boolean) << false
FacMinerCtrl.m_wirelessModeUpdateThread = HL.Field(HL.Thread)
FacMinerCtrl.m_progressUpdateThread = HL.Field(HL.Thread)
FacMinerCtrl.m_progressInitUpdateThread = HL.Field(HL.Thread)
FacMinerCtrl.m_cache = HL.Field(HL.Userdata)
FacMinerCtrl.m_onCacheChanged = HL.Field(HL.Function)
FacMinerCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_uiInfo = arg.uiInfo
    local nodeId = self.m_uiInfo.nodeId
    self.m_nodeId = nodeId
    local buildingId = self.m_uiInfo.buildingId
    local success, data = Tables.itemTable:TryGetValue(self.m_uiInfo.collectingItemId)
    if success then
        self.m_itemDepotMaxStackCount = data.maxStackCount
    end
    self:_InitInventoryArea()
    self:_InitFacCacheRepository()
    self:_RefreshFormulaInfo()
    self:_InitWirelessModeNode()
    self:_InitProgressNode()
    self.view.buildingCommon:InitBuildingCommon(self.m_uiInfo, {
        onStateChanged = function(state)
            self:_OnStateChanged(state)
        end
    })
    local protoData = self.m_uiInfo.protoData
    if (protoData == nil) or (protoData.mineNameId == nil) then
        self.view.mineTypeText.text = ""
    else
        self.view.mineTypeText.text = protoData.mineNameId:GetText()
    end
    if not string.isEmpty(self.m_uiInfo.condition.key) then
        self.view.conditionText.text = Language[self.m_uiInfo.condition.key] or ""
    end
    local buildingData = Tables.factoryBuildingTable:GetValue(buildingId)
    self.view.decoCostPower.gameObject:SetActive(buildingData.powerConsume > 0)
    self.view.decoCostNoPower.gameObject:SetActive(buildingData.powerConsume == 0)
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end
FacMinerCtrl.OnClose = HL.Override() << function(self)
    self:_ClearWirelessModeUpdateThread()
    self:_ClearProgressUpdateThread()
    if self.m_cache ~= nil then
        self.m_cache.onCacheChanged:RemoveListener(self.m_onCacheChanged)
    end
    if self.m_uiInfo.isFluidCollector then
        GameInstance.remoteFactoryManager:UnregisterInterestedUnitId(self.m_uiInfo.nodeId)
    end
end
FacMinerCtrl._isOriginiumOre = HL.Method().Return(HL.Boolean) << function(self)
    return GameInstance.player.facCharacterSystem:IsOriginiumOre(self.m_uiInfo.collectingItemId)
end
FacMinerCtrl._isNotOriginiumOre = HL.Method().Return(HL.Boolean) << function(self)
    return GameInstance.player.facCharacterSystem:IsNotOriginiumOre(self.m_uiInfo.collectingItemId)
end
FacMinerCtrl._OnStateChanged = HL.Method(HL.Userdata) << function(self, state)
    if self.m_wirelessModeValid then
        self.view.wirelessModeNode:RefreshPausedState(state ~= GEnums.FacBuildingState.Normal and state ~= GEnums.FacBuildingState.Idle and state ~= GEnums.FacBuildingState.Blocked)
    end
    self.view.facProgressNode:SwitchAudioPlayingState(state == GEnums.FacBuildingState.Normal)
end
FacMinerCtrl._RefreshFormulaInfo = HL.Method() << function(self)
    self.view.formulaNode:InitFormulaNode(self.m_uiInfo)
    local efficiency = self.m_uiInfo.speedPercentage
    local mineLevel = self.m_uiInfo.mineLevel
    local isHighEfficiency = mineLevel == CS.Beyond.Gameplay.LevelDoodadGroupData.EDoodadGroupLevel.LevelFour
    local targetCraftInfo = FactoryUtils.getBuildingProcessingCraft(self.m_uiInfo)
    if targetCraftInfo == nil then
        self.view.formulaNode:RefreshDisplayFormula()
        self.view.outCacheRepository:UpdateRepositoryFormula("")
        if self.m_uiInfo.isFluidCollector then
            self.view.fluidCacheRepository:UpdateRepositoryFormula("")
        end
        return
    end
    if efficiency > 0 then
        local extraSpeed = MAX_MINE_PROGRESS_EFFICIENCY / efficiency
        targetCraftInfo.time = targetCraftInfo.time * extraSpeed
        local timeColor = isHighEfficiency and self.view.config.HIGH_FORMULA_TIME_COLOR or self.view.config.NORMAL_FORMULA_TIME_COLOR
        self.view.highEfficiencyText.gameObject:SetActive(isHighEfficiency)
        self.view.normalTextNode.gameObject:SetActive(true)
        self.view.invalidTextNode.gameObject:SetActive(false)
        self.view.formulaNode:RefreshDisplayFormula(targetCraftInfo, timeColor)
        self.view.formulaNode:SetExtraFormulaSpeed(extraSpeed)
    else
        self.view.formulaNode:RefreshDisplayFormula(targetCraftInfo)
        self.view.normalTextNode.gameObject:SetActive(false)
        self.view.invalidTextNode.gameObject:SetActive(true)
    end
    self.view.outCacheRepository:UpdateRepositoryFormula(targetCraftInfo.craftId)
    if self.m_uiInfo.isFluidCollector then
        self.view.fluidCacheRepository:UpdateRepositoryFormula(targetCraftInfo.craftId)
    end
    local income = targetCraftInfo.incomes[#targetCraftInfo.incomes]
    self.view.sourceItem:InitItem(income, true)
    self.view.facProgressNode.view.gameObject:SetActive(efficiency > 0)
end
FacMinerCtrl._StartWirelessModeUpdateThread = HL.Method() << function(self)
    self:_UpdateWirelessModeBlockedState(true)
    self.m_wirelessModeUpdateThread = self:_StartCoroutine(function()
        while true do
            coroutine.step()
            self:_UpdateWirelessModeBlockedState()
        end
    end)
end
FacMinerCtrl._ClearWirelessModeUpdateThread = HL.Method() << function(self)
    if self.m_wirelessModeUpdateThread ~= nil then
        self.m_wirelessModeUpdateThread = self:_ClearCoroutine(self.m_wirelessModeUpdateThread)
    end
end
FacMinerCtrl._StartProgressUpdateThread = HL.Method() << function(self)
    self.m_progressUpdateThread = self:_StartCoroutine(function()
        while true do
            coroutine.step()
            self:_UpdateProgressState()
        end
    end)
end
FacMinerCtrl._ClearProgressUpdateThread = HL.Method() << function(self)
    if self.m_progressUpdateThread ~= nil then
        self.m_progressUpdateThread = self:_ClearCoroutine(self.m_progressUpdateThread)
    end
end
FacMinerCtrl._InitWirelessModeNode = HL.Method() << function(self)
    local minerData = Tables.factoryMinerTable[self.m_uiInfo.buildingId]
    if minerData.hasDroneMode then
        self.view.wirelessModeNode:InitWirelessModeNode(self.m_uiInfo, function()
            self:_CheckCacheItemStateOnComplete()
        end)
        self.view.wirelessModeNode.gameObject:SetActive(true)
        self:_StartWirelessModeUpdateThread()
    else
        self.view.wirelessModeNode.gameObject:SetActive(false)
    end
    self.m_wirelessModeValid = minerData.hasDroneMode
end
FacMinerCtrl._CheckCacheItemStateOnComplete = HL.Method() << function(self)
    local items = self.m_uiInfo.cache.items
    if items.Count <= 0 then
        return
    end
    for id, count in cs_pairs(items) do
        if count > 0 then
            local success, itemData = Tables.factoryItemTable:TryGetValue(id)
            if success then
                local depotCount = Utils.getDepotItemCount(id, Utils.getCurrentScope(), Utils.getCurDomainId())
                if depotCount >= itemData.repoStackLimit then
                    Notify(MessageConst.SHOW_TOAST, Language.LUA_FAC_WIRELESS_MODE_BLOCKED_TOAST)
                    break
                end
            end
        end
    end
end
FacMinerCtrl._InitProgressNode = HL.Method() << function(self)
    self:_UpdateProgressInitializedState()
    self.m_progressInitUpdateThread = self:_StartCoroutine(function()
        while true do
            coroutine.wait(UIConst.FAC_COMMON_UI_UPDATE_INTERVAL)
            self:_UpdateProgressInitializedState()
        end
    end)
end
FacMinerCtrl._InitFacCacheRepository = HL.Method() << function(self)
    local cache = self.m_uiInfo.cache
    if self.m_uiInfo.cache then
        self.view.outCacheRepository:InitFacCacheRepository({ cache = self.m_uiInfo.cache, isInCache = false, cacheIndex = 1, slotCount = 1, fakeFormulaDataList = FactoryUtils.getBuildingCrafts(self.m_uiInfo.buildingId) })
    end
    if self.m_uiInfo.isFluidCollector then
        self.view.fluidCacheRepository:InitFacCacheRepository({ cache = self.m_uiInfo.waterCache, isInCache = true, isFluidCache = true, cacheIndex = 1, slotCount = 1, fakeFormulaDataList = FactoryUtils.getBuildingCrafts(self.m_uiInfo.buildingId) })
        self.view.fluidCachePipe:InitFacCachePipe(self.m_uiInfo)
        GameInstance.remoteFactoryManager:RegisterInterestedUnitId(self.m_uiInfo.nodeId)
    end
    self.view.fluidCache.gameObject:SetActive(self.m_uiInfo.isFluidCollector)
    if cache ~= nil then
        self.view.gainBtn.onClick:AddListener(function()
            GameInstance.player.remoteFactory.core:Message_OpMoveItemCacheToBag(Utils.getCurrentChapterId(), cache.componentId, 0, 0, true)
        end)
        self.m_cache = cache
        self.m_onCacheChanged = function(changedItemList, isNew)
            self:_UpdateGainButtonState()
        end
        cache.onCacheChanged:AddListener(self.m_onCacheChanged)
        self:_UpdateGainButtonState()
    end
end
FacMinerCtrl._UpdateGainButtonState = HL.Method() << function(self)
    local findItem = false
    for id, count in pairs(self.m_cache.items) do
        if not string.isEmpty(id) and count > 0 then
            findItem = true
            break
        end
    end
    self.view.gainBtn.interactable = findItem
end
FacMinerCtrl._InitInventoryArea = HL.Method() << function(self)
    local customOnUpdateCell
    if self.m_uiInfo.isFluidCollector then
        customOnUpdateCell = function(cell, itemBundle)
            self:_RefreshInventoryItemCell(cell, itemBundle)
        end
    end
    self.view.inventoryArea:InitInventoryArea({ customOnUpdateCell = customOnUpdateCell })
end
FacMinerCtrl._RefreshInventoryItemCell = HL.Method(HL.Userdata, HL.Any) << function(self, cell, itemBundle)
    if cell == nil or itemBundle == nil then
        return
    end
    local itemId = itemBundle.id
    local isEmptyBottle = Tables.emptyBottleTable:ContainsKey(itemId)
    local isFullBottle = Tables.fullBottleTable:ContainsKey(itemId)
    local isBottle = isEmptyBottle or isFullBottle
    local isEmpty = string.isEmpty(itemBundle.id)
    cell.view.forbiddenMask.gameObject:SetActiveIfNecessary(not isBottle and not isEmpty)
    cell.view.dragItem.enabled = isBottle
    cell.view.dropItem.enabled = isBottle or isEmpty
end
FacMinerCtrl._UpdateWirelessModeBlockedState = HL.Method(HL.Opt(HL.Boolean)) << function(self, forceRefresh)
    if not self.m_wirelessModeValid or string.isEmpty(self.m_uiInfo.collectingItemId) then
        return
    end
    local depotCount = GameInstance.player.inventory:GetItemCountInDepot(Utils.getCurrentScope(), Utils.getCurrentChapterId(), self.m_uiInfo.collectingItemId)
    self.view.wirelessModeNode:RefreshBlockedState(depotCount == self.m_itemDepotMaxStackCount, forceRefresh)
end
FacMinerCtrl._UpdateProgressInitializedState = HL.Method() << function(self)
    if self.m_uiInfo.collector.progressIncreasePerMS == 0 then
        self.view.facProgressNode:InitFacProgressNode(0, 0)
        return
    end
    local totalProgress = self.m_uiInfo.totalProgress
    local time = totalProgress / (self.m_uiInfo.collector.progressIncreasePerMS * 1000)
    local skillBroad = self.m_uiInfo.skillBoard
    local colorStr = ""
    if skillBroad then
        if self:_isOriginiumOre() then
            if skillBroad.minerOrgDeltaScale > 0 then
                colorStr = UIConst.FAC_BUILDING_BUFF_COLOR_STR
            elseif skillBroad.minerOrgDeltaScale < 0 then
                colorStr = UIConst.FAC_BUILDING_DEBUFF_COLOR_STR
            end
        elseif self:_isNotOriginiumOre() then
            if skillBroad.minerUorgDeltaScale > 0 then
                colorStr = UIConst.FAC_BUILDING_BUFF_COLOR_STR
            elseif skillBroad.minerUorgDeltaScale < 0 then
                colorStr = UIConst.FAC_BUILDING_DEBUFF_COLOR_STR
            end
        end
    end
    self.view.facProgressNode:InitFacProgressNode(time, totalProgress, colorStr, function()
        self.view.decoArrow:PlayWithTween(ARROW_ANIMATION_NAME)
    end)
    self.view.facProgressNode:UpdateProgress(self.m_uiInfo.currentProgress)
    self.view.facProgressNode:SwitchAudioPlayingState(true)
    self:_StartProgressUpdateThread()
    self.m_progressInitUpdateThread = self:_ClearCoroutine(self.m_progressInitUpdateThread)
end
FacMinerCtrl._UpdateProgressState = HL.Method() << function(self)
    local currentProgress = self.m_uiInfo.currentProgress
    self.view.facProgressNode:UpdateProgress(currentProgress)
end
HL.Commit(FacMinerCtrl)