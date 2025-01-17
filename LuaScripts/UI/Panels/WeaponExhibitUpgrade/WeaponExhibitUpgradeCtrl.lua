local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.WeaponExhibitUpgrade
WeaponExhibitUpgradeCtrl = HL.Class('WeaponExhibitUpgradeCtrl', uiCtrl.UICtrl)
local SELECTION_OPTIONS = { { name = Language.LUA_WEAPON_EXHIBIT_SELECTION_LEVEL_TWO, maxFillWeaponQuality = 2, }, { name = Language.LUA_WEAPON_EXHIBIT_SELECTION_LEVEL_THREE, maxFillWeaponQuality = 3, }, { name = Language.LUA_WEAPON_EXHIBIT_SELECTION_LEVEL_FOUR, maxFillWeaponQuality = 4, }, }
local PREFS_KEY_EQUIP_UPGRADE_SELECTION = "PREFS_KEY_EQUIP_UPGRADE_SELECTION"
WeaponExhibitUpgradeCtrl.s_messages = HL.StaticField(HL.Table) << { [MessageConst.ON_WEAPON_GAIN_EXP] = 'OnWeaponGainExp', [MessageConst.ON_WEAPON_BREAKTHROUGH] = 'OnWeaponBreakthrough', [MessageConst.CACHE_REWARDS_POPUP] = 'CacheRewardsPopup', [MessageConst.SHOW_CACHED_REFUND_POPUP] = 'ShowRewardsPopup', [MessageConst.ON_ITEM_LOCKED_STATE_CHANGED] = '_OnItemLockedStateChanged', [MessageConst.ON_GEM_DETACH] = 'OnGemDetach', }
WeaponExhibitUpgradeCtrl.m_level2RequireExpDict = HL.Field(HL.Table)
WeaponExhibitUpgradeCtrl.m_level2RequireGoldDict = HL.Field(HL.Table)
WeaponExhibitUpgradeCtrl.m_costItemInfoList = HL.Field(HL.Table)
WeaponExhibitUpgradeCtrl.m_costItemInfoDict = HL.Field(HL.Table)
WeaponExhibitUpgradeCtrl.m_upgradeItemInfoList = HL.Field(HL.Table)
WeaponExhibitUpgradeCtrl.m_weaponInfo = HL.Field(HL.Table)
WeaponExhibitUpgradeCtrl.m_isFocusJump = HL.Field(HL.Boolean) << false
WeaponExhibitUpgradeCtrl.m_getBasicCostItemCell = HL.Field(HL.Function)
WeaponExhibitUpgradeCtrl.m_getExpandCostItemCell = HL.Field(HL.Function)
WeaponExhibitUpgradeCtrl.m_getBreakCostItemCell = HL.Field(HL.Function)
WeaponExhibitUpgradeCtrl.m_isBreakthrough = HL.Field(HL.Boolean) << false
WeaponExhibitUpgradeCtrl.m_selectionOptions = HL.Field(HL.Table)
WeaponExhibitUpgradeCtrl.m_maxFillWeaponQuality = HL.Field(HL.Number) << 4
WeaponExhibitUpgradeCtrl.m_weaponExhibitInfo = HL.Field(HL.Table)
WeaponExhibitUpgradeCtrl.m_curGenerateExp = HL.Field(HL.Number) << 0
WeaponExhibitUpgradeCtrl.m_curTargetLv = HL.Field(HL.Number) << 0
WeaponExhibitUpgradeCtrl.m_isBreakItemEnough = HL.Field(HL.Boolean) << false
WeaponExhibitUpgradeCtrl.m_rewardCache = HL.Field(HL.Any)
WeaponExhibitUpgradeCtrl.m_lastClickItemId = HL.Field(HL.Any)
WeaponExhibitUpgradeCtrl.m_lastClickItemInfo = HL.Field(HL.Table)
WeaponExhibitUpgradeCtrl.m_forceFocusListIndex = HL.Field(HL.Number) << -1
WeaponExhibitUpgradeCtrl.m_upgradeEffectCor = HL.Field(HL.Thread)
WeaponExhibitUpgradeCtrl.m_itemFillCor = HL.Field(HL.Thread)
WeaponExhibitUpgradeCtrl.m_controllerCurSelectedItemInfo = HL.Field(HL.Table)
WeaponExhibitUpgradeCtrl.m_controllerCalcItemModifier = HL.Field(HL.Number) << 1
WeaponExhibitUpgradeCtrl.m_controllerExpandKey = HL.Field(HL.Number) << -1
WeaponExhibitUpgradeCtrl.m_controllerTipKey = HL.Field(HL.Number) << -1
WeaponExhibitUpgradeCtrl.m_breakItemList = HL.Field(HL.Userdata)
WeaponExhibitUpgradeCtrl.m_curSelectedIndex = HL.Field(HL.Number) << 1
WeaponExhibitUpgradeCtrl.CacheRewardsPopup = HL.Method(HL.Any) << function(self, args)
    self.m_rewardCache = args
end
WeaponExhibitUpgradeCtrl.ShowRewardsPopup = HL.Method() << function(self)
    if self.m_rewardCache then
        Notify(MessageConst.SHOW_SYSTEM_REWARDS, { title = Language.LUA_WEAPON_EXHIBIT_UPGRADE_REFUND, items = unpack(self.m_rewardCache), icon = UIConst.WEAPON_EXHIBIT_REFUND_ICON, })
    end
    self.m_rewardCache = nil
end
WeaponExhibitUpgradeCtrl._OnItemLockedStateChanged = HL.Method(HL.Table) << function(self, arg)
    local itemId, instId, isLock = unpack(arg)
    if not isLock then
        return
    end
    if not instId or instId <= 0 then
        return
    end
    local costItemInfoDict = self.m_costItemInfoDict
    if costItemInfoDict[instId] ~= nil then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_ITEM_LOCK_TOAST)
        self:_RemoveFromCostItemDict(costItemInfoDict[instId], 1)
    end
end
WeaponExhibitUpgradeCtrl.OnGemDetach = HL.Method(HL.Table) << function(self, arg)
    self.view.expandNode.commonItemList:RefreshAllCells()
