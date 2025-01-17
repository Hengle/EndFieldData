UIDragHelper = HL.Class('UIDragHelper')
UIDragHelper.info = HL.Field(HL.Table)
UIDragHelper.source = HL.Field(HL.Number) << -1
UIDragHelper.type = HL.Field(HL.Any)
UIDragHelper.uiDragItem = HL.Field(CS.Beyond.UI.UIDragItem)
UIDragHelper.m_enterObj = HL.Field(GameObject)
UIDragHelper.m_enterDropHelper = HL.Field(HL.Forward('UIDropHelper'))
UIDragHelper.UIDragHelper = HL.Constructor(CS.Beyond.UI.UIDragItem, HL.Table) << function(self, uiDragItem, info)
    self.uiDragItem = uiDragItem
    self:RefreshInfo(info)
    uiDragItem.luaTable = { self }
end
UIDragHelper.RefreshInfo = HL.Method(HL.Table) << function(self, info)
    self.info = info
    self.source = self.info.source
    self.type = self.info.type
    self.uiDragItem.onBeginDragEvent:AddListener(function(eventData)
        self:_OnBeginDrag(eventData)
    end)
    self.uiDragItem.onDragEvent:AddListener(function(eventData)
        self:_OnDragging(eventData)
    end)
    self.uiDragItem.onEndDragEvent:AddListener(function(eventData)
        self:_OnEndDrag(eventData)
    end)
end
UIDragHelper.GetId = HL.Method().Return(HL.Any) << function(self)
    local source = self.source
    local info = self.info
    local id
    if source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.Storage then
        local item = info.storage.items[info.csIndex]
        id = item.Item1
    elseif source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.QuickBar then
        id = info.itemId
    elseif source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.ItemBag then
        local itemBundle = GameInstance.player.inventory.itemBag:GetOrFallback(Utils.getCurrentScope()).slots[info.csIndex]
        id = itemBundle.id
    elseif source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.Repository then
        id = info.itemId
    elseif source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.FactoryDepot then
        id = info.itemId
    elseif source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.BuildModeSelect then
        id = info.itemId
    elseif source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.UseItemBar then
        id = info.itemId
    elseif source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.RpgEquipSlot then
        id = info.itemId
    elseif source == UIConst.UI_DRAG_DROP_SOURCE_TYPE.SettlementDefenseShop then
        id = info.itemId
    end
    return id
end
UIDragHelper._OnBeginDrag = HL.Method(CS.UnityEngine.EventSystems.PointerEventData) << function(self, eventData)
    if self.info.onBeginDrag then
        self.info.onBeginDrag(self.m_enterObj, self.m_enterDropHelper)
    end
    self:ClearDraggingData()
    UIUtils.playItemDragAudio(self:GetId())
    Notify(MessageConst.ON_START_UI_DRAG, self)
end
UIDragHelper._OnEndDrag = HL.Method(CS.UnityEngine.EventSystems.PointerEventData) << function(self, eventData)
    if self.info.onEndDrag then
        self.info.onEndDrag(self.m_enterObj, self.m_enterDropHelper, eventData)
    end
    self:ClearDraggingData()
    Notify(MessageConst.ON_END_UI_DRAG, self)
end
UIDragHelper._OnDragging = HL.Method(CS.UnityEngine.EventSystems.PointerEventData) << function(self, eventData)
    local enterObj = eventData.pointerEnter
    if enterObj ~= self.m_enterObj then
        self:ClearDraggingData()
        self.m_enterObj = enterObj
        local dropHelper
        if NotNull(enterObj) then
            local dropItem = enterObj:GetComponentInParent(typeof(CS.Beyond.UI.UIDropItem))
            if dropItem and dropItem.luaTable then
                dropHelper = dropItem.luaTable[1]
                if dropHelper:Accept(self) then
                    self.m_enterDropHelper = dropHelper
                    dropHelper.uiDropItem:ToggleHighlight(true)
                end
            end
        end
        if self.info.onDropTargetChanged then
            self.info.onDropTargetChanged(enterObj, dropHelper)
        end
    end
end
UIDragHelper.ClearDraggingData = HL.Method() << function(self)
    if self.m_enterDropHelper then
        self.m_enterDropHelper.uiDropItem:ToggleHighlight(false)
        self.m_enterDropHelper = nil
    end
    self.m_enterObj = nil
end
HL.Commit(UIDragHelper)
return UIDragHelper