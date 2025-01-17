local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
FacCacheRepository = HL.Class('FacCacheRepository', UIWidgetBase)
FacCacheRepository._OnFirstTimeInit = HL.Override() << function(self)
    self.m_slotList = UIUtils.genCellCache(self.view.slotCell)
    self:_InitRepositoryDrop()
end
FacCacheRepository._OnDestroy = HL.Override() << function(self)
    self:_ClearRepositoryCache()
end
FacCacheRepository.InitFacCacheRepository = HL.Method(HL.Table) << function(self, repoData)
    self:_FirstTimeInit()
    if repoData == nil then
        return
    end
    if self.m_cacheInitialized then
        self:_ClearRepositoryCache()
    end
    self.m_onCacheChanged = function(changedItems, hasNewOrRemove)
        self:_OnCacheChanged(changedItems, hasNewOrRemove)
    end
    self.m_cache = repoData.cache
    self.m_isInCache = repoData.isInCache
    self.m_isFluidCache = repoData.isFluidCache or false
    self.m_cacheIndex = repoData.cacheIndex
    self.m_slotCount = repoData.slotCount
    self.m_currFormulaId = repoData.formulaId or ""
    self.m_lastFormulaId = repoData.lastFormulaId or ""
    self.m_lockFormulaId = repoData.lockFormulaId or ""
    self.m_fakeFormulaDataList = repoData.fakeFormulaDataList
    self.m_cacheChangedCallback = repoData.cacheChangedCallback or function()
    end
    self.m_producerInfo = repoData.producerInfo
    self.m_itemInfoList = {}
    self:_InitRepositoryCache()
    self:_RefreshRepository()
end
FacCacheRepository._RefreshRepository = HL.Method() << function(self)
    self:_RefreshRepositoryItemInfoList()
    self:_RefreshRepositorySlotList()
end
FacCacheRepository.m_isInCache = HL.Field(HL.Boolean) << false
FacCacheRepository.m_isFluidCache = HL.Field(HL.Boolean) << false
FacCacheRepository.m_cache = HL.Field(CS.Beyond.Gameplay.RemoteFactory.FBUtil.Cache)
FacCacheRepository.m_hasEmptySlot = HL.Field(HL.Boolean) << false
FacCacheRepository.m_cacheIndex = HL.Field(HL.Number) << -1
FacCacheRepository.m_cacheInitialized = HL.Field(HL.Boolean) << false
FacCacheRepository.m_onCacheChanged = HL.Field(HL.Function)
FacCacheRepository.m_cacheChangedCallback = HL.Field(HL.Function)
FacCacheRepository.m_producerInfo = HL.Field(HL.Userdata)
FacCacheRepository._InitRepositoryCache = HL.Method() << function(self)
    if self.m_cacheInitialized then
        return
    end
    if self.m_cache == nil then
        return
    end
    self.m_cache.onCacheChanged:AddListener(self.m_onCacheChanged)
    if self.m_cacheChangedCallback ~= nil then
        self.m_cacheChangedCallback(self.m_cache)
    end
    self.m_cacheInitialized = true
end
FacCacheRepository._ClearRepositoryCache = HL.Method() << function(self)
    if not self.m_cacheInitialized then
        return
    end
    if self.m_cache == nil then
        return
    end
    self.m_cache.onCacheChanged:RemoveListener(self.m_onCacheChanged)
    self.m_cacheInitialized = false
end
FacCacheRepository._OnCacheChanged = HL.Method(HL.Userdata, HL.Boolean) << function(self, changedItems, hasNewOrRemove)
    if hasNewOrRemove then
        self:_RefreshRepository()
        for _, id in pairs(changedItems) do
            local count = self.m_cache:GetCount(id)
            CS.Beyond.Gameplay.Conditions.OnFacCurMachineCacheAddItem.Trigger(id, count, self.m_isInCache)
        end
    else
        for _, id in pairs(changedItems) do
            local count = self.m_cache:GetCount(id)
            self:_RefreshRepositorySlotCellInfo(id, count)
            CS.Beyond.Gameplay.Conditions.OnFacCurMachineCacheAddItem.Trigger(id, count, self.m_isInCache)
        end
    end
    if self.m_cacheChangedCallback ~= nil then
        self.m_cacheChangedCallback(self.m_cache)
    end