end
WeaponExhibitUpgradeCtrl.OnWeaponGainExp = HL.Method(HL.Table) << function(self, arg)
    local weaponInstId, newLv, newExp = unpack(arg)
    local expInfoBefore = self.m_weaponExhibitInfo
    local expInfo = CharInfoUtils.getWeaponExpInfo(weaponInstId)
    local weaponInfo = self.m_weaponInfo
    self:_InitUpgradeCache(weaponInfo.weaponInstId, weaponInfo.weaponTemplateId)
    self:_RefreshTitle(weaponInfo.weaponTemplateId, false)
    self:_ToggleExpandNode(false, true)
    self:_ResetCostItem()
    self:_RefreshBottomCostItem()
    self:_RefreshSelectionDropdown()
    self.m_upgradeEffectCor = self:_ClearCoroutine(self.m_upgradeEffectCor)
    self.m_upgradeEffectCor = self:_StartCoroutine(function()
        local hadLevelUp = expInfoBefore.curLv < newLv
        if hadLevelUp then
            AudioAdapter.PostEvent("Au_UI_Event_WeaponLevelUp")
            self.view.animation:Play("weaponexhibitupgrade_scroll_in")
        end
        coroutine.wait(0.3)
        self:_RefreshUpgradeInformation(weaponInfo.weaponInstId, weaponInfo.weaponTemplateId, hadLevelUp)
        coroutine.wait(1.2)
        self:ShowRewardsPopup()
        if newLv >= expInfo.stageLv then
            if newLv >= expInfo.maxLv then
                self:_LeaveWeaponUpgrade()
                return
            end
            local aniWrapper = self:GetAnimationWrapper()
            aniWrapper:Play("weaponexhibitupgrade_out", function()
                self:PlayAnimationIn()
                self:OnShow()
            end)
        end
    end)
end
WeaponExhibitUpgradeCtrl._LeaveWeaponUpgrade = HL.Method() << function(self, arg)
    if self.m_isFocusJump then
        PhaseManager:SendMessageToOpenedPhase(PhaseId.WeaponInfo, MessageConst.P_WEAPON_EXHIBIT_BLEND_EXIT, {
            finishCallback = function()
                PhaseManager:ExitPhaseFast(PhaseId.WeaponInfo)
            end
        })
        self:PlayAnimationOut()
        return
    end
    self:Notify(MessageConst.WEAPON_EXHIBIT_PAGE_CHANGE, { pageType = UIConst.WEAPON_EXHIBIT_PAGE_TYPE.OVERVIEW, })
end
WeaponExhibitUpgradeCtrl.OnWeaponBreakthrough = HL.Method(HL.Table) << function(self, arg)
    AudioAdapter.PostEvent("Au_UI_Event_WeaponLevelLimit")
    local weaponInstId, newBreakLv = unpack(arg)
    local weaponExpInfo = CharInfoUtils.getWeaponExpInfo(weaponInstId)
    if weaponExpInfo.curBreakthroughLv >= weaponExpInfo.maxBreakthroughLv and weaponExpInfo.curLv >= weaponExpInfo.maxLv then
        self:_LeaveWeaponUpgrade()
        return
    end
    self.m_upgradeEffectCor = self:_ClearCoroutine(self.m_upgradeEffectCor)
    self.m_upgradeEffectCor = self:_StartCoroutine(function()
        self.view.breakWeaponInfo.view.animation:Play("weaponexhibitupgrade_breakweaponinfo_break_in")
        coroutine.wait(0.5)
        local aniWrapper = self:GetAnimationWrapper()
        aniWrapper:Play("weaponexhibitupgrade_out", function()
            self:PlayAnimationIn()
            self:OnShow()
        end)
    end)
end
WeaponExhibitUpgradeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitActionEvent()
    self.view.expandNode.gameObject:SetActive(true)
    self.view.expandNode.gameObject:SetActive(false)
    self.view.expandNode.commonItemList.view.gameObject:SetActive(false)
    self.m_weaponInfo = arg.weaponInfo
    self.m_isFocusJump = arg.isFocusJump == true
end
WeaponExhibitUpgradeCtrl.OnClose = HL.Override() << function()
    CS.Beyond.Lua.UtilsForLua.ToggleWeaponInUpgradePanelOption(false)
end
WeaponExhibitUpgradeCtrl.OnShow = HL.Override() << function(self)
    local weaponInfo = self.m_weaponInfo
    local weaponExhibitInfo = CharInfoUtils.getWeaponExhibitBasicInfo(weaponInfo.weaponTemplateId, weaponInfo.weaponInstId)
    local weaponTemplateId = weaponExhibitInfo.weaponInst.templateId
    local weaponInstId = weaponExhibitInfo.weaponInst.instId
    local isBreakthrough = weaponExhibitInfo.curLv >= weaponExhibitInfo.stageLv
    self.m_isBreakthrough = isBreakthrough
    self.m_weaponExhibitInfo = weaponExhibitInfo
    self.view.expandNode.gameObject:SetActive(false)
    self:_InitUpgradeCache(weaponInstId, weaponTemplateId)
    self:_RefreshTitle(weaponTemplateId, isBreakthrough)
    self:_ToggleExpandNode(false)
    self:_RefreshSelectionDropdown()
    self.view.breakWeaponInfo.gameObject:SetActive(isBreakthrough)
    self.view.upgradeWeaponInfo.gameObject:SetActive(not isBreakthrough)
    self.view.weaponIntroduction:InitWeaponIntroduction(weaponTemplateId, weaponInstId)
    self.view.upgradeNode.gameObject:SetActive(not isBreakthrough)
    self.view.breakNode.gameObject:SetActive(isBreakthrough)
    CS.Beyond.Lua.UtilsForLua.ToggleWeaponInUpgradePanelOption(not isBreakthrough)
    if isBreakthrough then
        self:_RefreshBreakPanel(weaponInstId, weaponTemplateId)
    else
        self:_RefreshUpgradePanel(weaponInstId, weaponTemplateId)
    end
