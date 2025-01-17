local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.WeaponExhibitGem
WeaponExhibitGemCtrl = HL.Class('WeaponExhibitGemCtrl', uiCtrl.UICtrl)
WeaponExhibitGemCtrl.s_messages = HL.StaticField(HL.Table) << { [MessageConst.ON_GEM_ATTACH] = 'OnGemAttach', [MessageConst.ON_GEM_DETACH] = 'OnGemDetach', [MessageConst.ON_GEM_RECAST] = "_OnGemRecast", }
WeaponExhibitGemCtrl.m_weaponInfo = HL.Field(HL.Table)
WeaponExhibitGemCtrl.m_weaponExhibitInfo = HL.Field(HL.Table)
WeaponExhibitGemCtrl.m_isCompareOn = HL.Field(HL.Boolean) << false
WeaponExhibitGemCtrl.m_isFocusJump = HL.Field(HL.Boolean) << false
WeaponExhibitGemCtrl.m_curSelectGemInstId = HL.Field(HL.Number) << -1
WeaponExhibitGemCtrl.OnGemAttach = HL.Method(HL.Table) << function(self)
    local weaponInfo = self.m_weaponInfo
    local weaponExhibitInfo = CharInfoUtils.getWeaponExhibitBasicInfo(weaponInfo.weaponTemplateId, weaponInfo.weaponInstId)
    self.m_weaponExhibitInfo = weaponExhibitInfo
    self.view.commonGemHorizontalList:RefreshAllCells()
    self:_RefreshGemCompareNode(weaponExhibitInfo, self.m_curSelectGemInstId)
    AudioAdapter.PostEvent("au_ui_weapon_subjoin")
end
WeaponExhibitGemCtrl.OnGemDetach = HL.Method(HL.Table) << function(self)
    local weaponInfo = self.m_weaponInfo
    local weaponExhibitInfo = CharInfoUtils.getWeaponExhibitBasicInfo(weaponInfo.weaponTemplateId, weaponInfo.weaponInstId)
    self.m_weaponExhibitInfo = weaponExhibitInfo
    self.view.commonGemHorizontalList:RefreshAllCells()
    self:_RefreshGemCompareNode(weaponExhibitInfo, self.m_curSelectGemInstId)
end
WeaponExhibitGemCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    local weaponInfo = arg.weaponInfo
    self.m_weaponInfo = weaponInfo
    self.m_isCompareOn = false
    self.m_isFocusJump = arg.isFocusJump == true
    self:_InitActionEvent()
end
WeaponExhibitGemCtrl._InitActionEvent = HL.Method() << function(self)
    self.view.btnBack.onClick:AddListener(function()
        if self.m_isFocusJump then
            PhaseManager:SendMessageToOpenedPhase(PhaseId.WeaponInfo, MessageConst.P_WEAPON_EXHIBIT_BLEND_EXIT, {
                finishCallback = function()
                    PhaseManager:ExitPhaseFast(PhaseId.WeaponInfo)
                end
            })
            Notify(MessageConst.CLOSE_WEAPON_EXHIBIT_GEM_CARD)
            self:PlayAnimationOut()
            return
        end
        self:Notify(MessageConst.WEAPON_EXHIBIT_PAGE_CHANGE, { pageType = UIConst.WEAPON_EXHIBIT_PAGE_TYPE.OVERVIEW, })
    end)
    self.view.btnReplace.onClick:AddListener(function()
        self:_OnClickReplace()
    end)
    self.view.btnUnload.onClick:AddListener(function()
        self:_OnClickUnload()
    end)
    self.view.btnLoad.onClick:AddListener(function()
        self:_OnClickReplace()
    end)
    self.view.btnEmpty.onClick:AddListener(function()
        if not self.m_isCompareOn then
            return
        end
        self.m_isCompareOn = false
        self:_RefreshGemCompareNode(self.m_weaponExhibitInfo, self.m_curSelectGemInstId)
    end)
    self.view.compareButton.onClick:RemoveAllListeners()
    self.view.compareButton.onClick:AddListener(function()
        self.m_isCompareOn = true
        self:_RefreshGemCompareNode(self.m_weaponExhibitInfo, self.m_curSelectGemInstId)
    end)
    self.view.shrinkButton.onClick:RemoveAllListeners()
    self.view.shrinkButton.onClick:AddListener(function()
        self.m_isCompareOn = false
        self:_RefreshGemCompareNode(self.m_weaponExhibitInfo, self.m_curSelectGemInstId)
    end)
    self.view.gemRecastBtn.onClick:AddListener(function()
        PhaseManager:OpenPhase(PhaseId.GemRecast)
    end)
