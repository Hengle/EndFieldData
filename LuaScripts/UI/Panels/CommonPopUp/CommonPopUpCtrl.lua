local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CommonPopUp
CommonPopUpCtrl = HL.Class('CommonPopUpCtrl', uiCtrl.UICtrl)
CommonPopUpCtrl.s_messages = HL.StaticField(HL.Table) << {}
CommonPopUpCtrl.m_getItemCell = HL.Field(HL.Function)
CommonPopUpCtrl.m_getCharIconCell = HL.Field(HL.Function)
CommonPopUpCtrl.m_timeScaleHandler = HL.Field(HL.Number) << 0
CommonPopUpCtrl.m_focusItemBindingId = HL.Field(HL.Number) << -1
CommonPopUpCtrl.m_inputFieldText = HL.Field(HL.String) << ""
CommonPopUpCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.confirmButton.onClick:AddListener(function()
        self:_OnClickConfirm()
    end)
    self.view.cancelButton.onClick:AddListener(function()
        self:_OnClickCancel()
    end)
    self.m_getItemCell = UIUtils.genCachedCellFunction(self.view.itemScrollList)
    self.view.itemScrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateItemCell(self.m_getItemCell(obj), LuaIndex(csIndex))
    end)
    self.view.itemScrollList.onCellSelectedChanged:AddListener(function(obj, csIndex, isSelected)
        local cell = self.m_getItemCell(obj)
        if cell then
            cell:SetSelected(isSelected)
        end
    end)
    UIUtils.bindInputPlayerAction("common_view_item", function()
        self:_ShowItemTips()
    end, self.view.itemScrollListInputBindingGroupMonoTarget.groupId)
    UIUtils.bindInputPlayerAction("common_cancel", function()
        self:_UnFocusItemList()
    end, self.view.itemScrollListInputBindingGroupMonoTarget.groupId)
    self.m_focusItemBindingId = self:BindInputPlayerAction("common_focus_on_item_list", function()
        self:_FocusItemList()
    end)
    self.m_getCharIconCell = UIUtils.genCachedCellFunction(self.view.charIconScrollList)
    self.view.charIconScrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCharIconCell(self.m_getCharIconCell(obj), LuaIndex(csIndex))
    end)
    self.view.inputField.characterLimit = UIConst.INPUT_FIELD_CHARACTER_LIMIT
    self.view.inputField.onValueChanged:AddListener(function(text)
        self.m_inputFieldText = text
    end)
    self.view.inputField.onValidateInput = function(text, charIndex, addedChar)
        return self:_ValidateInput(addedChar)
    end
    self.view.controllerHintPlaceholder:InitControllerHintPlaceholder({ self.view.inputGroup.groupId })
end
CommonPopUpCtrl.OnHide = HL.Override() << function(self)
    self:_ResumeWorld()
    self.m_args = nil
end
CommonPopUpCtrl.OnClose = HL.Override() << function(self)
    self:_ResumeWorld()
    self.m_args = nil
end
CommonPopUpCtrl._ValidateInput = HL.Method(HL.Number).Return(HL.Any) << function(self, addedChar)
    local tmpInput = self.m_inputFieldText .. utf8.char(addedChar)
    local length = I18nUtils.GetTextRealLength(tmpInput)
    if length > UIConst.INPUT_FIELD_CHARACTER_LIMIT then
        self.view.inputField.isLastKeyBackspace = true
        return ""
    else
        return addedChar
    end
end
CommonPopUpCtrl._FreezeWorld = HL.Method() << function(self)
    self:_ResumeWorld()
    self.m_timeScaleHandler = TimeManagerInst:StartChangeTimeScale(0)
    if self.m_args.freezeServer == true then
        GameInstance.gameplayNetwork:SendPauseWorldByUI(true)
    end
end
CommonPopUpCtrl._ResumeWorld = HL.Method() << function(self)
    if self.m_timeScaleHandler > 0 then
        TimeManagerInst:StopChangeTimeScale(self.m_timeScaleHandler)
        self.m_timeScaleHandler = 0
        if self.m_args.freezeServer == true then
            GameInstance.gameplayNetwork:SendPauseWorldByUI(false)
        end
    end