end
WeaponExhibitUpgradeCtrl._InitActionEvent = HL.Method() << function(self)
    self.m_getBasicCostItemCell = UIUtils.genCachedCellFunction(self.view.upgradeNode.costItemList)
    self.m_getBreakCostItemCell = UIUtils.genCachedCellFunction(self.view.breakNode.costItemList)
    self.view.btnLevelUp.onClick:AddListener(function()
        local isBreakthrough = self.m_isBreakthrough
        Notify(MessageConst.HIDE_ITEM_TIPS)
        if isBreakthrough then
            self:_ClickWeaponBreakButton()
        else
            self:_ClickWeaponUpgradeButton()
        end
    end)
    self.view.btnBack.onClick:AddListener(function()
        Notify(MessageConst.HIDE_ITEM_TIPS)
        if self.m_isFocusJump then
            PhaseManager:SendMessageToOpenedPhase(PhaseId.WeaponInfo, MessageConst.P_WEAPON_EXHIBIT_BLEND_EXIT, {
                finishCallback = function()
                    PhaseManager:ExitPhaseFast(PhaseId.WeaponInfo)
                end
            })
            self:PlayAnimationOut()
            return
        end
        UIUtils.PlayAnimationAndToggleActive(self.view.expandNode.commonItemList.view.animationWrapper, false)
        self:Notify(MessageConst.WEAPON_EXHIBIT_PAGE_CHANGE, { pageType = UIConst.WEAPON_EXHIBIT_PAGE_TYPE.OVERVIEW, })
    end)
    self.view.upgradeNode.costItemList.onUpdateCell:AddListener(function(object, csIndex)
        self:_RefreshBasicCostItemCell(object, csIndex)
    end)
    self.view.breakNode.costItemList.onUpdateCell:AddListener(function(object, csIndex)
        self:_RefreshBreakCostItemCell(object, csIndex)
    end)
    self.view.upgradeNode.btnAutoFill.onClick:AddListener(function()
        self:_AutoFillCostItem()
    end)
    self.view.upgradeNode.btnReset.onClick:AddListener(function()
        self:_ResetCostItem()
        self:_RefreshBottomCostItem()
        self:_RefreshUpgradeInformation(self.m_weaponInfo.weaponInstId, self.m_weaponInfo.weaponTemplateId)
    end)
    self.view.expandNode.emptyButton.onClick:AddListener(function()
        self:_ToggleExpandNode(false)
    end)
    local onUpdateSelectionCell = function(index, option, isSelected)
        option:SetText(self.m_selectionOptions[LuaIndex(index)].name)
    end
    local onSelectCell = function(index)
        local selectionOption = self.m_selectionOptions[LuaIndex(index)]
        self.m_maxFillWeaponQuality = selectionOption.maxFillWeaponQuality
        Unity.PlayerPrefs.SetInt(PREFS_KEY_EQUIP_UPGRADE_SELECTION, index)
    end
    self.view.upgradeNode.selectionDropDown.dropdown:Init(onUpdateSelectionCell, onSelectCell)
    self.view.walletBarPlaceholder:InitWalletBarPlaceholder(UIConst.INVENTORY_MONEY_IDS)
end
WeaponExhibitUpgradeCtrl._InitUpgradeCache = HL.Method(HL.Number, HL.String) << function(self, weaponInstId, weaponTemplateId)
    local _, weaponCfg = Tables.weaponBasicTable:TryGetValue(weaponTemplateId)
    if not weaponCfg then
        logger.error("CharInfoUtils->Can't get weapon basic info, templateId: " .. weaponTemplateId)
        return
    end
    local levelUpTemplateId = weaponCfg.levelTemplateId
    local _, levelUpCfg = Tables.weaponUpgradeTemplateTable:TryGetValue(levelUpTemplateId)
    if not levelUpCfg then
        logger.error("CharInfoUtils->Can't get weapon level up info, levelUpTemplateId: " .. levelUpTemplateId)
        return
    end
    local curLevel = CharInfoUtils.getWeaponByInstId(weaponInstId).weaponLv
    local maxLevel = weaponCfg.maxLv
    local startExp = levelUpCfg.list[CSIndex(curLevel)].lvUpExp
    local startGold = levelUpCfg.list[CSIndex(curLevel)].lvUpGold
    local level2RequireExpDict = {}
    local level2RequireGoldDict = {}
    for levelIndex = curLevel + 1, maxLevel do
        level2RequireExpDict[levelIndex] = startExp
        level2RequireGoldDict[levelIndex] = startGold
        startExp = startExp + levelUpCfg.list[CSIndex(levelIndex)].lvUpExp
        startGold = startGold + levelUpCfg.list[CSIndex(levelIndex)].lvUpGold
    end
    self.m_selectionOptions = SELECTION_OPTIONS
    self.m_level2RequireExpDict = level2RequireExpDict
    self.m_level2RequireGoldDict = level2RequireGoldDict
    self.m_costItemInfoList = {}
    self.m_costItemInfoDict = {}
end
WeaponExhibitUpgradeCtrl._RefreshBreakPanel = HL.Method(HL.Number, HL.String) << function(self, weaponInstId, weaponTemplateId)
    local weaponExhibitInfo = CharInfoUtils.getWeaponExhibitBasicInfo(weaponTemplateId, weaponInstId)
    self.view.breakWeaponInfo:InitBreakWeaponInfo({ weaponExhibitInfo = weaponExhibitInfo, })
    local weaponInst = weaponExhibitInfo.weaponInst
    local fromBreakthroughCfg = CharInfoUtils.getWeaponBreakthroughInfo(weaponInstId, weaponInst.breakthroughLv + 1)
    self:_RefreshBreakItemList(fromBreakthroughCfg)
    self:_RefreshBreakthroughButton(fromBreakthroughCfg.breakthroughGold)
end
WeaponExhibitUpgradeCtrl._RefreshUpgradePanel = HL.Method(HL.Number, HL.String) << function(self, weaponInstId, weaponTemplateId)
    self.m_costItemInfoDict = {}
    self:_RefreshBottomCostItem()
    self:_ResetCostItem()
    self:_RefreshUpgradeInformation(weaponInstId, weaponTemplateId)
