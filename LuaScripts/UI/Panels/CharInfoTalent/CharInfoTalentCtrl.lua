local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CharInfoTalent
CharInfoTalentCtrl = HL.Class('CharInfoTalentCtrl', uiCtrl.UICtrl)
CharInfoTalentCtrl.s_messages = HL.StaticField(HL.Table) << { [MessageConst.ON_CHAR_TALENT_UPGRADE] = "OnCharTalentUpgrade", [MessageConst.ON_CLOSE_SKILL_UPGRADE_POPUP] = "OnCloseSkillUpgradePopup", [MessageConst.TRY_CLOSE_CHAR_TALENT] = "TryClose", [MessageConst.CHAR_INFO_CANCEL_TALENT_SELECT] = "_CancelSelect", [MessageConst.CHAR_INFO_TALENT_REMOTE_EXCHANGE_TO_SKILL] = "_ExchangeToSkill", [MessageConst.CHAR_INFO_TALENT_EXIT_EXPAND_NODE] = "_ExternalExitExpandNode", }
CharInfoTalentCtrl.m_attributeStageCellCache = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_passiveStageCellCacheA = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_passiveStageCellCacheB = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_shipSkillStageCellCacheA = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_shipSkillStageCellCacheB = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_skillLayoutCache = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_attributeCellCache = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_passiveCellCacheA = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_passiveCellCacheB = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_passiveLineCacheA = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_passiveLineCacheB = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_shipLineCacheA = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_shipLineCacheB = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_shipCellCacheA = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_shipCellCacheB = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_eliteCellCache = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_maxRankCellCache = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_lvFillCellCache = HL.Field(HL.Forward("UIListCache"))
CharInfoTalentCtrl.m_charInfo = HL.Field(HL.Table)
CharInfoTalentCtrl.m_attrNodeList = HL.Field(HL.Table)
CharInfoTalentCtrl.m_passiveSkillNodeList = HL.Field(HL.Table)
CharInfoTalentCtrl.m_shipSkillNodeList = HL.Field(HL.Table)
CharInfoTalentCtrl.m_selectableGroup = HL.Field(HL.Table)
CharInfoTalentCtrl.m_curSelectedCell = HL.Field(HL.Userdata)
CharInfoTalentCtrl.m_isShowSkill = HL.Field(HL.Boolean) << false
CharInfoTalentCtrl.m_isExpanding = HL.Field(HL.Boolean) << false
CharInfoTalentCtrl.m_arg = HL.Field(HL.Any)
CharInfoTalentCtrl.m_isInInitTransition = HL.Field(HL.Boolean) << false
local BIG_SCALE_CHAR_TEMPLATE_ID_DICT = { "" }
CharInfoTalentCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self:_InitActionEvent()
    self.view.btnExchange.gameObject:SetActive(false)
    local charInfo = arg.initCharInfo
    self.m_charInfo = charInfo
    self.m_arg = arg
    local enterAnimName = self:_GetEnterAnimName()
    self.view.animation:SeekToPercent(enterAnimName, 0)
end
CharInfoTalentCtrl.OnShow = HL.Override() << function(self)
    local charInfo = self.m_charInfo
    local arg = self.m_arg
    local isFastEnter, nodeId = self:_CheckIsPanelFastEnter(charInfo, arg)
    self:_RefreshPanelScale(charInfo)
    self.m_isInInitTransition = true
    self:_RefreshTalentPanel(charInfo, { showBgTransition = true, isFastEnter = isFastEnter })
    self.m_isInInitTransition = false
    self:_RefreshTrail()
    self.view.skillDragPanel.gameObject:SetActive(false)
    self.view.talentDragPanel.gameObject:SetActive(false)
    local isEndmin = CharInfoUtils.isEndmin(charInfo.templateId)
    local skillExpandAnim = isEndmin and "charinfo_talent_expand_skill_talent_admini" or "charinfo_talent_expand_skill_talent"
    self.view.animationNode:SeekToPercent(skillExpandAnim, 0)
end
CharInfoTalentCtrl.PhaseCharInfoPanelShowFinal = HL.Method(HL.Any) << function(self, arg)
    local charInfo = arg.initCharInfo
    self.m_isExpanding = false
    self.m_charInfo = charInfo
    self.m_arg = arg
    self:Show()
    local isFastEnter, nodeId = self:_CheckIsPanelFastEnter(charInfo, arg)
    if isFastEnter then
        local enterAnimName = self:_GetEnterAnimName()
        self.view.animation:SeekToPercent(enterAnimName, 1)
    end
    if arg.extraArg then
        if arg.extraArg.showNextCharBreak then
            self:_SelectCharBreakNodeId(charInfo, nodeId, isFastEnter)
        elseif arg.extraArg.showSkillGroupType then
            self:_SelectSkillGroupType(charInfo, arg.extraArg.showSkillGroupType, isFastEnter)
        elseif arg.extraArg.showPassiveSkillId then
            self:_SelectPassiveSkillNodeId(charInfo, arg.extraArg.showPassiveSkillId, isFastEnter)
        elseif arg.extraArg.showCharBreakNodeId then
            self:_SelectCharBreakNodeId(charInfo, arg.extraArg.showCharBreakNodeId, isFastEnter)
        end
    end
    if isFastEnter then
        return
    end
    local enterAnimName = self:_GetEnterAnimName()
    self.view.animation:Play(enterAnimName)
end
CharInfoTalentCtrl._CheckIsPanelFastEnter = HL.Method(HL.Table, HL.Table).Return(HL.Boolean, HL.Opt(HL.String)) << function(self, charInfo, arg)
    if not arg then
        return false
    end
    local extraArg = arg.extraArg
    if not extraArg then
        return false
    end
    if extraArg.showNextCharBreak then
        local nodeId = self:_getNextCharBreakStageNodeId(charInfo.instId)
        if nodeId then
            return true, nodeId
        end
    end
    if extraArg.showSkillGroupType or extraArg.showPassiveSkillId or extraArg.showCharBreakNodeId then
        return true
    end
end
CharInfoTalentCtrl._GetEnterAnimName = HL.Method().Return(HL.String) << function(self)
    local isEndmin = CharInfoUtils.isEndmin(self.m_charInfo.templateId)
    if isEndmin then
        return "charinfo_talent_adminifirst_in"
    else
        return "charinfo_talent_first_in"
    end
end
CharInfoTalentCtrl._RefreshPanelScale = HL.Method(HL.Table) << function(self, charInfo)
    local templateId = charInfo.templateId
    local charDisplayData = CharInfoUtils.getCharDisplayData(templateId)
    self.view.offset.transform.localScale = charDisplayData.talentPanelScale
