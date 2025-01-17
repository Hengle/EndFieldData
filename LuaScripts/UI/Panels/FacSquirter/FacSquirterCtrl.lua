local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.FacSquirter
local SoilState = { None = 0, Spraying = 1, Paused = 2, Invalid = 3, Completed = 4, Waiting = 5, NotInStep = 6, }
local OutState = { None = "None", Idle = "Idle", Spraying = "Spraying", Stopped = "Stopped", }
FacSquirterCtrl = HL.Class('FacSquirterCtrl', uiCtrl.UICtrl)
local SOIL_CELL_PROGRESS_TWEEN_DURATION = 0.25
local SQUIRTER_SPRITES_FOLDER_PATH = "Factory/Squirter"
local INVALID_ITEM_TEXT_ID = "ui_fac_squirter_different_liquid"
local INVALID_SOIL_NODES_TEXT_ID = "ui_fac_squirter_no_target_info"
FacSquirterCtrl.m_buildingInfo = HL.Field(CS.Beyond.Gameplay.RemoteFactory.BuildingUIInfo_FluidSpray)
FacSquirterCtrl.m_updateThread = HL.Field(HL.Thread)
FacSquirterCtrl.m_soilNodeDataList = HL.Field(HL.Table)
FacSquirterCtrl.m_needUpdateSoilNodes = HL.Field(HL.Boolean) << false
FacSquirterCtrl.m_soilCellConfig = HL.Field(HL.Table)
FacSquirterCtrl.m_validLiquidIds = HL.Field(HL.Table)
FacSquirterCtrl.m_soilCellTweenList = HL.Field(HL.Table)
FacSquirterCtrl.m_soilCells = HL.Field(HL.Forward('UIListCache'))
FacSquirterCtrl.m_outState = HL.Field(HL.String) << ""
FacSquirterCtrl.s_messages = HL.StaticField(HL.Table) << {}
FacSquirterCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_buildingInfo = arg.uiInfo
    self.view.inventoryArea:InitInventoryArea({
        customOnUpdateCell = function(cell, itemBundle)
            self:_RefreshInventoryItemCell(cell, itemBundle)
        end
    })
    self.view.facCacheRepository:InitFacCacheRepository({ cache = self.m_buildingInfo.sprayCache, isInCache = true, isFluidCache = true, cacheIndex = 1, slotCount = 1, })
    self.view.facCachePipe:InitFacCachePipe(self.m_buildingInfo, { useSinglePipe = true, })
    self.view.buildingCommon:InitBuildingCommon(self.m_buildingInfo)
    GameInstance.remoteFactoryManager:RegisterInterestedUnitId(self.m_buildingInfo.nodeId)
    self:_InitSquirterStaticData()
    self:_InitSquirterBasicContent()
    self:_InitSquirterSoilCellColorConfig()
    self:_InitSquirterSoilNodes()
    self:_InitSquirterUpdateThread()
end
FacSquirterCtrl.OnClose = HL.Override() << function(self)
    GameInstance.remoteFactoryManager:UnregisterInterestedUnitId(self.m_buildingInfo.nodeId)
    if self.m_soilCellTweenList ~= nil then
        for _, tween in pairs(self.m_soilCellTweenList) do
            if tween ~= nil then
                tween:Kill(false)
            end
        end
    end
end
FacSquirterCtrl._InitSquirterUpdateThread = HL.Method() << function(self)
    self:_UpdateAndRefreshOutState()
    self.m_updateThread = self:_StartCoroutine(function()
        while true do
            self:_RefreshSquirterSpeed()
            self:_UpdateAndRefreshOutState()
            self:_UpdateAndRefreshSquirterAllSoilNodesState()
            coroutine.step(UIConst.FAC_COMMON_UI_MIDDLE_UPDATE_INTERVAL)
        end
    end)
