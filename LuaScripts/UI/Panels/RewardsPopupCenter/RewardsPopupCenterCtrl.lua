local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.RewardsPopupCenter
RewardsPopupCenterCtrl = HL.Class('RewardsPopupCenterCtrl', uiCtrl.UICtrl)
RewardsPopupCenterCtrl.s_messages = HL.StaticField(HL.Table) << { [MessageConst.INTERRUPT_MAIN_HUD_TOAST] = 'InterruptMainHudToast', }
RewardsPopupCenterCtrl.m_itemList = HL.Field(HL.Forward('UIListCache'))
RewardsPopupCenterCtrl.m_startIndex = HL.Field(HL.Number) << 1
RewardsPopupCenterCtrl.m_items = HL.Field(HL.Table)
RewardsPopupCenterCtrl.m_count = HL.Field(HL.Number) << -1
RewardsPopupCenterCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_itemList = UIUtils.genCellCache(self.view.item)
end
RewardsPopupCenterCtrl.ShowRewardsPopupCenter = HL.StaticMethod(HL.Table) << function(args)
    LuaSystemManager.mainHudToastSystem:AddRequest("CenterRewards", function()
        local ctrl = UIManager:AutoOpen(PANEL_ID, nil, true)
        ctrl:_ShowRewardsPopupCenter(args)
    end)
end
RewardsPopupCenterCtrl.ShowRewardsPopupCenterByRewardId = HL.StaticMethod(HL.Any) << function(args)
    local rewardId
    if type(args) == "table" then
        rewardId = unpack(args)
    else
        rewardId = args
    end
    if not string.isEmpty(rewardId) then
        local succ, rewardData = Tables.rewardTable:TryGetValue(rewardId)
        if succ then
            local param = { items = {}, }
            for _, item in pairs(rewardData.itemBundles) do
                if not string.isEmpty(item.id) then
                    table.insert(param.items, { id = item.id, count = item.count })
                end
            end
            RewardsPopupCenterCtrl.ShowRewardsPopupCenter(param)
        end
    end
end
RewardsPopupCenterCtrl.InterruptMainHudToast = HL.Method() << function(self)
    self.view.animationWrapper:ClearTween(false)
    self:_ClearArgs()
    self:Hide()
end
RewardsPopupCenterCtrl._ShowRewardsPopupCenter = HL.Method(HL.Table) << function(self, args)
    local oriItems, sourceTypeInt
    if args[1] then
        oriItems, sourceTypeInt = unpack(args)
    else
        oriItems = args.items
    end
    local isLuaTable = type(oriItems) == "table"
    local items
    if isLuaTable then
        items = oriItems
    else
        if not items then
            items = {}
            for _, item in pairs(oriItems) do
                table.insert(items, { id = item.id, count = item.count })
            end
        end
    end
    for k = 1, #items do
        local v = items[k]
        if type(v) ~= "table" then
            v = { id = v.id, count = v.count }
        end
        local iData = Tables.itemTable[v.id]
        v.sortId1 = iData.sortId1
        v.sortId2 = iData.sortId2
        v.rarity = iData.rarity
    end
    table.sort(items, Utils.genSortFunction(UIConst.COMMON_ITEM_SORT_KEYS))
    self.m_startIndex = 1
    self.m_items = items
    self.m_count = #items
    self.view.animationWrapper:ClearTween(false)
    self:_ContinueShowRewards()
end
RewardsPopupCenterCtrl._ContinueShowRewards = HL.Method() << function(self)
    local items = self.m_items
    local count = self.m_count
    local startIndex = self.m_startIndex
    local endIndex = math.min(count, startIndex + self.view.config.MAX_SHOW_COUNT - 1)
    self.m_itemList:Refresh(endIndex - startIndex + 1, function(cell, index)
        local itemInfo = items[startIndex + index - 1]
        cell:InitItem(itemInfo)
        UIUtils.setRewardItemRarityGlow(cell, UIUtils.getItemRarity(itemInfo.id))
        cell.view.gameObject:SetActive(false)
        cell.view.gameObject:SetActive(true)
    end)
    self.view.animationWrapper:PlayInAnimation(function()
        if endIndex == count then
            self:_ClearArgs()
            self:Hide()
            Notify(MessageConst.ON_ONE_MAIN_HUD_TOAST_FINISH, "CenterRewards")
        else
            self.m_startIndex = endIndex + 1
            self:_ContinueShowRewards()
        end
    end)
end
RewardsPopupCenterCtrl._ClearArgs = HL.Method() << function(self)
    self.m_startIndex = -1
    self.m_items = nil
    self.m_count = -1
end
HL.Commit(RewardsPopupCenterCtrl)