end
CharInfoTalentCtrl._SelectSkillGroupType = HL.Method(HL.Table, HL.Any, HL.Opt(HL.Boolean)) << function(self, charInfo, showSkillGroupType, isFast)
    self.m_isShowSkill = true
    for i = 1, self.m_skillLayoutCache:GetCount() do
        local cell = self.m_skillLayoutCache:Get(i)
        if cell.skillGroupType == showSkillGroupType then
            self:_OnClickCellDefault(cell.btnSkill.view.imageSelect, isFast)
        end
    end
    local skillGroupCfg = CharInfoUtils.getCharSkillGroupCfgByType(charInfo.templateId, showSkillGroupType)
    local skillInfo = CharInfoUtils.getCharSkillLevelInfoByType(charInfo, showSkillGroupType)
    Notify(MessageConst.CHAR_TALENT_SHOW_SKILL, { charInstId = charInfo.instId, skillGroupId = skillGroupCfg.skillGroupId, skillGroupType = showSkillGroupType, curSkillLv = skillInfo.level, })
end
CharInfoTalentCtrl._SelectCharBreakNodeId = HL.Method(HL.Table, HL.String, HL.Opt(HL.Boolean)) << function(self, charInfo, nodeId, isFast)
    for i = 1, self.m_eliteCellCache:GetCount() do
        local cell = self.m_eliteCellCache:Get(i)
        local validNode = cell.elite.nodeCfg ~= nil and cell.elite or cell.equip
        if validNode.nodeCfg.nodeId == nodeId then
            self:_OnClickCellDefault(validNode.selected, isFast)
        end
    end
    Notify(MessageConst.CHAR_TALENT_SHOW_CHAR_BREAK, { charInstId = charInfo.instId, nodeId = nodeId, })
end
CharInfoTalentCtrl._SelectPassiveSkillNodeId = HL.Method(HL.Table, HL.String, HL.Opt(HL.Boolean)) << function(self, charInfo, nodeId, isFast)
    for i = 1, self.m_passiveCellCacheA:GetCount() do
        local cell = self.m_passiveCellCacheA:Get(i)
        if cell.nodeCfg.nodeId == nodeId then
            self:_OnClickCellDefault(cell.selected, isFast)
        end
    end
    for i = 1, self.m_passiveCellCacheB:GetCount() do
        local cell = self.m_passiveCellCacheB:Get(i)
        if cell.nodeCfg.nodeId == nodeId then
            self:_OnClickCellDefault(cell.selected, isFast)
        end
    end
    local talentNode = CharInfoUtils.getTalentNodeCfg(charInfo.templateId, nodeId)
    local passiveSkillNodeInfo = talentNode.passiveSkillNodeInfo
    local nodeIndex = passiveSkillNodeInfo.index
    local nodeLevel = passiveSkillNodeInfo.level
    Notify(MessageConst.CHAR_TALENT_SHOW_PASSIVE_SKILL, { charInstId = self.m_charInfo.instId, nodeIndex = nodeIndex, selectNodeLv = nodeLevel, })
end
CharInfoTalentCtrl._SelectAttributeSkillNodeId = HL.Method(HL.Table, HL.String) << function(self, charInfo, nodeId)
    for i = 1, self.m_attributeCellCache:GetCount() do
        local cell = self.m_attributeCellCache:Get(i)
        if cell.nodeCfg.nodeId == nodeId then
            self:_OnClickCellDefault(cell.selected)
        end
    end
    local talentCfg = CharInfoUtils.getTalentNodeCfg(charInfo.templateId, nodeId)
    Notify(MessageConst.CHAR_TALENT_SHOW_ATTRIBUTE, { charInstId = charInfo.instId, talentCfg = talentCfg })
end
CharInfoTalentCtrl._SelectShipSkillNodeId = HL.Method(HL.Table, HL.String) << function(self, charInfo, nodeId)
    for i = 1, self.m_shipCellCacheA:GetCount() do
        local cell = self.m_shipCellCacheA:Get(i)
        if cell.nodeCfg.nodeId == nodeId then
            self:_OnClickCellDefault(cell.selected)
        end
    end
    for i = 1, self.m_shipCellCacheB:GetCount() do
        local cell = self.m_shipCellCacheB:Get(i)
        if cell.nodeCfg.nodeId == nodeId then
            self:_OnClickCellDefault(cell.selected)
        end
    end
    local talentNode = CharInfoUtils.getTalentNodeCfg(charInfo.templateId, nodeId)
    local skillId = CharInfoUtils.getShipSkillIdByTalentNodeId(self.m_charInfo.templateId, talentNode.nodeId)
    local shipSkillCfg = Tables.spaceshipSkillTable[skillId]
    local factorySkillNodeInfo = talentNode.factorySkillNodeInfo
    Notify(MessageConst.CHAR_TALENT_SHOW_SHIP_SKILL, { charInstId = self.m_charInfo.instId, skillId = shipSkillCfg.id, selectSkillLv = shipSkillCfg.level, skillIndex = factorySkillNodeInfo.index })
end
CharInfoTalentCtrl.TryClose = HL.Method() << function(self)
    if self.m_isExpanding then
        self:_ToggleExpandNode(false)
    else
        self.view.animation:Play("charinfo_talent_default_out")
        self:Notify(MessageConst.P_CHAR_INFO_PAGE_CHANGE, { pageType = UIConst.CHAR_INFO_PAGE_TYPE.OVERVIEW })
    end
end
CharInfoTalentCtrl.OnCharTalentUpgrade = HL.Method(HL.Table) << function(self, arg)
    local charInstId, nodeId = unpack(arg)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
    local charGrowthCfg = Tables.charGrowthTable[charInst.templateId]
    local success, nodeCfg = charGrowthCfg.talentNodeMap:TryGetValue(nodeId)
    local isCharBreak = false
    if nodeCfg then
        isCharBreak = nodeCfg.nodeType == GEnums.TalentNodeType.CharBreak
    end
    if nodeCfg.nodeType == GEnums.TalentNodeType.CharBreak then
        AudioAdapter.PostEvent("Au_UI_Event_CharEliteUp")
        if Tables.characterConst.maxBreak == charInst.breakStage then
            Utils.triggerVoice("chrup_promt_lower", charInst.templateId)
        else
            Utils.triggerVoice("chrup_promt_high", charInst.templateId)
        end
        self:_SelectCharBreakNodeId(self.m_charInfo, nodeId)
    elseif nodeCfg.nodeType == GEnums.TalentNodeType.EquipBreak then
        self:_SelectCharBreakNodeId(self.m_charInfo, nodeId)
    elseif nodeCfg.nodeType == GEnums.TalentNodeType.PassiveSkill then
        self:_SelectPassiveSkillNodeId(self.m_charInfo, nodeId)
        Utils.triggerVoice("chrup_skill_new", self.m_charInfo.templateId)
    elseif nodeCfg.nodeType == GEnums.TalentNodeType.FactorySkill then
        self:_SelectShipSkillNodeId(self.m_charInfo, nodeId)
        Utils.triggerVoice("chrup_skill_new", self.m_charInfo.templateId)
    elseif nodeCfg.nodeType == GEnums.TalentNodeType.Attr then
        self:_SelectAttributeSkillNodeId(self.m_charInfo, nodeId)
        Utils.triggerVoice("chrup_skill_new", self.m_charInfo.templateId)
    end
    self:_RefreshTalentPanel(self.m_charInfo, { showBgTransition = nodeCfg.nodeType == GEnums.TalentNodeType.CharBreak, isInBreakTransition = nodeCfg.nodeType == GEnums.TalentNodeType.CharBreak })
