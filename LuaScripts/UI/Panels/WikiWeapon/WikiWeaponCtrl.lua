local wikiDetailBaseCtrl = require_ex('UI/Panels/WikiDetailBase/WikiDetailBaseCtrl')
local PANEL_ID = PanelId.WikiWeapon
WikiWeaponCtrl = HL.Class('WikiWeaponCtrl', wikiDetailBaseCtrl.WikiDetailBaseCtrl)
WikiWeaponCtrl.GetPanelId = HL.Override().Return(HL.Number) << function(self)
    return PANEL_ID
end
WikiWeaponCtrl._OnPhaseItemBind = HL.Override() << function(self)
    WikiWeaponCtrl.Super._OnPhaseItemBind(self)
    self:_RefreshModel(true)
end
WikiWeaponCtrl._RefreshCenter = HL.Override() << function(self)
    WikiWeaponCtrl.Super._RefreshCenter(self)
    self:_RefreshModel()
end
WikiWeaponCtrl.m_isShowWeaponMaxInfo = HL.Field(HL.Boolean) << false
WikiWeaponCtrl.m_isBtnAttrInited = HL.Field(HL.Boolean) << false
WikiWeaponCtrl._RefreshRight = HL.Override() << function(self)
    if not self.m_isBtnAttrInited then
        self.m_isBtnAttrInited = true
        self.view.right.btnToggle.onClick:AddListener(function()
            self.view.right.recipeNodeAnimWrapper:PlayOutAnimation(function()
                self.m_isShowWeaponMaxInfo = not self.m_isShowWeaponMaxInfo
                self:_RefreshModel()
                self:_RefreshRight()
                self.view.right.recipeNodeAnimWrapper:PlayInAnimation()
            end)
        end)
    end
    self:_RefreshWeaponShowInfo(self:_GetWeaponShowData(self.m_isShowWeaponMaxInfo))
end
WikiWeaponCtrl._RefreshModel = HL.Method(HL.Opt(HL.Boolean)) << function(self, playInAnim)
    if self.m_phase then
        self.m_phase:ShowModel(self.m_wikiEntryShowData, { isWeaponRefinedMax = self.m_isShowWeaponMaxInfo, playInAnim = playInAnim, })
        self.m_phase:ActiveEntryVirtualCamera(true)
    end
end
WikiWeaponCtrl._GetWeaponShowData = HL.Method(HL.Boolean).Return(HL.Table) << function(self, isMaxLevel)
    local templateId = self.m_wikiEntryShowData.wikiEntryData.refItemId
    local hasValue
    local weaponBasicData
    local weaponBreakThroughDetailList
    local weaponTalentDetailList
    local maxLevel, initMaxLevel, breakThroughCount, maxBreakthroughLevel, maxRefineLevel = 0, 0, 0, 0, 0
    hasValue, weaponBasicData = Tables.weaponBasicTable:TryGetValue(templateId)
    if hasValue then
        maxLevel = weaponBasicData.maxLv
        hasValue, weaponBreakThroughDetailList = Tables.weaponBreakThroughTemplateTable:TryGetValue(weaponBasicData.breakthroughTemplateId)
        if hasValue then
            breakThroughCount = #weaponBreakThroughDetailList.list
            if breakThroughCount > 1 then
                initMaxLevel = weaponBreakThroughDetailList.list[1].breakthroughLv
                maxBreakthroughLevel = breakThroughCount - 1
            end
        end
        hasValue, weaponTalentDetailList = Tables.weaponTalentTemplateTable:TryGetValue(weaponBasicData.talentTemplateId)
        if hasValue then
            maxRefineLevel = #weaponTalentDetailList.list
        end
    end
    local weaponShowData = { templateId = templateId, level = isMaxLevel and maxLevel or 1, maxLevel = isMaxLevel and maxLevel or initMaxLevel, breakthroughLevel = isMaxLevel and maxBreakthroughLevel or 0, maxBreakthroughLevel = maxBreakthroughLevel, refineLevel = isMaxLevel and maxRefineLevel or 0, }
    return weaponShowData
end
WikiWeaponCtrl._RefreshWeaponShowInfo = HL.Method(HL.Table) << function(self, weaponShowData)
    local view = self.view.right
    local isMax = weaponShowData.level == weaponShowData.maxLevel
    view.txtArr.text = isMax and Language.LUA_WIKI_WEAPON_MAX_ATTR or Language.LUA_WIKI_WEAPON_INIT_ATTR
    view.levelText.text = tostring(weaponShowData.level)
    view.maxText.text = string.format("/%d", weaponShowData.maxLevel)
    view.levelBreakNode:InitLevelBreakNodeSimple(weaponShowData.breakthroughLevel, weaponShowData.maxBreakthroughLevel, false)
    view.weaponAttributeNode:InitWeaponAttributeNodeByTemplateId(weaponShowData.templateId, isMax)
    view.weaponSkillNode:InitWeaponSkillNodeByTemplateId(weaponShowData.templateId, weaponShowData.breakthroughLevel, weaponShowData.refineLevel, isMax)
    view.potentialStar:InitWeaponPotentialStar(weaponShowData.refineLevel)
    view.btnSkill.onClick:RemoveAllListeners()
    view.btnSkill.onClick:AddListener(function()
        self.m_phase:CreateOrShowPhasePanelItem(PanelId.WikiWeaponSkill, self.m_wikiEntryShowData)
    end)
end
HL.Commit(WikiWeaponCtrl)