end
WeaponExhibitGemCtrl.OnShow = HL.Override() << function(self)
    local weaponInfo = self.m_weaponInfo
    local weaponExhibitInfo = CharInfoUtils.getWeaponExhibitBasicInfo(weaponInfo.weaponTemplateId, weaponInfo.weaponInstId)
    local curEquippingGemInstId = weaponExhibitInfo.gemInst and weaponExhibitInfo.gemInst.instId or -1
    self.m_weaponExhibitInfo = weaponExhibitInfo
    self.m_isCompareOn = false
    self.m_curSelectGemInstId = curEquippingGemInstId
    self.view.weaponIntroduction:InitWeaponIntroduction(weaponInfo.weaponTemplateId, weaponInfo.weaponInstId)
    self:_RefreshGemPanel(weaponExhibitInfo)
end
WeaponExhibitGemCtrl._PlayCustomAnimationOut = HL.Method() << function(self)
    UIUtils.PlayAnimationAndToggleActive(self.view.basicInfoNode.animationWrapper, false)
    UIUtils.PlayAnimationAndToggleActive(self.view.gemCellUnselected.animationWrapper, false, function()
        self:Hide()
    end)
end
WeaponExhibitGemCtrl._RefreshGemPanel = HL.Method(HL.Table) << function(self, weaponExhibitInfo)
    self.view.title.text = string.format(Language.LUA_WEAPON_EXHIBIT_GEM_TITLE, weaponExhibitInfo.itemCfg.name)
    self:_RefreshGemCompareNode(weaponExhibitInfo, self.m_curSelectGemInstId)
    self:_RefreshGemList(true, self.m_curSelectGemInstId)
end
WeaponExhibitGemCtrl._OnGemRecast = HL.Method(HL.Table) << function(self)
    self:_RefreshGemPanel(self.m_weaponExhibitInfo)
end
WeaponExhibitGemCtrl._RefreshGemList = HL.Method(HL.Boolean, HL.Opt(HL.Number)) << function(self, skipGraduallyShow, curSelectGemInstId)
    local weaponInstId = self.m_weaponInfo.weaponInstId
    local weaponInst = CharInfoUtils.getWeaponByInstId(weaponInstId)
    local _, weaponSkillList = CS.Beyond.Gameplay.WeaponUtil.TryGetWeaponSkillIdAndLevel(Utils.getCurrentScope(), weaponInstId, nil, weaponInst.breakthroughLv, weaponInst.refineLv)
    self.view.commonGemHorizontalList:InitCommonItemList({
        listType = UIConst.COMMON_ITEM_LIST_TYPE.WEAPON_EXHIBIT_GEM,
        skipGraduallyShow = skipGraduallyShow,
        weaponSkillList = weaponSkillList,
        onClickItem = function(args)
            local itemInfo = args.itemInfo
            if not itemInfo then
                return
            end
            self:_OnSelectNewGem(itemInfo)
        end,
        refreshItemAddOn = function(cell, itemInfo)
            local gemInst = itemInfo.itemInst
            local attachedWeaponInstId = gemInst.weaponInstId
            cell.equipped.gameObject:SetActive(attachedWeaponInstId and attachedWeaponInstId > 0)
            cell.curEquipped.gameObject:SetActive(attachedWeaponInstId and attachedWeaponInstId > 0 and attachedWeaponInstId == self.m_weaponInfo.weaponInstId)
            cell.disableMask.gameObject:SetActive(not itemInfo.enableOnWeapon)
        end,
    })
    if curSelectGemInstId and curSelectGemInstId > 0 and not skipGraduallyShow then
        self.view.commonGemHorizontalList:SetSelectedId(curSelectGemInstId, false)
    end