end
CharInfoTalentCtrl.OnCloseSkillUpgradePopup = HL.Method(HL.Opt(HL.Any)) << function(self, arg)
    local _, skillGroupId = unpack(arg)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(self.m_charInfo.instId)
    local skillGroupCfg = CharInfoUtils.getSkillGroupCfg(charInst.templateId, skillGroupId)
    if not skillGroupCfg then
        return
    end
    self:_RefreshTalentPanel(self.m_charInfo, { isInSkillUpgrade = true })
    if skillGroupCfg then
        self:_SelectSkillGroupType(self.m_charInfo, skillGroupCfg.skillGroupType, false)
    end
end
CharInfoTalentCtrl._getNextCharBreakStageNodeId = HL.Method(HL.Number).Return(HL.Opt(HL.String)) << function(self, charInstId)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
    local charBreakCostMap = Tables.charGrowthTable[charInst.templateId].charBreakCostMap
    for nodeId, breakNode in pairs(charBreakCostMap) do
        if breakNode.breakStage == charInst.breakStage + 1 then
            return nodeId
        end
    end
end
CharInfoTalentCtrl._RebuildAllLayout = HL.Method() << function(self)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.skillRoot.transform)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.attributeNode.transform)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.passiveNodeA.transform)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.passiveNodeB.transform)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.shipNodeA.transform)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.shipNodeB.transform)
end
CharInfoTalentCtrl._InitActionEvent = HL.Method() << function(self)
    self.m_skillLayoutCache = UIUtils.genCellCache(self.view.skillLayout)
    self.m_attributeStageCellCache = UIUtils.genCellCache(self.view.attributeNode.breakStage)
    self.m_passiveStageCellCacheA = UIUtils.genCellCache(self.view.passiveNodeA.breakStage)
    self.m_passiveStageCellCacheB = UIUtils.genCellCache(self.view.passiveNodeB.breakStage)
    self.m_shipSkillStageCellCacheA = UIUtils.genCellCache(self.view.shipNodeA.breakStage)
    self.m_shipSkillStageCellCacheB = UIUtils.genCellCache(self.view.shipNodeB.breakStage)
    self.m_attributeCellCache = UIUtils.genCellCache(self.view.attributeNode.attributeCell)
    self.m_passiveCellCacheA = UIUtils.genCellCache(self.view.passiveNodeA.passiveCellA)
    self.m_passiveCellCacheB = UIUtils.genCellCache(self.view.passiveNodeB.passiveCellB)
    self.m_shipCellCacheA = UIUtils.genCellCache(self.view.shipNodeA.shipCellA)
    self.m_shipCellCacheB = UIUtils.genCellCache(self.view.shipNodeB.shipCellB)
    self.m_eliteCellCache = UIUtils.genCellCache(self.view.eliteNode.eliteCell)
    self.m_maxRankCellCache = UIUtils.genCellCache(self.view.maxRankCell)
    self.m_lvFillCellCache = UIUtils.genCellCache(self.view.eliteBar.lvFillCell)
    self.m_passiveLineCacheA = UIUtils.genCellCache(self.view.passiveNodeA.charTalentLine)
    self.m_passiveLineCacheB = UIUtils.genCellCache(self.view.passiveNodeB.charTalentLine)
    self.m_shipLineCacheA = UIUtils.genCellCache(self.view.shipNodeA.charTalentLine)
    self.m_shipLineCacheB = UIUtils.genCellCache(self.view.shipNodeB.charTalentLine)
    self.m_attributeStageCellCache:Refresh(Tables.characterConst.maxBreak)
    self.m_passiveStageCellCacheA:Refresh(Tables.characterConst.maxBreak)
    self.m_passiveStageCellCacheB:Refresh(Tables.characterConst.maxBreak)
    self.m_shipSkillStageCellCacheA:Refresh(Tables.characterConst.maxBreak)
    self.m_shipSkillStageCellCacheB:Refresh(Tables.characterConst.maxBreak)
    self.view.btnExchange.onClick:RemoveAllListeners()
    self.view.btnExchange.onClick:AddListener(function()
        self:_ExchangeToSkill(not self.m_isShowSkill)
    end)
    self.view.btnUpgrade.onClick:RemoveAllListeners()
    self.view.btnUpgrade.onClick:AddListener(function()
        local charInst = CharInfoUtils.getPlayerCharInfoByInstId(self.m_charInfo.instId)
        local isTrail = charInst.charType == GEnums.CharType.Trial
        if isTrail then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_CHAR_INFO_UPGRADE_FORBID)
            return
        end
        self:Notify(MessageConst.P_CHAR_INFO_PAGE_CHANGE, { pageType = UIConst.CHAR_INFO_PAGE_TYPE.UPGRADE, isFast = true, showGlitch = true, })
    end)
    self.view.skillDragPanel.onDragToUp:AddListener(function()
        self:_ExchangeToSkill(false)
    end)
    self.view.skillDragPanel.onDragToDown:AddListener(function()
        self:_ExchangeToSkill(true)
    end)
    self.view.talentDragPanel.onDragToUp:AddListener(function()
        self:_ExchangeToSkill(false)
    end)
    self.view.talentDragPanel.onDragToDown:AddListener(function()
        self:_ExchangeToSkill(true)
    end)