end
CommonPopUpCtrl.ShowPopUp = HL.StaticMethod(HL.Table) << function(args)
    local ctrl = CommonPopUpCtrl.AutoOpen(PANEL_ID, nil, false)
    ctrl:_ShowPopUp(args)
end
CommonPopUpCtrl.m_args = HL.Field(HL.Table)
CommonPopUpCtrl._ShowPopUp = HL.Method(HL.Table) << function(self, args)
    Notify(MessageConst.HIDE_ITEM_TIPS)
    self.m_args = args
    self.view.contentText.text = UIUtils.resolveTextStyle(args.content)
    if args.subContent then
        self.view.subText.text = UIUtils.resolveTextStyle(args.subContent)
        self.view.subText.gameObject:SetActiveIfNecessary(true)
    else
        self.view.subText.gameObject:SetActiveIfNecessary(false)
    end
    if args.warningContent then
        self.view.warningNode.warningText.text = UIUtils.resolveTextStyle(args.warningContent)
        self.view.warningNode.gameObject:SetActive(true)
    else
        self.view.warningNode.gameObject:SetActive(false)
    end
    self.view.confirmButton.text = args.confirmText or Language.LUA_CONFIRM
    self.view.cancelButton.text = args.cancelText or Language.LUA_CANCEL
    local hideCancel = args.hideCancel == true
    self.view.cancelButton.gameObject:SetActive(not hideCancel)
    self.view.oneBtnBg.gameObject:SetActive(hideCancel)
    self.view.twoBtnBg.gameObject:SetActive(not hideCancel)
    self.view.blurWithUI.gameObject:SetActive(not args.hideBlur)
    if self.m_args.items then
        self.view.itemScrollList.gameObject:SetActive(true)
        self.view.itemScrollList:UpdateCount(#self.m_args.items)
        InputManagerInst:ToggleBinding(self.m_focusItemBindingId, true)
    else
        self.view.itemScrollList.gameObject:SetActive(false)
        InputManagerInst:ToggleBinding(self.m_focusItemBindingId, false)
    end
    if self.m_args.charIcons then
        self.view.charIconScrollList.gameObject:SetActiveIfNecessary(true)
        self.view.charIconScrollList:UpdateCount(#self.m_args.charIcons)
    else
        self.view.charIconScrollList.gameObject:SetActiveIfNecessary(false)
    end
    if self.m_args.input then
        self.view.inputField.text = self.m_args.inputName or ""
        self.view.textInput.gameObject:SetActive(true)
    else
        self.view.textInput.gameObject:SetActive(false)
    end
    self.view.equipNode.gameObject:SetActive(self.m_args.equipInstId ~= nil)
    if self.m_args.equipInstId then
        self.view.equipItem:InitEquipItem({ equipInstId = self.m_args.equipInstId, })
    end
    if self.m_args.freezeWorld then
        self:_FreezeWorld()
    end
    if self.m_args.toggle ~= nil then
        self.view.toggle.toggle.onValueChanged:RemoveAllListeners()
        self.view.toggle.toggle.onValueChanged:AddListener(function(isOn)
            local onValueChanged = self.m_args.toggle.onValueChanged
            if onValueChanged ~= nil then
                onValueChanged(isOn)
            end
        end)
        self.view.toggle.toggleText.text = self.m_args.toggle.toggleText
        self.view.toggle.toggle.isOn = self.m_args.toggle.isOn
        self.view.toggle.gameObject:SetActive(true)
    else
        self.view.toggle.gameObject:SetActive(false)
    end
    local costItems = self.m_args.costItems
    local costNode = self.view.costItemNode
    if costItems ~= nil then
        local arrowIndex = self.m_args.convertArrowIndex
        costNode.gameObject:SetActive(true)
        if not costNode.m_cache then
            costNode.m_cache = UIUtils.genCellCache(costNode.costItemCell)
        end
        costNode.m_cache:Refresh(#costItems, function(cell, index)
            local info = costItems[index]
            cell.item:InitItem(info, true)
            if arrowIndex and index > arrowIndex then
                cell.ownCountTxt.text = UIUtils.getNumString(info.ownCount)
            else
                local isEnough = info.ownCount >= info.count
                cell.item.view.count.text = UIUtils.setCountColor(cell.item.view.count.text, not isEnough)
                cell.ownCountTxt.text = UIUtils.setCountColor(UIUtils.getNumString(info.ownCount), not isEnough)
            end
            cell.transform:SetSiblingIndex(CSIndex(index))
        end)
        if arrowIndex then
            costNode.convertArrow.gameObject:SetActive(true)
            costNode.convertArrow.transform:SetSiblingIndex(arrowIndex)
        else
            costNode.convertArrow.gameObject:SetActive(false)
        end
    else
        costNode.gameObject:SetActive(false)
    end
    if InputManagerInst.usingController then
        self:_UnFocusItemList()
    else
        self.view.itemScrollListInputBindingGroupMonoTarget.enabled = true
    end
end
CommonPopUpCtrl._OnUpdateItemCell = HL.Method(HL.Forward("Item"), HL.Number) << function(self, cell, index)
    cell:InitItem(self.m_args.items[index], true)
    if self.m_args.noShowItemCount then
        cell.view.countNode.gameObject:SetActiveIfNecessary(false)
    end
    if self.m_args.showItemName then
        cell.view.name.gameObject:SetActiveIfNecessary(true)
    end
    if self.m_args.itemNames and index <= #self.m_args.itemNames then
        cell.view.name.text = self.m_args.itemNames[index]
    end
    if self.m_args.got then
        cell.view.getNode.gameObject:SetActiveIfNecessary(true)
    end
    cell:SetSelected(InputManagerInst.usingController and CSIndex(index) == self.view.itemScrollList.curSelectedIndex)
end
CommonPopUpCtrl._OnUpdateCharIconCell = HL.Method(HL.Table, HL.Number) << function(self, cell, index)
    cell.headIcon.spriteName = UIConst.UI_ROUND_CHAR_HEAD_PREFIX .. self.m_args.charIcons[index]
end
CommonPopUpCtrl._OnClickConfirm = HL.Method() << function(self)
    local args = self.m_args
    local text = self.view.inputField.text
    self:PlayAnimationOutWithCallback(function()
        self:Hide()
        if args.onConfirm then
            if args.input then
                args.onConfirm(text)
            else
                args.onConfirm()
            end
        end
    end)
end
CommonPopUpCtrl._OnClickCancel = HL.Method() << function(self)
    local onCancel = self.m_args.onCancel
    self:PlayAnimationOutWithCallback(function()
        self:Hide()
        if onCancel then
            onCancel()
        end
    end)
end
CommonPopUpCtrl._ShowItemTips = HL.Method() << function(self)
    local index = LuaIndex(self.view.itemScrollList.curSelectedIndex)
    local cell = self.m_getItemCell(index)
    cell:ShowTips(nil, function()
        cell:SetSelected(true)
    end)
end
CommonPopUpCtrl._FocusItemList = HL.Method() << function(self)
    self.view.itemScrollListInputBindingGroupMonoTarget.enabled = true
    Notify(MessageConst.SHOW_AS_CONTROLLER_SMALL_MENU, { panelId = PANEL_ID, isGroup = true, id = self.view.itemScrollListInputBindingGroupMonoTarget.groupId, hintPlaceholder = self.view.controllerHintPlaceholder, rectTransform = self.view.itemScrollList.transform, })
    self.view.itemScrollList:SetSelectedIndex(0)
end
CommonPopUpCtrl._UnFocusItemList = HL.Method() << function(self)
    self.view.itemScrollListInputBindingGroupMonoTarget.enabled = false
    Notify(MessageConst.CLOSE_CONTROLLER_SMALL_MENU, PANEL_ID)
    self.view.itemScrollList:SetSelectedIndex(-1)
end
HL.Commit(CommonPopUpCtrl)