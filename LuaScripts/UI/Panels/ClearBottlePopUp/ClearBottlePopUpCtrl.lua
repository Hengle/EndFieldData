local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.ClearBottlePopUp
ClearBottlePopUpCtrl = HL.Class('ClearBottlePopUpCtrl', uiCtrl.UICtrl)
local CAPACITY_TEXT_ID = "LUA_ITEM_TIPS_LIQUID_INFO_FULL_CAPACITY"
local CLEAR_TIPS_TEXT_ID = "LUA_CLEAR_BOTTLE_POPUP_TIPS_TEXT"
ClearBottlePopUpCtrl.m_itemBagIndex = HL.Field(HL.Number) << -1
ClearBottlePopUpCtrl.m_fromDepot = HL.Field(HL.Boolean) << false
ClearBottlePopUpCtrl.m_itemId = HL.Field(HL.String) << ""
ClearBottlePopUpCtrl.m_itemCount = HL.Field(HL.Number) << -1
ClearBottlePopUpCtrl.s_messages = HL.StaticField(HL.Table) << {}
ClearBottlePopUpCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_itemBagIndex = arg.slotIndex
    self.m_itemId = arg.itemId
    self.m_itemCount = arg.itemCount
    if arg.fromDepot == nil then
        self.m_fromDepot = false
    else
        self.m_fromDepot = arg.fromDepot
    end
    self.view.confirmBtn.onClick:AddListener(function()
        self:_OnConfirmBtnClicked()
    end)
    self.view.cancelBtn.onClick:AddListener(function()
        self:PlayAnimationOutAndClose()
    end)
    self:_RefreshPopupContent()
end
ClearBottlePopUpCtrl._OnPanelInputBlocked = HL.Override(HL.Boolean) << function(self, active)
    if not active then
        self:PlayAnimationOutAndClose()
    end
end
ClearBottlePopUpCtrl._OnConfirmBtnClicked = HL.Method() << function(self)
    local scope = Utils.getCurrentScope()
    local chapterId = Utils.getCurrentChapterId()
    if self.m_fromDepot then
        GameInstance.player.inventory:DumpBottleInDepot(self.m_itemId, self.m_itemCount, scope, chapterId)
    else
        GameInstance.player.inventory:DumpBottleInItemBag(self.m_itemBagIndex, self.m_itemCount, scope)
    end
    self:PlayAnimationOutAndClose()
end
ClearBottlePopUpCtrl._RefreshPopupContent = HL.Method() << function(self)
    local fullBottleSuccess, fullBottleData = Tables.fullBottleTable:TryGetValue(self.m_itemId)
    if not fullBottleSuccess then
        return
    end
    local bottleItemId, liquidItemId = fullBottleData.emptyBottleId, fullBottleData.liquidId
    local bottleCapacity = fullBottleData.liquidCapacity
    local bottleSuccess, bottleData = Tables.itemTable:TryGetValue(bottleItemId)
    local liquidSuccess, liquidData = Tables.itemTable:TryGetValue(liquidItemId)
    if not bottleSuccess or not liquidSuccess then
        return
    end
    self.view.bottleNameTxt.text = bottleData.name
    self.view.bottleRarityLine.color = UIUtils.getItemRarityColor(bottleData.rarity)
    local bottleSprite = self:LoadSprite(UIConst.UI_SPRITE_ITEM_BIG, bottleData.iconId)
    if bottleSprite ~= nil then
        self.view.bottleItemIcon.sprite = bottleSprite
    end
    local liquidInfoNode = self.view.liquidInfoNode
    liquidInfoNode.nameTxt.text = liquidData.name
    local liquidCount = bottleCapacity * self.m_itemCount
    liquidInfoNode.capacityTxt.text = string.format(Language[CAPACITY_TEXT_ID], liquidCount)
    liquidInfoNode.rarityLine.color = UIUtils.getItemRarityColor(liquidData.rarity)
    local liquidSprite = self:LoadSprite(UIConst.UI_SPRITE_ITEM, liquidData.iconId)
    if liquidSprite ~= nil then
        liquidInfoNode.icon.sprite = liquidSprite
    end
    self.view.tipsTxt.text = string.format(Language[CLEAR_TIPS_TEXT_ID], liquidCount, liquidData.name)
    self.view.sourceItem:InitItem({ id = self.m_itemId, count = self.m_itemCount }, true)
    self.view.targetItem:InitItem({ id = bottleItemId, count = self.m_itemCount }, true)
end
HL.Commit(ClearBottlePopUpCtrl)