end
CharInfoTalentCtrl._RefreshTalentPanel = HL.Method(HL.Table, HL.Opt(HL.Table)) << function(self, charInfo, arg)
    local attrNodes, passiveSkillNodeList, shipSkillNodeList = CharInfoUtils.classifyTalentNode(charInfo.templateId)
    self.m_charInfo = charInfo
    self.m_attrNodeList = attrNodes
    self.m_passiveSkillNodeList = passiveSkillNodeList
    self.m_shipSkillNodeList = shipSkillNodeList
    self.m_selectableGroup = {}
    self.m_attributeCellCache:Refresh(#self.m_attrNodeList, function(cell, index)
        local attrNode = self.m_attrNodeList[index]
        self:_RefreshAttributeCell(cell, attrNode, self.m_attributeStageCellCache)
    end)
    self:_RefreshMainSkillNode(charInfo, arg and arg.isInSkillUpgrade)
    self:_RefreshPassiveSkillNode(charInfo)
    self:_RefreshFacSkillNode(charInfo)
    self:_RefreshEliteNode(charInfo)
    self:_RefreshTalentBg(charInfo, arg)
    self:_RebuildAllLayout()
    self:_RefreshPassiveSkillLine(charInfo)
    self:_RefreshFacSkillLine(charInfo)
end
CharInfoTalentCtrl._RefreshTrail = HL.Method() << function(self)
    local isTrailCard = CharInfoUtils.checkIsCardInTrail(self.m_charInfo.instId)
    self.view.btnUpgrade.gameObject:SetActive(not isTrailCard)
end
CharInfoTalentCtrl._RefreshFacSkillLine = HL.Method(HL.Table) << function(self, charInfo)
    local lineInfoGroupA = self:_GenerateNodeLineInfo(self.m_shipCellCacheA, charInfo.instId, self._CheckIfShowShipLine, CharInfoUtils.getShipSkillNodeStatus)
    local lineInfoGroupB = self:_GenerateNodeLineInfo(self.m_shipCellCacheB, charInfo.instId, self._CheckIfShowShipLine, CharInfoUtils.getShipSkillNodeStatus)
    self.m_shipLineCacheA:Refresh(#lineInfoGroupA, function(cell, index)
        local lineInfo = lineInfoGroupA[index]
        self:_RefreshNodeLineDefault(cell, lineInfo)
    end)
    self.m_shipLineCacheB:Refresh(#lineInfoGroupB, function(cell, index)
        local lineInfo = lineInfoGroupB[index]
        self:_RefreshNodeLineDefault(cell, lineInfo)
    end)
end
CharInfoTalentCtrl._RefreshPassiveSkillLine = HL.Method(HL.Table) << function(self, charInfo)
    local lineInfoGroupA = self:_GenerateNodeLineInfo(self.m_passiveCellCacheA, charInfo.instId, self._CheckIfShowPassiveLine, CharInfoUtils.getPassiveSkillNodeStatus)
    local lineInfoGroupB = self:_GenerateNodeLineInfo(self.m_passiveCellCacheB, charInfo.instId, self._CheckIfShowPassiveLine, CharInfoUtils.getPassiveSkillNodeStatus)
    self.m_passiveLineCacheA:Refresh(#lineInfoGroupA, function(cell, index)
        local lineInfo = lineInfoGroupA[index]
        self:_RefreshNodeLineDefault(cell, lineInfo)
    end)
    self.m_passiveLineCacheB:Refresh(#lineInfoGroupB, function(cell, index)
        local lineInfo = lineInfoGroupB[index]
        self:_RefreshNodeLineDefault(cell, lineInfo)
    end)
end
CharInfoTalentCtrl._GenerateNodeLineInfo = HL.Method(HL.Userdata, HL.Number, HL.Function, HL.Function).Return(HL.Table) << function(self, cellCache, charInstId, checkLineFunc, checkNodeFunc)
    local lineInfoGroup = {}
    for i = 1, cellCache:GetCount() - 1 do
        local cell = cellCache:Get(i)
        local nextCell = cellCache:Get(i + 1)
        if cell and nextCell then
            local nodeCfg = cell.nodeCfg
            local nextNodeCfg = nextCell.nodeCfg
            local isActive, isLock = checkNodeFunc(charInstId, nodeCfg.nodeId)
            local nextIsActive, nextIsLock = checkNodeFunc(charInstId, nextNodeCfg.nodeId)
            if checkLineFunc(self, nodeCfg, nextNodeCfg) then
                local startX = cell.rectTransform.anchoredPosition.x + cell.rectTransform.parent.anchoredPosition.x
                local endX = nextCell.rectTransform.anchoredPosition.x + nextCell.rectTransform.parent.anchoredPosition.x
                table.insert(lineInfoGroup, { startY = cell.rectTransform.anchoredPosition.y, startX = startX, endX = endX, isActive = isActive, nextIsActive = nextIsActive, })
            end
        end
    end
    return lineInfoGroup
end
CharInfoTalentCtrl._CheckIfShowPassiveLine = HL.Method(HL.Userdata, HL.Userdata).Return(HL.Boolean) << function(self, nodeCfg, nextNodeCfg)
    return nodeCfg.passiveSkillNodeInfo.index == nextNodeCfg.passiveSkillNodeInfo.index
end
CharInfoTalentCtrl._CheckIfShowShipLine = HL.Method(HL.Userdata, HL.Userdata).Return(HL.Boolean) << function(self, nodeCfg, nextNodeCfg)
    return true
end
CharInfoTalentCtrl._RefreshNodeLineDefault = HL.Method(HL.Table, HL.Table) << function(self, cell, lineInfo)
    local width = lineInfo.endX - lineInfo.startX
    cell.rectTransform.anchoredPosition = Vector2(lineInfo.startX, lineInfo.startY)
    cell.rectTransform.sizeDelta.y = width
    cell.activationLine.gameObject:SetActive(lineInfo.nextIsActive)
    cell.canActiveLine.gameObject:SetActive(lineInfo.isActive and not lineInfo.nextIsActive)
    cell.defaultLine.gameObject:SetActive(not lineInfo.isActive)
end
CharInfoTalentCtrl._RefreshCharMaxRankNode = HL.Method(HL.Table) << function(self, charInfo)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInfo.instId)
    self.m_maxRankCellCache:Refresh(Tables.characterConst.maxBreak, function(cell, index)
        local charBreakStageCfg = Tables.charBreakStageTable[CSIndex(index) + 1]
        local isReach = index > charInst.breakStage
        local isCurrent = index == charInst.breakStage
        cell.lockIcon.gameObject:SetActive(isReach)
        cell.maxRank.text = string.format(Language.LUA_CHAR_INFO_TALENT_SKILL_MAX_LEVEL_PREFIX, charBreakStageCfg.normalSkillLevel)
        cell.lockIcon.color = isCurrent and self.view.config.MAX_RANK_COLOR_CURRENT or self.view.config.MAX_RANK_COLOR_DEFAULT
        cell.maxRank.color = isCurrent and self.view.config.MAX_RANK_COLOR_CURRENT or self.view.config.MAX_RANK_COLOR_DEFAULT
        cell.maxRank.fontSize = isCurrent and self.view.config.MAX_RANK_SIZE_CURRENT or self.view.config.MAX_RANK_SIZE_DEFAULT
        if Tables.characterConst.maxBreak == index then
            cell.maxRank.text = Language.LUA_CHAR_INFO_TALENT_ELITE
        end
    end)