end
WeaponExhibitUpgradeCtrl._RefreshSelectionDropdown = HL.Method() << function(self)
    local lastSelectKey = Unity.PlayerPrefs.GetInt(PREFS_KEY_EQUIP_UPGRADE_SELECTION, 0)
    self.view.upgradeNode.selectionDropDown.dropdown:Refresh(#self.m_selectionOptions, lastSelectKey)
end
WeaponExhibitUpgradeCtrl._RefreshTitle = HL.Method(HL.String, HL.Boolean) << function(self, weaponTemplateId, isBreakthrough)
    local _, itemCfg = Tables.itemTable:TryGetValue(weaponTemplateId)
    if not itemCfg then
        logger.error("WeaponExhibitUpgradeCtrl->Can't find weaponItem ID: " .. weaponTemplateId)
        return
    end
    local title = isBreakthrough and Language.LUA_WEAPON_EXHIBIT_BREAKTHROUGH_TITLE or Language.LUA_WEAPON_EXHIBIT_UPGRADE_TITLE
    self.view.title.text = string.format(title, itemCfg.name)
end
WeaponExhibitUpgradeCtrl._RefreshBottomCostItem = HL.Method(HL.Opt(HL.Boolean)) << function(self, skipGraduallyShow)
    local costItemInfoList = self:_CollectCostItemInfoList()
    local costCellCount = math.max(#costItemInfoList, UIConst.WEAPON_EXHIBIT_UPGRADE_MIN_SLOT_NUM)
    self.m_costItemInfoList = costItemInfoList
    self.view.upgradeNode.costItemList:UpdateCount(costCellCount)
    self.view.upgradeNode.consumeNumber.text = #costItemInfoList
    self.view.upgradeNode.maxNumber.text = "/" .. UIConst.WEAPON_EXHIBIT_UPGRADE_ITEM_MAX_COUNT
end
WeaponExhibitUpgradeCtrl._RefreshBreakItemList = HL.Method(HL.Userdata) << function(self, breakthroughCfg)
    local breakItemList = breakthroughCfg.breakItemList
    self.m_breakItemList = breakthroughCfg.breakItemList
    self.view.breakNode.costItemList:UpdateCount(#breakItemList)
end
WeaponExhibitUpgradeCtrl._RefreshUpgradeInformation = HL.Method(HL.Number, HL.String, HL.Opt(HL.Boolean)) << function(self, weaponInstId, weaponTemplateId, inUpgradeTransition)
    local weaponExhibitInfo = CharInfoUtils.getWeaponExhibitBasicInfo(weaponTemplateId, weaponInstId)
    self.m_weaponExhibitInfo = weaponExhibitInfo
    local weaponInst = CharInfoUtils.getWeaponByInstId(weaponInstId)
    local curExp = weaponInst.exp
    local curLevel = weaponInst.weaponLv
    local curGenerateExp = self:_CalcGenerateExp()
    local curExpSum = curGenerateExp + curExp
    local targetLevel, expLeft = self:_CalcLevelByExp(curExpSum, curLevel, weaponExhibitInfo.stageLv)
    local _, weaponCfg = Tables.weaponBasicTable:TryGetValue(weaponTemplateId)
    local levelUpTemplateId = weaponCfg.levelTemplateId
    local _, levelUpCfg = Tables.weaponUpgradeTemplateTable:TryGetValue(levelUpTemplateId)
    local nextLvExp = levelUpCfg.list[CSIndex(curLevel)].lvUpExp
    self.m_curTargetLv = targetLevel
    self.m_curGenerateExp = curGenerateExp
    self.view.upgradeWeaponInfo:InitUpgradeWeaponInfo({ weaponExhibitInfo = weaponExhibitInfo, curLevel = curLevel, targetLevel = targetLevel, curExp = curExp, nextLvExp = nextLvExp, addExp = curGenerateExp, inUpgradeTransition = inUpgradeTransition, })
    local requireGold = targetLevel == curLevel and 0 or self.m_level2RequireGoldDict[targetLevel]
    self:_RefreshUpgradeBtn(curGenerateExp, requireGold)
end
WeaponExhibitUpgradeCtrl._RefreshUpgradeBtn = HL.Method(HL.Number, HL.Number) << function(self, generateExp, requireGold)
    local curGold = Utils.getItemCount(UIConst.INVENTORY_MONEY_IDS[1], true)
    local goldEnough = curGold >= requireGold
    self.view.goldCostNumber.text = UIUtils.setCountColor(requireGold, not goldEnough)
    self.view.btnLevelUp.text = Language.LUA_WEAPON_EXHIBIT_UPGRADE
end
WeaponExhibitUpgradeCtrl._RefreshBreakthroughButton = HL.Method(HL.Number) << function(self, requireGold)
    local curGold = Utils.getItemCount(UIConst.INVENTORY_MONEY_IDS[1], true)
    local goldEnough = curGold >= requireGold
    self.view.goldCostNumber.text = UIUtils.setCountColor(requireGold, not goldEnough)
    self.view.btnLevelUp.text = Language.LUA_WEAPON_EXHIBIT_BREAKTHROUGH
end
WeaponExhibitUpgradeCtrl._RefreshBasicCostItemCell = HL.Method(HL.Userdata, HL.Number) << function(self, object, index)
    local cell = self.m_getBasicCostItemCell(object)
    local costItemInfo = self.m_costItemInfoList[LuaIndex(index)]
    self:_RefreshCostItemCell(cell, costItemInfo, function()
        self.m_forceFocusListIndex = costItemInfo and costItemInfo.listShowIndex or -1
        self:_ToggleExpandNode(true)
    end)
    cell.itemBlack.view.redDot.gameObject:SetActive(false)
end
WeaponExhibitUpgradeCtrl._RefreshBreakCostItemCell = HL.Method(HL.Userdata, HL.Number) << function(self, object, index)
    local cell = self.m_getBreakCostItemCell(object)
    local itemInfo = self.m_breakItemList[index]
    local itemId = itemInfo.id
    local inventoryCount = Utils.getItemCount(itemId, true)
    cell.itemBlack:InitItem({ id = itemId, count = itemInfo.count, }, true)
    cell.storageNode:InitStorageNode(inventoryCount, itemInfo.count, true)
end
WeaponExhibitUpgradeCtrl._OnClickExpandCostItemCell = HL.Method(HL.Table, HL.Boolean) << function(self, costItemInfo, realClick)
    if not realClick then
        return
    end
    if self.m_lastClickItemId ~= costItemInfo.indexId and realClick then
        Notify(MessageConst.SHOW_ITEM_TIPS, { transform = self.view.expandNode.tipPos, itemId = costItemInfo.itemCfg.id, instId = costItemInfo.isWeapon and costItemInfo.indexId or 0, noJump = true, autoClose = false, isSideTips = true, })
    end
    self.m_lastClickItemId = costItemInfo.indexId
    self.m_lastClickItemInfo = costItemInfo
    self:_AddIntoCostItemDict(costItemInfo, 1)
end
WeaponExhibitUpgradeCtrl._RefreshCostItemCell = HL.Method(HL.Any, HL.Table, HL.Any) << function(self, cell, costItemInfo, onClickAction)
    local isEmpty = not costItemInfo
    cell.itemBlack.gameObject:SetActive(not isEmpty)
    cell.emptyNode.gameObject:SetActive(isEmpty)
    cell.selectNode.gameObject:SetActive(false)
    cell.multiSelectNode.gameObject:SetActive(false)
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        onClickAction()
    end)
    cell.btnMinus.onClick:RemoveAllListeners()
    cell.btnMinus.onClick:AddListener(function()
        self:_RemoveFromCostItemDict(costItemInfo, 1)
    end)
    cell.btnMinus.onPressStart:RemoveAllListeners()
    cell.btnMinus.onPressStart:AddListener(function()
        self:_StartFillTimer(costItemInfo, -10)
    end)
    cell.btnMinus.onPressEnd:RemoveAllListeners()
    cell.btnMinus.onPressEnd:AddListener(function()
        self:_StopFillTimer(costItemInfo)
    end)
    if isEmpty then
        return
    end
    local id = costItemInfo.indexId
    local isMarkCost = self.m_costItemInfoDict and self.m_costItemInfoDict[id] ~= nil
    local isWeapon = costItemInfo.isWeapon
    cell.btnMinus.gameObject:SetActive(isMarkCost)
    cell.itemBlack:InitItem({ id = costItemInfo.itemCfg.id, instId = isWeapon and costItemInfo.indexId or 0, }, true)
    cell.itemBlack:UpdateRedDot()
    cell.itemBlack.view.button.onClick:RemoveAllListeners()
    cell.itemBlack.view.button.onClick:AddListener(function()
        onClickAction()
    end)
    if costItemInfo.isWeapon then
        cell.selectNode.gameObject:SetActive(isMarkCost)
        cell.multiSelectNode.gameObject:SetActive(false)
    else
        cell.selectNode.gameObject:SetActive(isMarkCost)
        cell.multiSelectNode.gameObject:SetActive(true)
        cell.selectCount.text = costItemInfo.count
    end
end
WeaponExhibitUpgradeCtrl._ToggleExpandNode = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, isExpand, closeAll)
    if self.view.expandNode.commonItemList:IsAnyItemSelecting() then
        self.view.expandNode.commonItemList:SetSelectedIndex(0, false, true)
    end
    self.m_lastClickItemId = nil
    self.m_lastClickItemInfo = nil
    if UIManager:IsShow(PanelId.ItemTips) then
        Notify(MessageConst.HIDE_ITEM_TIPS)
        if not closeAll then
            return
        end
    end
    if isExpand then
        self.view.expandNode.gameObject:SetActive(true)
        UIUtils.PlayAnimationAndToggleActive(self.view.expandNode.commonItemList.view.animationWrapper, true)
        self.view.expandNode.commonItemList:PlayGraduallyShow()
    else
        UIUtils.PlayAnimationAndToggleActive(self.view.expandNode.commonItemList.view.animationWrapper, false, function()
            self.view.expandNode.gameObject:SetActive(false)
        end)
    end
    local audioEventKey = isExpand and "au_ui_menu_side_open" or "au_ui_menu_side_close"
    AudioManager.PostEvent(audioEventKey)
end
WeaponExhibitUpgradeCtrl._CalcGenerateExp = HL.Method().Return(HL.Number) << function(self)
    local expSum = 0
    for _, costItemInfo in pairs(self.m_costItemInfoDict) do
        local itemExp = costItemInfo.generateExp
        expSum = expSum + itemExp * costItemInfo.count
    end
    return expSum
end
WeaponExhibitUpgradeCtrl._TryModifyCostItemDict = HL.Method(HL.Table, HL.Number) << function(self, itemInfo, count)
    local costItemInfoDict = self.m_costItemInfoDict
    local expInfo = self.m_weaponExhibitInfo
    local targetLv = self.m_curTargetLv
    if targetLv >= expInfo.stageLv then
        self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_UPGRADE_MAX_LEVEL)
        return
    end
    if lume.count(costItemInfoDict) >= UIConst.WEAPON_EXHIBIT_UPGRADE_ITEM_MAX_COUNT then
        self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_UPGRADE_MAX_ITEM_COUNT)
        return
    end
    if itemInfo.isWeapon then
        local isLock = GameInstance.player.inventory:IsItemLocked(Utils.getCurrentScope(), itemInfo.itemInst.templateId, itemInfo.itemInst.instId)
        if isLock then
            self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_UPGRADE_WEAPON_LOCKED)
            return
        end
    end
    if itemInfo.isWeapon then
        itemInfo.count = 1
    else
        itemInfo.count = math.min(itemInfo.count + count, itemInfo.inventoryCount)
    end
    local indexId = itemInfo.indexId
    costItemInfoDict[indexId] = itemInfo