end
FacSquirterCtrl._InitSquirterStaticData = HL.Method() << function(self)
    self.m_validLiquidIds = {}
    local success, tableData = Tables.factoryFluidSprayTable:TryGetValue(self.m_buildingInfo.buildingId)
    if not success then
        return
    end
    for index = 0, tableData.validItemIds.Count - 1 do
        self.m_validLiquidIds[tableData.validItemIds[index]] = true
    end
end
FacSquirterCtrl._InitSquirterBasicContent = HL.Method() << function(self)
    local success, tableData = Tables.factoryFluidSprayTable:TryGetValue(self.m_buildingInfo.buildingId)
    if not success then
        return
    end
    self.view.speedNode.maxSpeedText.text = string.format("%d", tableData.maximumSuply)
    self:_RefreshSquirterSpeed()
end
FacSquirterCtrl._RefreshSquirterSpeed = HL.Method() << function(self)
    local speed = self.m_buildingInfo.fluidSpray.lastRoundSprayCount
    self.view.speedNode.currSpeedText.text = string.format("%d", speed)
    self.view.speedNode.currSpeedText.color = speed > 0 and self.view.config.NORMAL_COLOR or self.view.config.STOPPED_COLOR
end
FacSquirterCtrl._IsCurrentCacheItemValid = HL.Method().Return(HL.Boolean) << function(self)
    local cacheItemId = ""
    for id, _ in cs_pairs(self.m_buildingInfo.sprayCache.items) do
        if not string.isEmpty(id) then
            cacheItemId = id
            break
        end
    end
    return string.isEmpty(cacheItemId) or self.m_validLiquidIds[cacheItemId] == true
end
FacSquirterCtrl._UpdateAndRefreshOutState = HL.Method() << function(self)
    local state = OutState.None
    local isValidSoilNodes = #self.m_soilNodeDataList > 0
    local isValidItem = self:_IsCurrentCacheItemValid()
    if not isValidItem or not isValidSoilNodes then
        state = OutState.Stopped
    else
        local speed = self.m_buildingInfo.fluidSpray.lastRoundSprayCount
        state = speed > 0 and OutState.Spraying or OutState.Idle
    end
    if state == self.m_outState then
        return
    end
    self.view.outNode.stateController:SetState(state)
    local isStopped = state == OutState.Stopped
    if isStopped then
        local textId = ""
        if not isValidSoilNodes then
            textId = INVALID_SOIL_NODES_TEXT_ID
        else
            textId = INVALID_ITEM_TEXT_ID
        end
        self.view.tipsTextNode.tipsText.text = Language[textId]
    end
    UIUtils.PlayAnimationAndToggleActive(self.view.tipsTextNode.animationWrapper, isStopped)
    UIUtils.PlayAnimationAndToggleActive(self.view.outNode.blockedAnim, isStopped)
    self.m_outState = state
end
FacSquirterCtrl._InitSquirterSoilCellColorConfig = HL.Method() << function(self)
    self.m_soilCellConfig = { [SoilState.Spraying] = { iconId = "icon_squirter_play", iconColor = self.view.config.NORMAL_COLOR, progressColor = self.view.config.NORMAL_COLOR, stateText = Language["ui_fac_squirter_soil_spraying"], }, [SoilState.Paused] = { iconId = "icon_squirter_pause", iconColor = self.view.config.PAUSED_COLOR, progressColor = self.view.config.PAUSED_COLOR, stateText = Language["ui_fac_squirter_soil_pause"], }, [SoilState.Invalid] = { iconId = "icon_squirter_error", iconColor = self.view.config.INVALID_COLOR, progressColor = self.view.config.INVALID_COLOR, stateText = Language["ui_fac_squirter_soil_different"], }, [SoilState.Completed] = { iconId = "icon_squirter_select", iconColor = self.view.config.COMPLETE_COLOR, progressColor = self.view.config.NORMAL_COLOR, stateText = Language["ui_fac_squirter_soil_complete"], }, [SoilState.Waiting] = { iconId = "icon_squirter_omit", iconColor = self.view.config.PAUSED_COLOR, progressColor = self.view.config.PAUSED_COLOR, stateText = Language["ui_fac_squirter_soil_waiting"], hideProgress = true, }, [SoilState.NotInStep] = { iconId = "icon_squirter_omit", iconColor = self.view.config.PAUSED_COLOR, progressColor = self.view.config.PAUSED_COLOR, stateText = Language["ui_fac_squirter_soil_step_invalid"], hideProgress = true, }, }