end
FacCacheRepository.m_currFormulaId = HL.Field(HL.String) << ""
FacCacheRepository.m_lastFormulaId = HL.Field(HL.String) << ""
FacCacheRepository.m_lockFormulaId = HL.Field(HL.String) << ""
FacCacheRepository.m_fakeFormulaDataList = HL.Field(HL.Table)
FacCacheRepository._GetCacheCraftItemDataList = HL.Method().Return(HL.Table) << function(self)
    local formulaId = string.isEmpty(self.m_currFormulaId) and self.m_lastFormulaId or self.m_currFormulaId
    if string.isEmpty(formulaId) then
        return nil
    end
    local result = {}
    if self.m_fakeFormulaDataList ~= nil then
        for _, craftInfo in pairs(self.m_fakeFormulaDataList) do
            if craftInfo.craftId == formulaId then
                local craftItemList = self.m_isInCache and craftInfo.incomes or craftInfo.outcomes
                if craftItemList ~= nil then
                    for _, craftItemData in pairs(craftItemList) do
                        table.insert(result, { id = craftItemData.id, count = craftItemData.count })
                    end
                end
            end
        end
    else
        local craftData = Tables.factoryMachineCraftTable:GetValue(formulaId)
        local craftItemList = self.m_isInCache and craftData.ingredients or craftData.outcomes
        local itemBundleGroup = craftItemList[CSIndex(self.m_cacheIndex)]
        for index = 0, itemBundleGroup.group.Count - 1 do
            local itemBundle = itemBundleGroup.group[index]
            if itemBundle ~= nil then
                table.insert(result, { id = itemBundle.id, count = itemBundle.count, })
            end
        end
    end
    return result
end
FacCacheRepository._InsertEmptyItemFromCache = HL.Method(HL.Table) << function(self, itemInfoList)
    local craftItemDataList = self:_GetCacheCraftItemDataList()
    if craftItemDataList == nil then
        return
    end
    if self.m_cacheIndex > #craftItemDataList then
        return
    end
    for _, itemData in pairs(craftItemDataList) do
        local id = itemData.id
        local isFluid = FactoryUtils.isFactoryItemFluid(id)
        if self.m_cache:GetCount(id) == 0 and #itemInfoList < self.m_slotCount and isFluid == self.m_isFluidCache then
            table.insert(itemInfoList, { id = id, count = 0, maxStackCount = math.maxinteger, })
        end
    end
end
FacCacheRepository.m_itemInfoList = HL.Field(HL.Table)
FacCacheRepository.m_slotCount = HL.Field(HL.Number) << 0
FacCacheRepository.m_slotList = HL.Field(HL.Forward('UIListCache'))
FacCacheRepository._CreateRepositoryItemInfo = HL.Method(HL.String, HL.Number).Return(HL.Table) << function(self, id, count)
    local itemSuccess, data = Tables.itemTable:TryGetValue(id)
    local facItemSuccess, facItemData = Tables.factoryItemTable:TryGetValue(id)
    if not itemSuccess or not facItemSuccess then
        return nil
    end
    local info = { id = id, count = count, data = data, maxStackCount = facItemData.buildingBufferStackLimit, showingType = data.showingType, facItemData = facItemData, }
    return info
end
FacCacheRepository._GetRepositoryItemSortMap = HL.Method().Return(HL.Table) << function(self)
    local craftItemDataList = self:_GetCacheCraftItemDataList()
    if craftItemDataList == nil then
        return {}
    end
    if self.m_cacheIndex > #craftItemDataList then
        return {}
    end
    local sortIdMap = {}
    for index, itemData in ipairs(craftItemDataList) do
        if itemData ~= nil then
            sortIdMap[itemData.id] = index
        end
    end
    return sortIdMap
end
FacCacheRepository._RefreshRepositoryItemInfoList = HL.Method() << function(self)
    if not self.m_cache then
        return
    end
    local dirtyItemIdList = {}
    local itemInfoCount = 0
    local items = self.m_cache.items
    local itemOrderMap = self.m_cache.itemOrderMap
    for id, count in cs_pairs(items) do
        local orderSuccess, csIndex = itemOrderMap:TryGetValue(id)
        if orderSuccess then
            local info = self:_CreateRepositoryItemInfo(id, count)
            local currentIndex = LuaIndex(csIndex)
            for originalIndex, originalInfo in pairs(self.m_itemInfoList) do
                if originalInfo.id == id then
                    self.m_itemInfoList[originalIndex] = self.m_itemInfoList[currentIndex]
                end
            end
            self.m_itemInfoList[currentIndex] = info
            dirtyItemIdList[id] = true
        end
    end
    for _, itemInfo in pairs(self.m_itemInfoList) do
        local itemId = itemInfo.id
        if not dirtyItemIdList[itemId] then
            itemInfo.count = 0
        end
        itemInfoCount = itemInfoCount + 1
    end
    if itemInfoCount < self.m_slotCount then
        local tempItemInfoList = {}
        self:_InsertEmptyItemFromCache(tempItemInfoList)
        if #tempItemInfoList == 0 then
            for index = 1, self.m_slotCount do
                if self.m_itemInfoList[index] == nil then
                    self.m_itemInfoList[index] = { id = "" }
                end
            end
        else
            local sortIdMap = self:_GetRepositoryItemSortMap()
            for _, itemInfo in ipairs(tempItemInfoList) do
                itemInfo.sortId = sortIdMap[itemInfo.id]
            end
            table.sort(tempItemInfoList, Utils.genSortFunction({ "sortId" }, true))
            for _, tempItemInfo in ipairs(tempItemInfoList) do
                local id = tempItemInfo.id
                if not dirtyItemIdList[id] then
                    for insertIndex = 1, self.m_slotCount do
                        if self.m_itemInfoList[insertIndex] == nil then
                            self.m_itemInfoList[insertIndex] = tempItemInfo
                            dirtyItemIdList[id] = true
                            break
                        end
                    end
                end
            end
        end
    end