end
WeaponExhibitGemCtrl._GetButtonState = HL.Method(HL.Table, HL.Number).Return(HL.Boolean, HL.Boolean, HL.Boolean) << function(self, weaponExhibitInfo, selectedGemInstId)
    local isReplace = true
    local isLoad = true
    local isUnload = true
    local isGemSelected = selectedGemInstId ~= nil and selectedGemInstId > 0
    if not isGemSelected then
        isReplace = false
        isLoad = false
        isUnload = false
        return isReplace, isLoad, isUnload
    end
    local curEquippingGemInstId = weaponExhibitInfo.gemInst and weaponExhibitInfo.gemInst.instId or -1
    local isSameGem = self.m_curSelectGemInstId == curEquippingGemInstId
    if isSameGem then
        isReplace = false
    else
        isUnload = false
    end
    local compareGemInst = CharInfoUtils.getGemByInstId(selectedGemInstId)
    local isSelectedGemEquipped = compareGemInst and compareGemInst.weaponInstId > 0
    if isSelectedGemEquipped then
        if isSameGem then
            isReplace = false
            isLoad = false
        else
            isLoad = false
            isUnload = false
        end
    end
    local isEquippingGem = curEquippingGemInstId > 0
    if isEquippingGem then
        isLoad = false
        self.view.btnLoad.gameObject:SetActive(false)
    else
        isUnload = false
    end
    return isReplace, isLoad, isUnload
end
WeaponExhibitGemCtrl._GetCurSelectedCellHint = HL.Method(HL.Table, HL.Number).Return(HL.String) << function(self, weaponExhibitInfo, cellGemInstId)
    if cellGemInstId ~= self.m_curSelectGemInstId then
        return ""
    end
    local isReplace, isLoad, isUnload = self:_GetButtonState(weaponExhibitInfo, cellGemInstId)
    if isReplace then
        return "ui_wpn_exhibit_gem_change"
    end
    if isLoad then
        return "ui_wpn_exhibit_gem_add"
    end
    if isUnload then
        return "ui_wpn_exhibit_gem_discard"
    end
    return ""
end
WeaponExhibitGemCtrl._OnClickCellWhenSelected = HL.Method(HL.Table, HL.Number) << function(self, weaponExhibitInfo, selectedGemInstId)
    local isReplace, isLoad, isUnload = self:_GetButtonState(weaponExhibitInfo, selectedGemInstId)
    if isReplace then
        self:_OnClickReplace()
    end
    if isLoad then
        self:_OnClickLoad()
    end
    if isUnload then
        self:_OnClickUnload()
    end
