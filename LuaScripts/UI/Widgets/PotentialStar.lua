local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
PotentialStar = HL.Class('PotentialStar', UIWidgetBase)
PotentialStar.m_potentialCellList = HL.Field(HL.Table)
PotentialStar.m_effectCor = HL.Field(HL.Thread)
PotentialStar._OnFirstTimeInit = HL.Override() << function(self)
    self.m_potentialCellList = {}
    for i = 1, UIConst.CHAR_MAX_POTENTIAL do
        local potentialCellName = 'potentialCell' .. i
        local cell = self.view[potentialCellName]
        cell.gameObject:SetActive(true)
        self.m_potentialCellList[i] = cell
    end
end
PotentialStar.InitCharPotentialStar = HL.Method(HL.Number, HL.Opt(HL.Boolean)) << function(self, charInstId, showMaxPotentialHint)
    self:_FirstTimeInit()
    local charInfo = CharInfoUtils.getPlayerCharInfoByInstId(charInstId)
    local fromLv = charInfo.potentialLevel
    local isPotentialMax = fromLv >= UIConst.CHAR_MAX_POTENTIAL
    for index, cell in ipairs(self.m_potentialCellList) do
        self:_InitPotentialCell(cell, isPotentialMax, index, fromLv)
    end
    self.view.maxNode.gameObject:SetActive(showMaxPotentialHint and isPotentialMax)
    self.view.finishGlowNode.gameObject:SetActive(isPotentialMax)
end
PotentialStar.InitWeaponPotentialStar = HL.Method(HL.Number, HL.Opt(HL.Table)) << function(self, toLv, args)
    self:_FirstTimeInit()
    local fromLv = toLv
    local showMaxPotentialHint = false
    local showCurLevelTransition = false
    if args then
        fromLv = args.fromLv or toLv
        showMaxPotentialHint = args.showMaxPotentialHint == true
        showCurLevelTransition = args.showCurLevelTransition == true
    end
    local isPotentialMax = toLv >= UIConst.CHAR_MAX_POTENTIAL
    if showCurLevelTransition then
        self.m_effectCor = self:_ClearCoroutine(self.m_effectCor)
        self.m_effectCor = self:_StartCoroutine(function()
            for index, cell in ipairs(self.m_potentialCellList) do
                local isCellCurActive = cell.currentLevel.gameObject.activeSelf
                self:_InitPotentialCell(cell, isPotentialMax, index, toLv)
                local isCurLevelShow = index <= fromLv
                if not isCellCurActive and isCurLevelShow then
                    cell.currentLevel:Play("weaponexhibitpotential_breakthroughcell_currentlevel_in")
                end
                coroutine.wait(0.1)
            end
        end)
    else
        for index, cell in ipairs(self.m_potentialCellList) do
            self:_InitPotentialCell(cell, isPotentialMax, index, toLv)
        end
    end
    self.view.maxNode.gameObject:SetActive(showMaxPotentialHint and isPotentialMax)
    self.view.finishGlowNode.gameObject:SetActive(isPotentialMax)
end
PotentialStar._InitPotentialCell = HL.Method(HL.Table, HL.Boolean, HL.Number, HL.Number) << function(self, cell, isPotentialMax, index, toLv)
    if isPotentialMax then
        cell.finishLevel.gameObject:SetActive(true)
        cell.currentLevel.gameObject:SetActive(false)
        cell.nextLevel.gameObject:SetActive(false)
    else
        local showNextLvIndex = toLv + 1
        cell.finishLevel.gameObject:SetActive(false)
        cell.currentLevel.gameObject:SetActive(index < showNextLvIndex)
        UIUtils.PlayAnimationAndToggleActive(cell.nextLevel, index == showNextLvIndex)
    end
end
HL.Commit(PotentialStar)
return PotentialStar