end
WeaponExhibitUpgradeCtrl._AddIntoCostItemDict = HL.Method(HL.Table, HL.Number) << function(self, itemInfo, count)
    local weaponInfo = self.m_weaponInfo
    self:_TryAddIntoCostItemDict(itemInfo, count)
    self:_RefreshBottomCostItem(true)
    self.view.expandNode.commonItemList:RefreshCellById(itemInfo.indexId)
    self:_RefreshUpgradeInformation(weaponInfo.weaponInstId, weaponInfo.weaponTemplateId)
end
WeaponExhibitUpgradeCtrl._TryAddIntoCostItemDict = HL.Method(HL.Table, HL.Number) << function(self, itemInfo, count)
    local curCount = itemInfo.count or 0
    local nextCount = curCount + count
    local costItemInfoDict = self.m_costItemInfoDict
    if count <= 0 then
        return nextCount
    end
    if itemInfo.isWeapon then
        local isLock = GameInstance.player.inventory:IsItemLocked(Utils.getCurrentScope(), itemInfo.itemInst.templateId, itemInfo.itemInst.instId)
        if isLock then
            self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_UPGRADE_WEAPON_LOCKED)
            return
        end
        local weaponInst = itemInfo.itemInst
        local hasGemEquipped = weaponInst.attachedGemInstId > 0
        if hasGemEquipped then
            local gemInst = CharInfoUtils.getGemByInstId(weaponInst.attachedGemInstId)
            local gemItemCfg = Tables.itemTable[gemInst.templateId]
            Notify(MessageConst.SHOW_POP_UP, {
                content = string.format(Language.LUA_WEAPON_EXHIBIT_UPGRADE_GEM_EQUIPPED, gemItemCfg.name),
                onConfirm = function()
                    GameInstance.player.charBag:DetachGem(weaponInst.instId)
                end,
                onCancel = function()
                end
            })
            return
        end
        if lume.count(costItemInfoDict) >= UIConst.WEAPON_EXHIBIT_UPGRADE_ITEM_MAX_COUNT then
            self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_UPGRADE_MAX_INGREDIENT)
            return
        end
    else
        if lume.count(costItemInfoDict) >= UIConst.WEAPON_EXHIBIT_UPGRADE_ITEM_MAX_COUNT and costItemInfoDict[itemInfo.indexId] == nil then
            self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_UPGRADE_MAX_INGREDIENT)
            return
        end
    end
    local weaponInstId = self.m_weaponInfo.weaponInstId
    local weaponInst = CharInfoUtils.getWeaponByInstId(weaponInstId)
    local curExp = weaponInst.exp
    local expInfo = self.m_weaponExhibitInfo
    local curGenerateExp = self:_CalcGenerateExp()
    local stageExp = self.m_level2RequireExpDict[expInfo.stageLv] or 0
    local expRequire = stageExp - curExp
    local itemExp = itemInfo.generateExp
    if (curGenerateExp + (itemExp * count)) > expRequire then
        self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_UPGRADE_MAX_LEVEL)
        local needExp = math.max(0, expRequire - curGenerateExp)
        nextCount = curCount + math.ceil(needExp / itemExp)
    end
    if itemInfo.inventoryCount ~= 0 and nextCount >= itemInfo.inventoryCount then
        if not itemInfo.isWeapon then
            self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_UPGRADE_MAX_ITEM_COUNT)
        end
        nextCount = itemInfo.inventoryCount
    elseif itemInfo.inventoryCount == 0 then
        nextCount = 0
    end
    itemInfo.count = nextCount
    if itemInfo.count > 0 then
        local indexId = itemInfo.indexId
        costItemInfoDict[indexId] = itemInfo
    end