end
FacCacheRepository._RefreshRepositorySlotList = HL.Method() << function(self)
    if self.m_itemInfoList == nil or #self.m_itemInfoList <= 0 then
        return
    end
    local slotCount = #self.m_itemInfoList
    self.m_slotList:Refresh(slotCount, function(cell, index)
        self:_OnRefreshRepositorySlotCell(cell, index)
    end)
end
FacCacheRepository._OnRefreshRepositorySlotCell = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    if cell == nil then
        return
    end
    cell:InitFacCacheSlot({ slotIndex = index, itemInfo = self.m_itemInfoList[index], isFluid = self.m_isFluidCache, cache = self.m_cache, isInCache = self.m_isInCache, lockFormulaId = self.m_lockFormulaId, producerInfo = self.m_producerInfo, })
end
FacCacheRepository._RefreshRepositorySlotCellInfo = HL.Method(HL.String, HL.Number) << function(self, itemId, count)
    local slotIndex
    for index, itemInfo in ipairs(self.m_itemInfoList) do
        if itemInfo.id == itemId then
            slotIndex = index
            if count ~= nil then
                itemInfo.count = count
            end
        end
    end
    if slotIndex == nil then
        return
    end
    local cell = self.m_slotList:GetItem(slotIndex)
    if cell == nil then
        return
    end
    self:_OnRefreshRepositorySlotCell(cell, slotIndex)
end
FacCacheRepository.m_dropHelper = HL.Field(HL.Forward('UIDropHelper'))
FacCacheRepository._InitRepositoryDrop = HL.Method() << function(self)
    self.m_dropHelper = UIUtils.initUIDropHelper(self.view.dropMask, {
        acceptTypes = UIConst.FACTORY_REPO_DROP_ACCEPT_INFO,
        checkAccept = function(dragHelper)
            if not self.m_isInCache then
                return false
            end
            return true
        end,
        onDropItem = function(_, dragHelper)
            self:_TryDropItemToRepository(dragHelper)
        end,
        isDropArea = true,
        quickDropCheckGameObject = self.gameObject,
        dropPriority = 1,
    })
end
FacCacheRepository._TryDropItemToRepository = HL.Method(HL.Forward('UIDragHelper')).Return(HL.Boolean) << function(self, dragHelper)
    for index = 1, self.m_slotList:GetCount() do
        local cell = self.m_slotList:GetItem(index)
        if cell ~= nil then
            local result = cell:TryDropItem(dragHelper)
            if result == true then
                return true
            end
        end
    end
    return false
end
FacCacheRepository.UpdateRepositoryFormula = HL.Method(HL.String, HL.Opt(HL.String)) << function(self, formulaId, lastFormulaId)
    self.m_currFormulaId = formulaId
    self.m_lastFormulaId = lastFormulaId or ""
    self:_RefreshRepository()
end
FacCacheRepository.RefreshRepositoryBlockState = HL.Method(HL.Boolean) << function(self, isBlocked)
    if self.m_slotList == nil then
        return
    end
    for index = 1, self.m_slotList:GetCount() do
        local cell = self.m_slotList:GetItem(index)
        if cell ~= nil then
            cell:RefreshSlotBlockState(isBlocked)
        end
    end
end
FacCacheRepository.GetRepositorySlotList = HL.Method().Return(HL.Table) << function(self)
    local lineList = {}
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.repositoryContent)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.slotList)
    for index = 1, self.m_slotList:GetCount() do
        local cell = self.m_slotList:GetItem(index)
        if cell ~= nil then
            table.insert(lineList, cell)
        end
    end
    return lineList
end
FacCacheRepository.TryDropItemToRepository = HL.Method(HL.Forward('UIDragHelper')).Return(HL.Boolean) << function(self, dragHelper)
    return self:_TryDropItemToRepository(dragHelper)
end
FacCacheRepository.GetIsFluidCache = HL.Method().Return(HL.Boolean) << function(self)
    return self.m_isFluidCache
end
HL.Commit(FacCacheRepository)
return FacCacheRepository