end
CharInfoTalentCtrl._RefreshMainSkillNode = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, charInfo, isInSkillUpgrade)
    local mainSkills, showOrderList = CharInfoUtils.classifyMainSkillUpgradeNodes(charInfo.instId)
    self.m_skillLayoutCache:Refresh(#showOrderList, function(cell, index)
        local skillGroupId = showOrderList[index]
        local _, charGrowthData = Tables.charGrowthTable:TryGetValue(charInfo.templateId)
        local skillGroupType = charGrowthData.skillGroupMap[skillGroupId].skillGroupType
        self:_RefreshMainSkillLayout(cell, charInfo, skillGroupId, skillGroupType, isInSkillUpgrade == true)
    end)
    self:_RefreshCharMaxRankNode(charInfo)
end
CharInfoTalentCtrl._RefreshMainSkillLayout = HL.Method(HL.Table, HL.Table, HL.String, HL.Userdata, HL.Boolean) << function(self, cell, charInfo, skillGroupId, skillGroupType, isInSkillUpgrade)
    local skillInfo = CharInfoUtils.getCharSkillLevelInfo(charInfo, skillGroupId)
    if not skillInfo then
        cell.gameObject:SetActive(false)
        return
    end
    local curSkillLv = skillInfo.level
    local curMaxLv = skillInfo.maxLevel
    local showSkillLv = lume.clamp(curSkillLv, 1, UIConst.CHAR_MAX_SKILL_NORMAL_LV)
    local showMaxLv = lume.clamp(curMaxLv, 1, UIConst.CHAR_MAX_SKILL_NORMAL_LV)
    cell.skillGroupType = skillGroupType
    cell.rank.text = string.format(Language.LUA_CHAR_INFO_TALENT_SKILL_LEVEL_PREFIX, showSkillLv)
    cell.rankMax.text = string.format(Language.LUA_CHAR_INFO_TALENT_LEVEL_POSTFIX, showMaxLv)
    cell.skillGroupType = skillGroupType
    cell.btnSkill:InitCharInfoSkillButtonNew(charInfo, skillGroupType, function()
        self.m_isShowSkill = true
        self:_OnClickCellDefault(cell.btnSkill.view.imageSelect)
        Notify(MessageConst.CHAR_TALENT_SHOW_SKILL, { charInstId = charInfo.instId, skillGroupId = skillGroupId, skillGroupType = skillGroupType, curSkillLv = curSkillLv, })
    end)
    cell.btnSkill:RefreshRedDot()
    local breakCount = #Tables.charBreakStageTable - 1
    local lastStageUpgradeCount = 0
    local skillLevel = 1
    if cell.skillBreakGroupCache == nil then
        cell.skillBreakGroupCache = UIUtils.genCellCache(cell.skillBreakGroup)
    end
    cell.skillBreakGroupCache:Refresh(breakCount - 1, function(cell, index)
        local extraOffset = index == 1 and 1 or 0
        cell.paddingControl.gameObject:SetActive(index == 1)
        if cell.skillCellCache == nil then
            cell.skillCellCache = UIUtils.genCellCache(cell.skillCell)
        end
        local canUpgradeCount = CharInfoUtils.getSkillCanUpgradeLv(skillGroupType, index)
        cell.skillCellCache:Refresh(canUpgradeCount - lastStageUpgradeCount - extraOffset, function(cell, index)
            skillLevel = skillLevel + 1
            local isActive = curSkillLv >= skillLevel
            local isLocked = skillLevel > curMaxLv
            local isActiveBefore = cell.upgradedShadow.gameObject.activeSelf
            cell.lockedShadow.gameObject:SetActive(isLocked)
            cell.upgradedShadow.gameObject:SetActive(isActive)
            cell.defaultShadow.gameObject:SetActive(not isActive and not isLocked)
            if isInSkillUpgrade and not isActiveBefore and isActive then
                cell.upgradedShadow:Play("charinfotalent_skillcell_upgradedshadow_in")
            end
        end)
        lastStageUpgradeCount = canUpgradeCount
    end)
    local canUpgradeToElite = curMaxLv > UIConst.CHAR_MAX_SKILL_NORMAL_LV
    cell.eliteNode.transform:SetSiblingIndex(cell.transform.childCount)
    cell.elitePolygon:InitElitePolygon(curSkillLv - UIConst.CHAR_MAX_SKILL_NORMAL_LV)
    cell.normalNode.gameObject:SetActive(canUpgradeToElite)
    cell.emptyNodeShadow.gameObject:SetActive(not canUpgradeToElite)
end
CharInfoTalentCtrl._RefreshPassiveSkillNode = HL.Method(HL.Table) << function(self, charInfo)
    local passiveSkillNodeListA = self.m_passiveSkillNodeList[0] or {}
    local passiveSkillNodeListB = self.m_passiveSkillNodeList[1] or {}
    self.m_passiveCellCacheA:Refresh(#passiveSkillNodeListA, function(cell, index)
        local node = passiveSkillNodeListA[index]
        self:_RefreshPassiveSkillCell(cell, node, self.m_passiveStageCellCacheA)
    end)
    self.m_passiveCellCacheB:Refresh(#passiveSkillNodeListB, function(cell, index)
        local node = passiveSkillNodeListB[index]
        self:_RefreshPassiveSkillCell(cell, node, self.m_passiveStageCellCacheB)
    end)