end
FacSquirterCtrl._InitSquirterSoilNodes = HL.Method() << function(self)
    local soilNodes = self.m_buildingInfo:GetProcessingSoilNodes()
    self.m_soilNodeDataList = {}
    self.m_soilCellTweenList = {}
    for soilNode, _ in cs_pairs(soilNodes) do
        local nodeHandler = FactoryUtils.getBuildingNodeHandler(soilNode)
        if nodeHandler ~= nil then
            local soilComponent = nodeHandler:GetComponentInPosition(GEnums.FCComponentPos.Soil:GetHashCode())
            if soilComponent ~= nil and soilComponent.soil ~= nil then
                table.insert(self.m_soilNodeDataList, { nodeHandler = nodeHandler, soilComponent = soilComponent.soil, state = SoilState.None, })
            end
        end
    end
    if #self.m_soilNodeDataList == 0 then
        self.view.targetNode.emptyNode.gameObject:SetActiveIfNecessary(true)
        self.view.targetNode.soilList.gameObject:SetActiveIfNecessary(false)
        self.m_needUpdateSoilNodes = false
        return
    end
    self.m_soilCells = UIUtils.genCellCache(self.view.targetNode.soilCell)
    self.m_soilCells:Refresh(#self.m_soilNodeDataList, function(cell, index)
        self:_RefreshSquirterSoilNodeBasicContent(cell, index)
        self:_UpdateAndRefreshSquirterSoilNodeState(cell, index, true)
    end)
    self.view.targetNode.emptyNode.gameObject:SetActiveIfNecessary(false)
    self.view.targetNode.soilList.gameObject:SetActiveIfNecessary(true)
    self.m_needUpdateSoilNodes = true
end
FacSquirterCtrl._RefreshSquirterSoilNodeBasicContent = HL.Method(HL.Any, HL.Number) << function(self, cell, index)
    if cell == nil then
        return
    end
    local data = self.m_soilNodeDataList[index]
    if data == nil then
        return
    end
    local success, facBuildingData = Tables.factoryBuildingTable:TryGetValue(data.nodeHandler.templateId)
    if not success then
        return
    end
    cell.titleNode.text.text = facBuildingData.name
end
FacSquirterCtrl._UpdateAndRefreshSquirterAllSoilNodesState = HL.Method() << function(self)
    if not self.m_needUpdateSoilNodes then
        return
    end
    local cellCount = self.m_soilCells:GetCount()
    for index = 1, cellCount do
        local cell = self.m_soilCells:GetItem(index)
        self:_UpdateAndRefreshSquirterSoilNodeState(cell, index, false)
    end