end
WeaponExhibitUpgradeCtrl._RemoveFromCostItemDict = HL.Method(HL.Table, HL.Number) << function(self, itemInfo, count)
    local costItemInfoDict = self.m_costItemInfoDict
    local weaponInfo = self.m_weaponInfo
    local id = itemInfo.indexId
    itemInfo.count = lume.clamp(itemInfo.count - count, 0, itemInfo.inventoryCount)
    if costItemInfoDict[id] and itemInfo.count <= 0 then
        costItemInfoDict[id].count = 0
        costItemInfoDict[id] = nil
    end
    self:_RefreshBottomCostItem(true)
    self:_RefreshUpgradeInformation(weaponInfo.weaponInstId, weaponInfo.weaponTemplateId)
    self.view.expandNode.commonItemList:RefreshCellById(itemInfo.indexId)
end
WeaponExhibitUpgradeCtrl._CalcLevelByExp = HL.Method(HL.Number, HL.Number, HL.Number).Return(HL.Number, HL.Number) << function(self, addExp, curLevel, maxLevel)
    local level2RequireExpDict = self.m_level2RequireExpDict
    if level2RequireExpDict[maxLevel] and addExp >= level2RequireExpDict[maxLevel] then
        return maxLevel, addExp - level2RequireExpDict[maxLevel]
    end
    for level = maxLevel, curLevel + 1, -1 do
        local requireExp = level2RequireExpDict[level]
        if addExp >= requireExp then
            return level, addExp - requireExp
        end
    end
    return curLevel, addExp
end
WeaponExhibitUpgradeCtrl._AutoFillCostItem = HL.Method() << function(self)
    local weaponInfo = self.m_weaponInfo
    self:_TryFillCostItem()
    self:_RefreshBottomCostItem()
    self.view.expandNode.commonItemList:RefreshAllCells()
    self:_RefreshUpgradeInformation(weaponInfo.weaponInstId, weaponInfo.weaponTemplateId)
end
WeaponExhibitUpgradeCtrl._TryFillCostItem = HL.Method() << function(self)
    local upgradeItemInfoList = self.m_upgradeItemInfoList
    local weaponExhibitInfo = self.m_weaponExhibitInfo
    local stageExp = self.m_level2RequireExpDict[weaponExhibitInfo.stageLv] or 0
    local targetExp = stageExp - weaponExhibitInfo.weaponInst.exp
    local maxFillWeaponQuality = self.m_maxFillWeaponQuality
    local costItemInfoDict = self:_AutoFillCostItemDict(targetExp, maxFillWeaponQuality, upgradeItemInfoList)
    for key, costItemInfo in pairs(costItemInfoDict) do
        if costItemInfo.count <= 0 then
            costItemInfoDict[key] = nil
        end
    end
    self.m_costItemInfoDict = costItemInfoDict
    if lume.count(costItemInfoDict) == 0 then
        self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_UPGRADE_NO_ITEM)
    end