end
CharInfoTalentCtrl._RefreshFacSkillNode = HL.Method(HL.Table) << function(self, charInfo)
    local shipSkillNodeA = self.m_shipSkillNodeList[1] or {}
    local shipSkillNodeListA = shipSkillNodeA.nodeList or {}
    local shipSkillNodeB = self.m_shipSkillNodeList[2] or {}
    local shipSkillNodeListB = shipSkillNodeB.nodeList or {}
    if not shipSkillNodeListA or #shipSkillNodeListA <= 0 then
        logger.info("角色养成->角色没有配置工厂技能A templateId = " .. tostring(charInfo.templateId))
    end
    self.m_shipCellCacheA:Refresh(#shipSkillNodeListA, function(cell, index)
        local node = shipSkillNodeListA[index]
        self:_RefreshShipSkillCell(cell, node, self.m_shipSkillStageCellCacheA, shipSkillNodeA.skillIndex)
    end)
    if not shipSkillNodeB or #shipSkillNodeListB <= 0 then
        logger.info("角色养成->角色没有配置工厂技能B, templateId = " .. tostring(charInfo.templateId))
    end
    self.m_shipCellCacheB:Refresh(#shipSkillNodeListB, function(cell, index)
        local node = shipSkillNodeListB[index]
        self:_RefreshShipSkillCell(cell, node, self.m_shipSkillStageCellCacheB, shipSkillNodeB.skillIndex)
    end)
end
CharInfoTalentCtrl._RefreshTalentBg = HL.Method(HL.Table, HL.Opt(HL.Table)) << function(self, charInfo, arg)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInfo.instId)
    local breakStage = charInst.breakStage
    local showBgTransition = arg.showBgTransition
    local isInBreakTransition = false
    local isFastEnter = false
    if arg then
        isInBreakTransition = arg.isInBreakTransition == true
        isFastEnter = arg.isFastEnter == true
    end
    if showBgTransition then
        if isInBreakTransition then
            local transitionAnimName = string.format("charinfo_talent_bg_lv%s_to_lv%s", breakStage - 1, breakStage)
            self.view.content:Play(transitionAnimName)
        else
            local idleAnimName = string.format("charinfo_talent_bg_lv%s", breakStage)
            if isFastEnter then
                self.view.content:SeekToPercent(idleAnimName, 1)
            else
                self.view.content:Play(idleAnimName)
            end
        end
    end
end
CharInfoTalentCtrl._RefreshEliteNode = HL.Method(HL.Table) << function(self, charInfo)
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(charInfo.instId)
    local charGrowthCfg = Tables.charGrowthTable[charInfo.templateId]
    local allBreakNodeList = {}
    local charBreakNodeList = {}
    local equipBreakNodeList = {}
    for _, breakNode in pairs(charGrowthCfg.charBreakCostMap) do
        if breakNode.nodeType == GEnums.TalentNodeType.CharBreak or breakNode.nodeType == GEnums.TalentNodeType.EquipBreak then
            table.insert(allBreakNodeList, breakNode)
            if breakNode.nodeType == GEnums.TalentNodeType.CharBreak then
                table.insert(charBreakNodeList, breakNode)
            elseif breakNode.nodeType == GEnums.TalentNodeType.EquipBreak then
                table.insert(equipBreakNodeList, breakNode)
            end
        end
    end
    if #charBreakNodeList <= 0 then
        logger.error("角色养成->角色没有配置角色突破节点 templateId = " .. tostring(charInfo.templateId))
        return
    end
    table.sort(allBreakNodeList, function(a, b)
        if a.breakStage ~= b.breakStage then
            return a.breakStage < b.breakStage
        else
            return a.equipTierLimit < b.equipTierLimit
        end
    end)
    local _, _, curLv, maxLevel = CharInfoUtils.getCharExpInfo(charInst.instId)
    self.m_eliteCellCache:Refresh(#allBreakNodeList, function(cell, index)
        local breakCfg = allBreakNodeList[index]
        local isCharBreak = breakCfg.nodeType == GEnums.TalentNodeType.CharBreak
        cell.elite.gameObject:SetActive(isCharBreak)
        cell.equip.gameObject:SetActive(not isCharBreak)
        if isCharBreak then
            local isActive, isLock = CharInfoUtils.getCharBreakNodeStatus(charInst.instId, breakCfg.nodeId)
            self:_RefreshNodeCellDefault({ cell = cell.elite, isActive = isActive, isLock = isLock, nodeCfg = breakCfg, })
            if isActive then
                cell.elite.activated.charEliteMarker:InitCharEliteMarkerByBreakStage(breakCfg.breakStage)
            elseif isLock then
                cell.elite.lock.charEliteMarker:InitCharEliteMarkerByBreakStage(breakCfg.breakStage)
            else
                cell.elite.canActivate.charEliteMarker:InitCharEliteMarkerByBreakStage(breakCfg.breakStage)
            end
            cell.elite.button.onClick:RemoveAllListeners()
            cell.elite.button.onClick:AddListener(function()
                self:_OnClickCellDefault(cell.elite.selected)
                Notify(MessageConst.CHAR_TALENT_SHOW_CHAR_BREAK, { charInstId = charInfo.instId, nodeId = breakCfg.nodeId, })
            end)
            cell.elite.redDot:InitRedDot("CharBreakNode", { charInst.instId, breakCfg.nodeId })
        else
            local isActive, isLock = CharInfoUtils.getEquipBreakNodeStatus(charInst.instId, breakCfg.nodeId)
            self:_RefreshNodeCellDefault({ cell = cell.equip, isActive = isActive, isLock = isLock, nodeCfg = breakCfg, })
            cell.equip.button.onClick:RemoveAllListeners()
            cell.equip.button.onClick:AddListener(function()
                self:_OnClickCellDefault(cell.equip.selected)
                Notify(MessageConst.CHAR_TALENT_SHOW_EQUIP_BREAK, { charInstId = charInfo.instId, nodeId = breakCfg.nodeId, breakStage = breakCfg.breakStage })
            end)
            cell.equip.stageLevelCellGroup:InitStageLevelCellGroup(breakCfg.breakStage, isLock)
            cell.equip.redDot:InitRedDot("EquipBreakNode", { charInst.instId, breakCfg.nodeId })
        end
    end)
    self.m_lvFillCellCache:Refresh(Tables.characterConst.maxBreak - 1, function(cell, index)
        local reachStage = charInst.breakStage >= charBreakNodeList[index + 1].breakStage - 1
        local breakStage = charBreakNodeList[index + 1].breakStage
        self:_RefreshEliteFillCell(cell, curLv, breakStage - 1, reachStage)
    end)
    local reachFirstStage = charInst.breakStage >= charBreakNodeList[1].breakStage - 1
    self:_RefreshEliteFillCell(self.view.eliteBar.firstLvFillCell, curLv, charBreakNodeList[1].breakStage - 1, reachFirstStage)
    local reachLastStage = charInst.breakStage == Tables.characterConst.maxBreak
    self.view.eliteBar.lastLvFillCell.gameObject:SetActive(reachLastStage)
    if reachLastStage then
        self:_RefreshEliteFillCell(self.view.eliteBar.lastLvFillCell, curLv, Tables.characterConst.maxBreak, reachLastStage)
    end
    local breakStateCount = Tables.characterConst.maxBreak
    local eliteNode = self.view.eliteNode
    eliteNode.charEliteMarker:InitCharEliteMarker(charInfo.instId, true)
    eliteNode.eliteCur.text = charInst.breakStage
    eliteNode.eliteMax.text = string.format(Language.LUA_CHAR_INFO_TALENT_LEVEL_POSTFIX, breakStateCount)
    local _, _, curLv, maxLevel = CharInfoUtils.getCharExpInfo(charInst.instId)
    eliteNode.curLv.text = curLv
    eliteNode.stageLv.text = string.format(Language.LUA_CHAR_INFO_TALENT_LEVEL_POSTFIX, maxLevel)