end
WeaponExhibitGemCtrl._RefreshGemCompareNode = HL.Method(HL.Table, HL.Opt(HL.Number)) << function(self, weaponExhibitInfo, newGemInstId)
    local selectGemInst
    local equippedGemInst = weaponExhibitInfo.gemInst
    if newGemInstId and newGemInstId > 0 then
        selectGemInst = CharInfoUtils.getGemByInstId(newGemInstId)
    end
    local hasGem = selectGemInst ~= nil or equippedGemInst ~= nil
    local isCompareOn = self.m_isCompareOn
    local selectGemInstId = selectGemInst and selectGemInst.instId or -1
    local equippedGemInstId = equippedGemInst and equippedGemInst.instId or -1
    local canCompare = selectGemInstId ~= -1 and equippedGemInstId ~= -1 and selectGemInstId ~= equippedGemInstId
    local isComparing = isCompareOn and canCompare
    self.view.noGemNode.gameObject:SetActive(equippedGemInst == nil and newGemInstId <= 0)
    UIUtils.PlayAnimationAndToggleActive(self.view.weaponInfoLeft.view.animationWrapper, isComparing)
    UIUtils.PlayAnimationAndToggleActive(self.view.compareMask, isComparing)
    local gemLeftInstId
    local gemRightInstId
    if selectGemInst then
        gemRightInstId = selectGemInst.instId
    end
    if isComparing then
        gemLeftInstId = equippedGemInst.instId
        if not isCompareOn then
            gemLeftInstId = nil
        end
    else
        gemLeftInstId = nil
    end
    local isLeftGemChanged = self.view.weaponInfoLeft.m_lastTryGemInstId ~= gemLeftInstId
    local isRightGemChanged = self.view.weaponInfoRight.m_lastTryGemInstId ~= gemRightInstId
    if gemLeftInstId then
        self.view.weaponInfoRight:InitInWeaponExhibitGemCompare({ weaponExhibitInfo = weaponExhibitInfo, }, gemRightInstId)
        self.view.weaponInfoLeft:InitInWeaponExhibitGemCompare({ weaponExhibitInfo = weaponExhibitInfo, }, gemLeftInstId)
        self.view.weaponInfoRight.view.nameNode.gameObject:SetActive(false)
        self.view.weaponInfoLeft.m_lastTryGemInstId = gemLeftInstId
        self.view.weaponInfoRight.m_lastTryGemInstId = gemRightInstId
    else
        self.view.weaponInfoRight:InitInWeaponExhibitGem({ weaponExhibitInfo = weaponExhibitInfo, }, gemRightInstId)
        self.view.weaponInfoRight.view.nameNode.gameObject:SetActive(true)
        self.view.weaponInfoRight.m_lastTryGemInstId = gemRightInstId
    end
    if isLeftGemChanged then
        UIUtils.PlayAnimationAndToggleActive(self.view.weaponInfoLeft.view.animationWrapper, gemLeftInstId ~= nil and gemLeftInstId > 0)
    end
    if isRightGemChanged then
        UIUtils.PlayAnimationAndToggleActive(self.view.weaponInfoRight.view.animationWrapper, gemRightInstId ~= nil and gemRightInstId > 0)
    end
    self:_RefreshButtonNode(weaponExhibitInfo, selectGemInst)
    self:Notify(MessageConst.WEAPON_EXHIBIT_REFRESH_GEM_CARD, { hasGem = hasGem, canCompare = canCompare, equippedGemInstId = equippedGemInstId, selectGemInstId = selectGemInstId, })
end
WeaponExhibitGemCtrl._RefreshButtonNode = HL.Method(HL.Table, HL.Opt(HL.Userdata)) << function(self, weaponExhibitInfo, compareGemInst)
    local canCompare = (compareGemInst and compareGemInst.instId > 0) and (weaponExhibitInfo.gemInst and compareGemInst.instId ~= weaponExhibitInfo.gemInst.instId)
    local inCompare = self.m_isCompareOn
    self.view.shrinkButton.gameObject:SetActive(canCompare and inCompare)
    self.view.compareButton.gameObject:SetActive(canCompare and not inCompare)
    self.view.btnReplace.gameObject:SetActive(true)
    self.view.btnLoad.gameObject:SetActive(true)
    self.view.btnUnload.gameObject:SetActive(true)
    local isGemSelected = compareGemInst ~= nil and compareGemInst.instId > 0
    if not isGemSelected then
        self.view.btnLoad.gameObject:SetActive(false)
        self.view.btnReplace.gameObject:SetActive(false)
        self.view.btnUnload.gameObject:SetActive(false)
        return
    end
    local curEquippingGemInstId = weaponExhibitInfo.gemInst and weaponExhibitInfo.gemInst.instId or -1
    local isSameGem = self.m_curSelectGemInstId == curEquippingGemInstId
    if isSameGem then
        self.view.btnReplace.gameObject:SetActive(false)
    else
        self.view.btnUnload.gameObject:SetActive(false)
    end
    local isSelectedGemEquipped = compareGemInst and compareGemInst.weaponInstId > 0
    if isSelectedGemEquipped then
        if isSameGem then
            self.view.btnReplace.gameObject:SetActive(false)
            self.view.btnLoad.gameObject:SetActive(false)
        else
            self.view.btnUnload.gameObject:SetActive(false)
        end
    end
    local isEquippingGem = curEquippingGemInstId > 0
    if isEquippingGem then
        self.view.btnLoad.gameObject:SetActive(false)
    else
        self.view.btnReplace.gameObject:SetActive(false)
        self.view.btnUnload.gameObject:SetActive(false)
    end