end
WeaponExhibitUpgradeCtrl._AutoFillCostItemDict = HL.Method(HL.Number, HL.Number, HL.Table).Return(HL.Table) << function(self, targetExp, maxQuality, upgradeItemInfoList)
    local costItemInfoDict = {}
    local expLeft = targetExp
    local calcAssistInfoList = lume.sort(upgradeItemInfoList, function(a, b)
        if a.isWeapon ~= b.isWeapon then
            return a.isWeapon == false
        end
        if a.itemCfg.rarity ~= b.itemCfg.rarity then
            return a.itemCfg.rarity < b.itemCfg.rarity
        end
        if a.isWeapon and b.isWeapon then
            local aWeaponLv = a.itemInst.weaponLv
            local bWeaponLv = b.itemInst.weaponLv
            if aWeaponLv ~= bWeaponLv then
                return aWeaponLv < bWeaponLv
            end
        end
        return a.itemCfg.id > b.itemCfg.id
    end)
    local ingredientList = {}
    for _, itemInfo in ipairs(calcAssistInfoList) do
        local singleExp = itemInfo.generateExp
        local maxCount = itemInfo.inventoryCount
        local generateExpTotal = singleExp * maxCount
        if expLeft <= 0 then
            break
        end
        if lume.count(costItemInfoDict) >= UIConst.WEAPON_EXHIBIT_UPGRADE_ITEM_MAX_COUNT then
            return costItemInfoDict
        end
        local isWeapon = itemInfo.isWeapon
        local isLockWeapon = itemInfo.itemInst and itemInfo.itemInst.isLocked
        local weaponEquippedWithGem = false
        if isWeapon then
            local weaponInst = itemInfo.itemInst
            weaponEquippedWithGem = weaponInst.attachedGemInstId > 0
        end
        if (not isLockWeapon) and (not weaponEquippedWithGem) then
            if itemInfo.itemCfg.rarity <= maxQuality then
                if generateExpTotal > expLeft then
                    local count = math.min(math.ceil(expLeft / singleExp), maxCount)
                    itemInfo.count = count
                    expLeft = expLeft - singleExp * count
                else
                    itemInfo.count = maxCount
                    expLeft = expLeft - singleExp * maxCount
                end
                if itemInfo.count > 0 then
                    costItemInfoDict[itemInfo.indexId] = itemInfo
                    table.insert(ingredientList, itemInfo)
                end
            end
        end
    end
    if expLeft == 0 then
        return costItemInfoDict
    end
    ingredientList = lume.sort(ingredientList, function(a, b)
        if a.isWeapon ~= b.isWeapon then
            return a.isWeapon == true
        end
        if a.itemCfg.rarity ~= b.itemCfg.rarity then
            return a.itemCfg.rarity > b.itemCfg.rarity
        end
        if a.isWeapon and b.isWeapon then
            local aWeaponLv = a.itemInst.weaponLv
            local bWeaponLv = b.itemInst.weaponLv
            if aWeaponLv ~= bWeaponLv then
                return aWeaponLv > bWeaponLv
            end
        end
    end)
    for _, itemInfo in ipairs(ingredientList) do
        local singleExp = itemInfo.generateExp
        local count = itemInfo.count
        local addedExpTotal = singleExp * count
        if expLeft + singleExp < 0 then
            if expLeft + addedExpTotal > 0 then
                if itemInfo.isWeapon then
                    break
                else
                    if count > 1 then
                        local canPopCount = math.floor(math.abs(expLeft) / singleExp)
                        itemInfo.count = itemInfo.count - canPopCount
                        expLeft = expLeft + singleExp * canPopCount
                    end
                end
            else
                expLeft = expLeft + addedExpTotal
                itemInfo.count = 0
                costItemInfoDict[itemInfo.indexId] = nil
            end
        end
    end
    return costItemInfoDict
end
WeaponExhibitUpgradeCtrl._RefreshWeaponCellAddOn = HL.Method(HL.Any, HL.Table) << function(self, cell, itemInfo)
    cell.selectNode.gameObject:SetActive(itemInfo.count ~= nil and itemInfo.count > 0)
    cell.multiSelectNode.gameObject:SetActive(false)
    cell.selectCount.text = itemInfo.count
end
WeaponExhibitUpgradeCtrl._RefreshItemCellAddOn = HL.Method(HL.Any, HL.Table) << function(self, cell, itemInfo)
    cell.selectNode.gameObject:SetActive(itemInfo.count ~= nil and itemInfo.count > 0)
    cell.multiSelectNode.gameObject:SetActive(true)
    cell.selectCount.text = itemInfo.count
end
WeaponExhibitUpgradeCtrl._RefreshCellAddOn = HL.Method(HL.Any, HL.Table) << function(self, cell, itemInfo)
    if itemInfo.itemInst ~= nil then
        self:_RefreshWeaponCellAddOn(cell, itemInfo)
    else
        self:_RefreshItemCellAddOn(cell, itemInfo)
    end
    cell.btnMinus.onClick:RemoveAllListeners()
    cell.btnMinus.onClick:AddListener(function()
        self:_RemoveFromCostItemDict(itemInfo, 1)
        self:_RefreshCellAddOn(cell, itemInfo)
    end)
    cell.btnMinus.onPressStart:AddListener(function()
        self:_StartFillTimer(itemInfo, -10)
    end)
    cell.btnMinus.onPressEnd:AddListener(function()
        self:_StopFillTimer(itemInfo)
    end)
