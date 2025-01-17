local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
FormulaNode = HL.Class('FormulaNode', UIWidgetBase)
FormulaNode.m_buildingInfo = HL.Field(HL.Userdata)
FormulaNode.m_buildingId = HL.Field(HL.String) << ''
FormulaNode.m_isMachineCrafterFormula = HL.Field(HL.Boolean) << false
FormulaNode.m_extraFormulaSpeed = HL.Field(HL.Number) << 1
FormulaNode._OnFirstTimeInit = HL.Override() << function(self)
    self.view.openBtn.onClick:AddListener(function()
        self:_ShowFormula()
    end)
end
FormulaNode.InitFormulaNode = HL.Method(HL.Userdata) << function(self, buildingInfo)
    if buildingInfo == nil then
        return
    end
    self:_FirstTimeInit()
    self.m_buildingInfo = buildingInfo
    self.m_buildingId = buildingInfo.buildingId
    self.m_extraFormulaSpeed = 1.0
    self:RefreshRedDot()
end
FormulaNode._ShowFormula = HL.Method() << function(self)
    local uiCtrl = self:GetUICtrl()
    local canvasGroup
    if uiCtrl ~= nil then
        canvasGroup = uiCtrl.view.canvasGroup
    end
    local processingCraftInfo = FactoryUtils.getBuildingProcessingCraft(self.m_buildingInfo)
    local highlightFormulaId = processingCraftInfo ~= nil and processingCraftInfo.craftId or ""
    Notify(MessageConst.FAC_SHOW_FORMULA, { nodeId = self.m_buildingInfo.nodeId, buildingId = self.m_buildingInfo.buildingId, extraSpeed = self.m_extraFormulaSpeed, isMachineCrafterFormula = self.m_isMachineCrafterFormula, belongingCanvasGroup = canvasGroup, highlightFormulaIdList = { highlightFormulaId }, })
end
FormulaNode.RefreshDisplayFormula = HL.Method(HL.Opt(HL.Table, Color)) << function(self, craftInfo, timeColor)
    if craftInfo == nil then
        self.view.craftCell.gameObject:SetActiveIfNecessary(false)
        self.view.noFormulaNode.gameObject:SetActiveIfNecessary(true)
        return
    end
    craftInfo.buildingId = nil
    self.view.craftCell:InitCraftCell(craftInfo)
    self.view.craftCell.gameObject:SetActiveIfNecessary(true)
    self.view.noFormulaNode.gameObject:SetActiveIfNecessary(false)
    if timeColor ~= nil then
        self.view.craftCell.view.time.color = timeColor
    end
end
FormulaNode.SetExtraFormulaSpeed = HL.Method(HL.Number) << function(self, extraSpeed)
    self.m_extraFormulaSpeed = extraSpeed
end
FormulaNode.RefreshRedDot = HL.Method() << function(self)
    local nodeHandler = self.m_buildingInfo.nodeHandler
    local formulaManComponentPosition = GEnums.FCComponentPos.FormulaMan:GetHashCode()
    local formulaManComponent = nodeHandler:GetComponentInPosition(formulaManComponentPosition)
    if formulaManComponent ~= nil then
        local currentMode = formulaManComponent.formulaMan.currentMode
        local isFormulaLocked = not string.isEmpty(FactoryUtils.getMachineCraftLockFormulaId(self.m_buildingInfo.nodeId))
        self.view.lockNode.gameObject:SetActive(isFormulaLocked)
        self.m_isMachineCrafterFormula = true
        if not Utils.isInBlackbox() then
            self.view.redDot.gameObject:SetActiveIfNecessary(true)
            self.view.redDot:InitRedDot("BuildingFormula", { buildingId = self.m_buildingId, modeName = currentMode })
        else
            self.view.redDot.gameObject:SetActiveIfNecessary(false)
        end
    else
        self.view.redDot.gameObject:SetActiveIfNecessary(false)
        self.m_isMachineCrafterFormula = false
    end
end
HL.Commit(FormulaNode)
return FormulaNode