end
CharInfoTalentCtrl._RefreshEliteFillCell = HL.Method(HL.Table, HL.Number, HL.Number, HL.Boolean) << function(self, cell, curLv, breakStage, reachStage)
    local breakStageCfg = Tables.charBreakStageTable[breakStage]
    local gap = breakStageCfg.maxCharLevel - breakStageCfg.minCharLevel
    local curLvGap = curLv - breakStageCfg.minCharLevel
    cell.curLvFill.fillAmount = curLvGap / gap
    cell.stageLvFill.gameObject:SetActive(reachStage and curLvGap >= 0)
    cell.curLvFill.gameObject:SetActive(reachStage and curLvGap >= 0)
end
CharInfoTalentCtrl._RefreshAttributeCell = HL.Method(HL.Table, HL.Userdata, HL.Any) << function(self, cell, talentCfg, breakCellCache)
    local attrNodeInfo = talentCfg.attributeNodeInfo
    local attrType = attrNodeInfo.attributeModifier.attrType
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(self.m_charInfo.instId)
    local isActive, isLock = CharInfoUtils.getAttributeNodeStatus(charInst.instId, talentCfg.nodeId)
    local charInstId = self.m_charInfo.instId
    local breakStage = attrNodeInfo.breakStage
    local breakParent = breakCellCache:Get(breakStage)
    self:_RefreshNodeCellDefault({ cell = cell, isActive = isActive, isLock = isLock, stageParent = breakParent, nodeCfg = talentCfg, })
    local attrKey = Const.ATTRIBUTE_TYPE_2_ATTRIBUTE_DATA_KEY[attrType]
    cell.activated.icon.sprite = self:LoadSprite(UIConst.UI_SPRITE_ATTRIBUTE_ICON, UIConst.UI_ATTRIBUTE_ICON_PREFIX .. attrKey)
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        self.m_isShowSkill = false
        self:_OnClickCellDefault(cell.selected)
        Notify(MessageConst.CHAR_TALENT_SHOW_ATTRIBUTE, { charInstId = charInstId, talentCfg = talentCfg })
    end)
    cell.redDot:InitRedDot("CharAttrNode", { charInstId, talentCfg.nodeId })
end
CharInfoTalentCtrl._RefreshPassiveSkillCell = HL.Method(HL.Table, HL.Userdata, HL.Any) << function(self, cell, talentNode, breakCellCache)
    local passiveSkillNodeInfo = talentNode.passiveSkillNodeInfo
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(self.m_charInfo.instId)
    local isActive, isLock = CharInfoUtils.getPassiveSkillNodeStatus(charInst.instId, talentNode.nodeId)
    local breakStage = passiveSkillNodeInfo.breakStage
    local breakParent = breakCellCache:Get(breakStage)
    self:_RefreshNodeCellDefault({ cell = cell, isActive = isActive, isLock = isLock, stageParent = breakParent, nodeCfg = talentNode, })
    local nodeIndex = passiveSkillNodeInfo.index
    local nodeLevel = passiveSkillNodeInfo.level
    cell.stageLevelCellGroup:InitStageLevelCellGroup(nodeLevel, isLock)
    cell.activated.icon.sprite = self:LoadSprite(UIConst.UI_SPRITE_SKILL_ICON, passiveSkillNodeInfo.iconId)
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        self.m_isShowSkill = false
        self:_OnClickCellDefault(cell.selected)
        Notify(MessageConst.CHAR_TALENT_SHOW_PASSIVE_SKILL, { charInstId = self.m_charInfo.instId, nodeIndex = nodeIndex, selectNodeLv = nodeLevel, })
    end)
    cell.redDot:InitRedDot("PassiveSkillNode", { charInst.instId, talentNode.nodeId })
end
CharInfoTalentCtrl._RefreshShipSkillCell = HL.Method(HL.Table, HL.Userdata, HL.Any, HL.Number) << function(self, cell, talentNode, breakCellCache, skillIndex)
    local skillId = CharInfoUtils.getShipSkillIdByTalentNodeId(self.m_charInfo.templateId, talentNode.nodeId)
    local factorySkillNodeInfo = talentNode.factorySkillNodeInfo
    local shipSkillCfg = Tables.spaceshipSkillTable[skillId]
    if not shipSkillCfg then
        logger.error("CharInfoTalentCtrl->_RefreshPassiveSkillCell: skillId not found in SpaceshipSkillTable, skillId = " .. tostring(skillId))
        return
    end
    local charInst = CharInfoUtils.getPlayerCharInfoByInstId(self.m_charInfo.instId)
    local isActive, isLock = CharInfoUtils.getShipSkillNodeStatus(charInst.instId, talentNode.nodeId)
    cell.activated.stageLevel.text = shipSkillCfg.skillNamePostfix
    if isActive then
        cell.activated.icon.sprite = self:LoadSprite(UIConst.UI_SPRITE_SS_SKILL_ICON, shipSkillCfg.icon)
    else
        cell.activated.icon.sprite = self:LoadSprite(UIConst.UI_SPRITE_SS_SKILL_ICON, string.format("%s_grey", shipSkillCfg.icon))
    end
    local breakStage = factorySkillNodeInfo.breakStage
    local breakParent = breakCellCache:Get(breakStage)
    self:_RefreshNodeCellDefault({ cell = cell, isActive = isActive, isLock = isLock, stageParent = breakParent, nodeCfg = talentNode, })
    cell.button.onClick:RemoveAllListeners()
    cell.button.onClick:AddListener(function()
        self.m_isShowSkill = false
        self:_OnClickCellDefault(cell.selected)
        Notify(MessageConst.CHAR_TALENT_SHOW_SHIP_SKILL, { charInstId = self.m_charInfo.instId, skillId = shipSkillCfg.id, selectSkillLv = shipSkillCfg.level, skillIndex = skillIndex })
    end)
    cell.redDot:InitRedDot("ShipSkillNode", { charInst.instId, talentNode.nodeId })