end
WeaponExhibitUpgradeCtrl._ResetCostItem = HL.Method() << function(self)
    self.m_costItemInfoDict = {}
    self.view.expandNode.commonItemList:InitCommonItemList({
        listType = UIConst.COMMON_ITEM_LIST_TYPE.WEAPON_EXHIBIT_UPGRADE,
        onlyGenerateData = self.view.expandNode.commonItemList.view.activeInHierarchy,
        refreshItemAddOn = function(cell, itemInfo)
            self:_RefreshCellAddOn(cell, itemInfo)
        end,
        onClickItem = function(args)
            local itemInfo = args.itemInfo
            local curCell = args.curCell
            local nextCell = args.nextCell
            self:_OnClickExpandCostItemCell(itemInfo, args.realClick)
            if curCell then
            end
            if nextCell then
                self:_RefreshCellAddOn(nextCell, itemInfo)
            end
        end,
        onPressItem = function(itemInfo)
            self:_StartFillTimer(itemInfo, 10)
        end,
        onReleaseItem = function(itemInfo)
            self:_StopFillTimer(itemInfo)
        end,
        filter_not_equipped = true,
        filter_not_instId = self.m_weaponInfo.weaponInstId,
    })
    self.m_upgradeItemInfoList = self.view.expandNode.commonItemList.m_itemInfoList
    for _, itemInfo in pairs(self.m_upgradeItemInfoList) do
        if itemInfo.generateExp == nil then
            itemInfo.generateExp = WeaponUtils.CalcItemExp(itemInfo.itemCfg, itemInfo.itemInst)
        end
    end
end
WeaponExhibitUpgradeCtrl._StartFillTimer = HL.Method(HL.Table, HL.Number) << function(self, itemInfo, count)
    self.m_itemFillCor = self:_ClearCoroutine(self.m_itemFillCor)
    self.m_itemFillCor = self:_StartCoroutine(function()
        while true do
            coroutine.wait(0.3)
            if count > 0 then
                self:_AddIntoCostItemDict(itemInfo, count)
            else
                self:_RemoveFromCostItemDict(itemInfo, -count)
            end
        end
    end)
end
WeaponExhibitUpgradeCtrl._StopFillTimer = HL.Method(HL.Table) << function(self, itemInfo)
    self.m_itemFillCor = self:_ClearCoroutine(self.m_itemFillCor)
end
WeaponExhibitUpgradeCtrl._CollectCostItemInfoList = HL.Method().Return(HL.Table) << function(self)
    local costItemInfoList = {}
    for _, costItemInfo in pairs(self.m_costItemInfoDict) do
        table.insert(costItemInfoList, costItemInfo)
    end
    costItemInfoList = lume.sort(costItemInfoList, function(a, b)
        if a.isWeapon ~= b.isWeapon then
            return a.isWeapon
        end
        if a.isWeapon and b.isWeapon then
            local aWeaponLv = a.itemInst.weaponLv
            local bWeaponLv = b.itemInst.weaponLv
            if a.isLocked ~= b.isLocked then
                return a.isLocked
            end
            if aWeaponLv ~= bWeaponLv then
                return aWeaponLv > bWeaponLv
            end
        end
        if a.itemCfg.rarity ~= b.itemCfg.rarity then
            return a.itemCfg.rarity > b.itemCfg.rarity
        end
        return a.itemCfg.id > b.itemCfg.id
    end)
    return costItemInfoList
end
WeaponExhibitUpgradeCtrl._ClickWeaponUpgradeButton = HL.Method() << function(self)
    if self.m_curGenerateExp <= 0 then
        self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_UPGRADE_NONE_ITEM)
        return
    end
    local weaponExhibitInfo = self.m_weaponExhibitInfo
    local weaponInst = weaponExhibitInfo.weaponInst
    local curLv = weaponInst.weaponLv
    local targetLv = self.m_curTargetLv
    if curLv >= weaponExhibitInfo.stageLv then
        return
    end
    local requireGold = (targetLv == curLv) and 0 or self.m_level2RequireGoldDict[targetLv]
    local curGold = Utils.getItemCount(UIConst.INVENTORY_MONEY_IDS[1], true)
    if curGold < requireGold then
        self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_GOLD_NOT_ENOUGH)
        return
    end
    local weaponInfo = self.m_weaponInfo
    local costItemInfoDict = self.m_costItemInfoDict
    local costWeaponInstIds = {}
    local costItemId2Count = {}
    for _, costItemInfo in pairs(costItemInfoDict) do
        if costItemInfo.isWeapon then
            local isLocked = GameInstance.player.inventory:IsItemLocked(Utils.getCurrentScope(), costItemInfo.itemInst.templateId, costItemInfo.itemInst.instId)
            if isLocked then
                self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_UPGRADE_CONTAIN_WEAPON_LOCKED)
                return
            end
            table.insert(costWeaponInstIds, costItemInfo.itemInst.instId)
        else
            costItemId2Count[costItemInfo.itemCfg.id] = costItemInfo.count
        end
    end
    GameInstance.player.charBag:AddWeaponExp(weaponInfo.weaponInstId, costItemId2Count, costWeaponInstIds)
end
WeaponExhibitUpgradeCtrl._ClickWeaponBreakButton = HL.Method() << function(self)
    local exhibitInfo = self.m_weaponExhibitInfo
    local expInfo = CharInfoUtils.getWeaponExpInfo(exhibitInfo.weaponInst.instId)
    if expInfo.curLv < expInfo.stageLv then
        return
    end
    local breakItemList = self.m_breakItemList
    if breakItemList == nil then
        return
    end
    for i, itemInfo in pairs(breakItemList) do
        local itemId = itemInfo.id
        local itemCount = Utils.getItemCount(itemId, true)
        if itemCount < itemInfo.count then
            self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_BREAK_NOT_ENOUGH_ITEM)
            return
        end
    end
    local weaponInst = exhibitInfo.weaponInst
    local fromBreakthroughCfg = CharInfoUtils.getWeaponBreakthroughInfo(weaponInst.instId, weaponInst.breakthroughLv)
    local curGold = Utils.getItemCount(UIConst.INVENTORY_MONEY_IDS[1], true)
    if curGold < fromBreakthroughCfg.breakthroughGold then
        self:Notify(MessageConst.SHOW_TOAST, Language.LUA_WEAPON_EXHIBIT_GOLD_NOT_ENOUGH)
        return
    end
    local weaponInfo = self.m_weaponInfo
    GameInstance.player.charBag:BreakthroughWeapon(weaponInfo.weaponInstId)
end
HL.Commit(WeaponExhibitUpgradeCtrl)