end
FacSquirterCtrl._UpdateAndRefreshSquirterSoilNodeState = HL.Method(HL.Any, HL.Number, HL.Boolean) << function(self, cell, index, firstRefresh)
    if cell == nil then
        return
    end
    local data = self.m_soilNodeDataList[index]
    if data == nil then
        return
    end
    local success, stepsData = Tables.plantingDataTable:TryGetValue(data.nodeHandler.templateId)
    if not success then
        return
    end
    local state = SoilState.None
    local step = data.soilComponent.stepCursor
    local stepData = stepsData.plantingSteps[step]
    local stepType = stepData.plantingStepType
    local currProgress, totalProgress = data.soilComponent.waterGot, -1
    if stepType ~= GEnums.PlantingStepType.Water then
        if step == 0 then
            state = SoilState.NotInStep
        else
            local lastStepType = stepsData.plantingSteps[step - 1].plantingStepType
            local isCompleted = lastStepType == GEnums.PlantingStepType.Water
            state = isCompleted and SoilState.Completed or SoilState.NotInStep
            if isCompleted then
                currProgress = totalProgress
            end
        end
    else
        local valueIntList = stepData.plantingStepParameter.valueIntList
        totalProgress = valueIntList[valueIntList.Count - 1]
        if currProgress == totalProgress then
            state = SoilState.Completed
        else
            if not self:_IsCurrentCacheItemValid() then
                state = SoilState.Invalid
            else
                if currProgress <= 0 then
                    state = SoilState.Waiting
                else
                    local currSpeed = self.m_buildingInfo.fluidSpray.lastRoundSprayCount
                    state = currSpeed > 0 and SoilState.Spraying or SoilState.Paused
                end
            end
        end
    end
    if state == data.state and not firstRefresh and state ~= SoilState.Spraying then
        return
    end
    local config = self.m_soilCellConfig[state]
    if config == nil then
        return
    end
    local iconSprite = self:LoadSprite(SQUIRTER_SPRITES_FOLDER_PATH, config.iconId)
    if iconSprite ~= nil then
        cell.stateNode.icon.sprite = iconSprite
    end
    cell.stateNode.icon.color = config.iconColor
    cell.progressNode.progressBar.color = config.progressColor
    cell.stateNode.text.text = config.stateText
    if not config.hideProgress then
        local targetAmount = currProgress / totalProgress
        if firstRefresh then
            cell.progressNode.progressBar.fillAmount = targetAmount
        else
            if self.m_soilCellTweenList[index] ~= nil then
                self.m_soilCellTweenList[index]:Kill(false)
            end
            self.m_soilCellTweenList[index] = DOTween.To(function()
                return cell.progressNode.progressBar.fillAmount
            end, function(amount)
                cell.progressNode.progressBar.fillAmount = amount
            end, targetAmount, SOIL_CELL_PROGRESS_TWEEN_DURATION)
        end
        cell.progressNode.content.gameObject:SetActiveIfNecessary(true)
    else
        cell.progressNode.content.gameObject:SetActiveIfNecessary(false)
    end
    if firstRefresh then
        if state == SoilState.Invalid then
            self:_RefreshSquirterSoilNodeAnimState(cell, state)
        end
    else
        if data.state ~= state then
            self:_RefreshSquirterSoilNodeAnimState(cell, state)
        end
    end
    data.state = state
end
FacSquirterCtrl._RefreshSquirterSoilNodeAnimState = HL.Method(HL.Any, HL.Number) << function(self, cell, state)
    local animName = "facsquirtersoil_change"
    if state == SoilState.Invalid then
        animName = "facsquirtersoil_loop"
    elseif state == SoilState.Completed then
        animName = "facsquirtersoil_done"
    end
    if cell.stateAnim.curStateName == animName then
        return
    end
    cell.stateAnim:PlayWithTween(animName)
end
FacSquirterCtrl._RefreshInventoryItemCell = HL.Method(HL.Userdata, HL.Any) << function(self, cell, itemBundle)
    if cell == nil or itemBundle == nil then
        return
    end
    local itemId = itemBundle.id
    local isEmptyBottle = Tables.emptyBottleTable:ContainsKey(itemId)
    local isFullBottle = Tables.fullBottleTable:ContainsKey(itemId)
    local isBottle = isEmptyBottle or isFullBottle
    local isEmpty = string.isEmpty(itemBundle.id)
    cell.view.forbiddenMask.gameObject:SetActiveIfNecessary(not isBottle and not isEmpty)
    cell.view.dragItem.enabled = isBottle
    cell.view.dropItem.enabled = isBottle or isEmpty
end
HL.Commit(FacSquirterCtrl)