end
CharInfoTalentCtrl._RefreshNodeCellDefault = HL.Method(HL.Table) << function(self, arg)
    local cell = arg.cell
    local isActive = arg.isActive
    local isLock = arg.isLock
    local stageParent = arg.stageParent
    cell.nodeCfg = arg.nodeCfg
    cell.lock.gameObject:SetActive(isLock)
    if cell.lock.animationWrapper then
        cell.lock.animationWrapper:SampleToInAnimationBegin()
    end
    cell.activated.gameObject:SetActive(isActive)
    cell.canActivate.gameObject:SetActive(not isActive and not isLock)
    if not self.m_isInInitTransition then
        if cell.isActiveBefore == false and isActive == true then
            if cell.activated.animationWrapper then
                cell.activated.animationWrapper:PlayInAnimation()
            end
        end
        if cell.isLockBefore == true and isLock == false then
            if cell.lock.animationWrapper then
                cell.canActivate.gameObject:SetActive(false)
                cell.lock.gameObject:SetActive(true)
                cell.lock.animationWrapper:PlayInAnimation()
            end
        end
    end
    cell.isLockBefore = isLock
    cell.isActiveBefore = isActive
    cell.selected.gameObject:SetActive(false)
    if stageParent then
        cell.transform:SetParent(stageParent.transform, false)
        cell.transform:Reset()
    end
end
CharInfoTalentCtrl._ToggleExpandNode = HL.Method(HL.Boolean, HL.Opt(HL.Boolean)) << function(self, isExpand, isFast)
    if isFast == nil then
        isFast = false
    end
    local charTemplateId = self.m_charInfo.templateId
    local isEndmin = CharInfoUtils.isEndmin(charTemplateId)
    if self.m_isExpanding == isExpand then
        return
    end
    self.view.skillDragPanel.gameObject:SetActive(isExpand and self.m_isShowSkill)
    self.view.talentDragPanel.gameObject:SetActive(isExpand and not self.m_isShowSkill)
    if self.view.animation.isPlaying then
        local animationName = self:_GetEnterAnimName()
        self.view.animation:Stop()
        self.view.animation:SeekToPercent(animationName, 1)
    end
    if isExpand then
        local skillExpandAnim = isEndmin and "charinfo_talent_expand_skill_talent_admini" or "charinfo_talent_expand_skill_talent"
        local talentExpandAnim = isEndmin and "charinfo_talent_expand_talentadmini" or "charinfo_talent_expand_talent"
        if self.m_isShowSkill then
            self.view.btnExchangeText.text = Language.LUA_CHAR_INFO_TALENT_EXCHANGE_TALENT
            if isFast then
                self.view.animationNode:SeekToPercent(skillExpandAnim, 1)
            else
                self.view.animationNode:Play(skillExpandAnim)
            end
        else
            self.view.btnExchangeText.text = Language.LUA_CHAR_INFO_TALENT_EXCHANGE_SKILL
            if isFast then
                self.view.animationNode:SeekToPercent(talentExpandAnim, 1)
            else
                self.view.animationNode:Play(talentExpandAnim)
            end
        end
        self.view.arrowUp.gameObject:SetActive(self.m_isShowSkill)
        self.view.arrowDown.gameObject:SetActive(not self.m_isShowSkill)
    else
        self:_CancelSelect()
        local backAnim = isEndmin and "charinfo_talent_default_admini" or "charinfo_talent_default"
        if self.m_isShowSkill then
            backAnim = isEndmin and "charinfo_talent_expand_skill_talent_adminiback" or "charinfo_talent_expand_skill_talent_back"
        end
        self.view.animationNode:Play(backAnim)
    end
    if isExpand then
        Notify(MessageConst.CHAR_TALENT_FOCUS, isFast)
        self.view.skillRootNode.blocksRaycasts = self.m_isShowSkill
        self.view.talentRoot.blocksRaycasts = not self.m_isShowSkill
    else
        Notify(MessageConst.CHAR_TALENT_LEAVE_FOCUS, isFast)
        self.view.skillRootNode.blocksRaycasts = true
        self.view.talentRoot.blocksRaycasts = true
    end
    self.view.btnExchange.gameObject:SetActive(isExpand)
    self.m_isExpanding = isExpand
end
CharInfoTalentCtrl._CancelSelect = HL.Method() << function(self)
    if self.m_curSelectedCell then
        self.m_curSelectedCell.gameObject:SetActive(false)
        self.m_curSelectedCell = nil
    end
end
CharInfoTalentCtrl._OnClickCellDefault = HL.Method(HL.Userdata, HL.Opt(HL.Boolean)) << function(self, selected, isFast)
    self:_ToggleExpandNode(true, isFast)
    if self.m_curSelectedCell then
        self.m_curSelectedCell.gameObject:SetActive(false)
    end
    selected.gameObject:SetActive(true)
    self.m_curSelectedCell = selected
end
CharInfoTalentCtrl._ExternalExitExpandNode = HL.Method() << function(self)
    self:_StartCoroutine(function()
        coroutine.wait(0.1)
        self:_ToggleExpandNode(false)
    end)
end
CharInfoTalentCtrl._ExchangeToSkill = HL.Method(HL.Boolean) << function(self, isSkill)
    if isSkill == self.m_isShowSkill then
        return
    end
    self.m_isShowSkill = isSkill
    self.view.skillDragPanel.gameObject:SetActive(self.m_isExpanding and isSkill)
    self.view.talentDragPanel.gameObject:SetActive(self.m_isExpanding and not isSkill)
    local charInfo = self.m_charInfo
    local isEndmin = CharInfoUtils.isEndmin(charInfo.templateId)
    if isSkill then
        local toSkillAnim = isEndmin and "charinfo_talent_expand_skilladmini" or "charinfo_talent_expand_skill"
        self.view.btnExchangeText.text = Language.LUA_CHAR_INFO_TALENT_EXCHANGE_TALENT
        self.view.animationNode:Play(toSkillAnim)
    else
        local toTalentAnim = isEndmin and "charinfo_talent_expand_skillbackadmini" or "charinfo_talent_expand_skillback"
        self.view.btnExchangeText.text = Language.LUA_CHAR_INFO_TALENT_EXCHANGE_SKILL
        self.view.animationNode:Play(toTalentAnim)
    end
    self.view.arrowUp.gameObject:SetActive(isSkill)
    self.view.arrowDown.gameObject:SetActive(not isSkill)
    self.view.skillRootNode.blocksRaycasts = isSkill
    self.view.talentRoot.blocksRaycasts = not isSkill
end
HL.Commit(CharInfoTalentCtrl)