end
WeaponExhibitGemCtrl._OnSelectNewGem = HL.Method(HL.Table) << function(self, itemInfo)
    local weaponExhibitInfo = self.m_weaponExhibitInfo
    local curEquippingGemInstId = weaponExhibitInfo.gemInst and weaponExhibitInfo.gemInst.instId or -1
    local selectedGemInstId = itemInfo and itemInfo.itemInst.instId or curEquippingGemInstId
    if self.m_curSelectGemInstId == selectedGemInstId then
        return
    end
    self.m_curSelectGemInstId = selectedGemInstId
    self:_RefreshGemCompareNode(self.m_weaponExhibitInfo, selectedGemInstId)
end
WeaponExhibitGemCtrl._OnClickReplace = HL.Method() << function(self)
    local weaponInstId = self.m_weaponInfo.weaponInstId
    local selectGemInstId = self.m_curSelectGemInstId
    if selectGemInstId == -1 then
        logger.error("WeaponExhibitGemCtrl-> gemInstId is -1")
        return
    end
    local selectGemInst = CharInfoUtils.getGemByInstId(selectGemInstId)
    if selectGemInst.weaponInstId > 0 then
        local gemItemCfg = Tables.itemTable:GetValue(selectGemInst.templateId)
        local gemName = gemItemCfg.name
        local selectGemWeaponInst = CharInfoUtils.getWeaponByInstId(selectGemInst.weaponInstId)
        local selectGemWeaponItemCfg = Tables.itemTable:GetValue(selectGemWeaponInst.templateId)
        local weaponName = selectGemWeaponItemCfg.name
        self:Notify(MessageConst.SHOW_POP_UP, {
            content = string.format(Language.LUA_WEAPON_GEM_REPLACE_CONFIRM_FORMAT, gemName, weaponName),
            onConfirm = function()
                GameInstance.player.charBag:AttachGem(weaponInstId, selectGemInstId)
            end
        })
    else
        GameInstance.player.charBag:AttachGem(weaponInstId, selectGemInstId)
    end
end
WeaponExhibitGemCtrl._OnClickLoad = HL.Method() << function(self)
    local weaponInstId = self.m_weaponInfo.weaponInstId
    local gemInstId = self.m_curSelectGemInstId
    if gemInstId == -1 then
        logger.error("WeaponExhibitGemCtrl-> gemInstId is -1")
        return
    end
    GameInstance.player.charBag:AttachGem(weaponInstId, gemInstId)
end
WeaponExhibitGemCtrl._OnClickUnload = HL.Method() << function(self)
    local weaponInstId = self.m_weaponInfo.weaponInstId
    GameInstance.player.charBag:DetachGem(weaponInstId)
end
WeaponExhibitGemCtrl._ToggleWeaponDetail = HL.Method(HL.Boolean) << function(self, isOn)
    self.view.weaponCompareNode.gameObject:SetActive(isOn)
    self.view.gemCompareNode.gameObject:SetActive(not isOn)
end
HL.Commit(WeaponExhibitGemCtrl)