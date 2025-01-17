local wikiDetailBaseCtrl = require_ex('UI/Panels/WikiDetailBase/WikiDetailBaseCtrl')
local PANEL_ID = PanelId.WikiMonster
WikiMonsterCtrl = HL.Class('WikiMonsterCtrl', wikiDetailBaseCtrl.WikiDetailBaseCtrl)
WikiMonsterCtrl.m_abilityListCache = HL.Field(HL.Forward("UIListCache"))
WikiMonsterCtrl.m_distributionListCache = HL.Field(HL.Forward("UIListCache"))
WikiMonsterCtrl.m_dropListCache = HL.Field(HL.Forward("UIListCache"))
WikiMonsterCtrl.m_dropItemSortFunc = HL.Field(HL.Function) << nil
WikiMonsterCtrl.OnCreate = HL.Override(HL.Any) << function(self, args)
    self.m_abilityListCache = UIUtils.genCellCache(self.view.right.abilityDescNode)
    self.m_distributionListCache = UIUtils.genCellCache(self.view.right.distributionNode)
    self.m_dropListCache = UIUtils.genCellCache(self.view.right.itemSmallBlack)
    WikiMonsterCtrl.Super.OnCreate(self, args)
end
WikiMonsterCtrl.GetPanelId = HL.Override().Return(HL.Number) << function(self)
    return PANEL_ID
end
WikiMonsterCtrl._OnPhaseItemBind = HL.Override() << function(self)
    WikiMonsterCtrl.Super._OnPhaseItemBind(self)
    self:_RefreshModel(true)
end
WikiMonsterCtrl._RefreshModel = HL.Method(HL.Opt(HL.Boolean)) << function(self, playInAnim)
    if self.m_phase then
        self.m_phase:ShowModel(self.m_wikiEntryShowData, { playInAnim = playInAnim, })
        self.m_phase:ActiveEntryVirtualCamera(true)
    end
end
WikiMonsterCtrl._RefreshCenter = HL.Override() << function(self)
    WikiMonsterCtrl.Super._RefreshCenter(self)
    self:_RefreshModel()
end
WikiMonsterCtrl._RefreshRight = HL.Override() << function(self)
    local monsterTemplateId = self.m_wikiEntryShowData.wikiEntryData.refMonsterTemplateId
    local _, monsterDisplayData = Tables.enemyTemplateDisplayInfoTable:TryGetValue(monsterTemplateId)
    if not monsterDisplayData then
        return
    end
    local abilityDescList = {}
    if monsterDisplayData.abilityDescIds then
        for _, abilityDescId in pairs(monsterDisplayData.abilityDescIds) do
            local abilityInfo = Tables.EnemyAbilityDescTable[abilityDescId]
            if abilityInfo and abilityInfo.description then
                table.insert(abilityDescList, abilityInfo.description)
            end
        end
    end
    self.m_abilityListCache:Refresh(#abilityDescList, function(cell, index)
        local abilityDesc = abilityDescList[index]
        cell.abilityDescText.text = UIUtils.resolveTextStyle(abilityDesc)
    end)
    local distributionInfos = {}
    if monsterDisplayData.distributionIds then
        for _, distributionId in pairs(monsterDisplayData.distributionIds) do
            local distributionInfo = Tables.DistributionInfoTable[distributionId]
            if distributionInfo then
                if not distributionInfo.jumpId or string.isEmpty(distributionInfo.jumpId) or Utils.canJumpToSystem(distributionInfo.jumpId) then
                    table.insert(distributionInfos, distributionInfo)
                end
            end
        end
    end
    local distributionCnt = #distributionInfos
    self.view.distributionTitle.gameObject:SetActive(distributionCnt ~= 0)
    self.m_distributionListCache:Refresh(distributionCnt, function(cell, index)
        local distributionInfo = distributionInfos[index]
        if distributionInfo.jumpId and not string.isEmpty(distributionInfo.jumpId) then
            cell.jumpSiteText.text = distributionInfo.areaName
            cell.siteBtn.gameObject:SetActive(true)
            cell.unableToJumpNode.gameObject:SetActive(false)
            cell.siteBtn.onClick:RemoveAllListeners()
            cell.siteBtn.onClick:AddListener(function()
                Utils.jumpToSystem(distributionInfo.jumpId)
            end)
        else
            cell.siteTxt.text = distributionInfo.areaName
            cell.siteBtn.gameObject:SetActive(false)
            cell.unableToJumpNode.gameObject:SetActive(true)
        end
    end)
    local dropItemInfos = {}
    local enemyDropData
    local hasValue
    hasValue, enemyDropData = Tables.wikiEnemyDropTable:TryGetValue(monsterTemplateId)
    if hasValue and enemyDropData and enemyDropData.dropItemIds then
        local rawDropIds = enemyDropData.dropItemIds
        for index, dropItemId in pairs(rawDropIds) do
            local dropItemData = Tables.itemTable:GetValue(dropItemId)
            local dropItemInfo = { id = dropItemData.id, rarity = dropItemData.rarity, sortId1 = dropItemData.sortId1, sortId2 = dropItemData.sortId2, }
            dropItemInfos[LuaIndex(index)] = dropItemInfo
        end
        if not self.m_dropItemSortFunc then
            self.m_dropItemSortFunc = Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS, true)
        end
        table.sort(dropItemInfos, self.m_dropItemSortFunc)
    end
    local dropItemCnt = #dropItemInfos
    self.view.dropTitle.gameObject:SetActive(dropItemCnt ~= 0)
    self.m_dropListCache:Refresh(dropItemCnt, function(cell, index)
        local dropItemInfo = dropItemInfos[index]
        cell:InitItem({ id = dropItemInfo.id }, true)
        cell:SetExtraInfo(self.m_itemTipsPosInfo)
    end)
end
HL.Commit(WikiMonsterCtrl)