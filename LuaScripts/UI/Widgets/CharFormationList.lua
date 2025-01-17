local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
CharFormationList = HL.Class('CharFormationList', UIWidgetBase)
CharFormationList.info = HL.Field(HL.Table)
CharFormationList.m_selectNum = HL.Field(HL.Number) << -1
CharFormationList.m_mode = HL.Field(HL.Number) << -1
CharFormationList.m_charNum = HL.Field(HL.Number) << 0
CharFormationList.m_originSingleSelect = HL.Field(HL.Number) << 0
CharFormationList.curSingleSelect = HL.Field(HL.Number) << 0
CharFormationList.cell2Select = HL.Field(HL.Table)
CharFormationList.m_select2Cell = HL.Field(HL.Table)
CharFormationList.m_charItems = HL.Field(HL.Table)
CharFormationList.m_onCharListChanged = HL.Field(HL.Function)
CharFormationList.GetCell = HL.Field(HL.Function)
CharFormationList.m_clickFunc = HL.Field(HL.Function)
CharFormationList.m_updateFunc = HL.Field(HL.Function)
CharFormationList._OnFirstTimeInit = HL.Override() << function(self)
    self.view.sortNode:InitSortNode(UIConst.CHAR_FORMATION_LIST_SORT_OPTION, function(optData, isIncremental)
        self:_OnSortChanged(optData, isIncremental)
    end, nil, false)
    self.GetCell = UIUtils.genCachedCellFunction(self.view.charScrollList)
    self.view.charScrollList.onSelectedCell:AddListener(function(obj, csIndex)
        local cellIndex = LuaIndex(csIndex)
        if self.m_mode == UIConst.CharListMode.Single then
            self:OnClickItem(cellIndex)
        else
            if DeviceInfo.usingController then
                self:_RefreshSingleSelect(cellIndex)
            end
        end
    end)
    self.view.charScrollList.getCurSelectedIndex = function()
        return CSIndex(self.curSingleSelect)
    end
    self.view.charScrollList.onUpdateCell:AddListener(function(object, index)
        self:OnUpdateCell(object, LuaIndex(index))
        if self.m_updateFunc then
            self.m_updateFunc(object, LuaIndex(index))
        end
    end)
end
CharFormationList.InitCharFormationList = HL.Method(HL.Table, HL.Opt(HL.Function)) << function(self, info, onCharListChanged)
    self:_FirstTimeInit()
    self:_InitData(info)
    self.m_onCharListChanged = onCharListChanged
end
CharFormationList._InitData = HL.Method(HL.Table) << function(self, info)
    self.info = info or {}
    self.m_selectNum = info.selectNum or 1
    if self.m_selectNum > 1 then
        self.m_mode = UIConst.CharListMode.MultiSelect
    else
        self.m_mode = UIConst.CharListMode.Single
    end
    self.m_charNum = 0
    self.cell2Select = {}
    self.m_select2Cell = {}
    self.m_charItems = {}
    self.m_originSingleSelect = 0
    self.curSingleSelect = 0
    self.m_mode = info.mode or UIConst.CharListMode.MultiSelect
end
CharFormationList._GetCharIndex = HL.Method(HL.Any).Return(HL.Number) << function(self, charInstId)
    for index = 1, #self.m_charItems do
        local charItem = self.m_charItems[index]
        if charItem.instId == charInstId then
            return index
        end
    end
    return -1;
end
CharFormationList._OnSortChanged = HL.Method(HL.Table, HL.Boolean) << function(self, optData, isIncremental)
    if self.m_charItems then
        local tmpTable = {}
        local tmpSingleInstId = 0
        if self.m_mode == UIConst.CharListMode.Single then
            local cell = self:GetCellByIndex(self.curSingleSelect)
            if cell then
                tmpSingleInstId = cell.charInfo.instId
            end
        else
            for selectIndex, cellIndex in pairs(self.m_select2Cell) do
                local cell = self:GetCellByIndex(cellIndex)
                local instId = cell.charInfo.instId
                if selectIndex and cellIndex then
                    tmpTable[instId] = selectIndex
                end
            end
        end
        local keys = isIncremental and optData.keys or optData.reverseKeys
        self:_SortData(keys, isIncremental)
        self.m_select2Cell = {}
        self.cell2Select = {}
        for cellIndex, info in pairs(self.m_charItems) do
            local cellInstId = info.instId
            local selectIndex = tmpTable[cellInstId]
            if selectIndex then
                self.m_select2Cell[selectIndex] = cellIndex
                self.cell2Select[cellIndex] = selectIndex
            end
            if tmpSingleInstId > 0 and tmpSingleInstId == cellInstId then
                self.curSingleSelect = cellIndex
            end
        end
        self:_RefreshCharList()
    end
end
CharFormationList._SortData = HL.Method(HL.Table, HL.Boolean) << function(self, keys, isIncremental)
    if self.m_charItems then
        table.sort(self.m_charItems, Utils.genSortFunction(keys, isIncremental))
    end
end
CharFormationList._RefreshCharList = HL.Method(HL.Opt(HL.Boolean)) << function(self, setTop)
    local count = #self.m_charItems
    self.view.charScrollList:UpdateCount(count, setTop or false)
    if self.m_onCharListChanged then
        self.m_onCharListChanged(self.m_charItems)
    end
end
CharFormationList._ShowMultiChars = HL.Method(HL.Opt(HL.Boolean)) << function(self, playAnim)
    for cellIndex = 1, self.view.charScrollList.count do
        local cell = self:GetCellByIndex(cellIndex)
        if cell then
            cell:SetMultiSelect(self.cell2Select[cellIndex], playAnim)
            if DeviceInfo.usingController then
                cell:SetSingleSelect(self.curSingleSelect == cellIndex)
            end
        end
    end
end
CharFormationList._ShowSingleChars = HL.Method(HL.Opt(HL.Boolean)) << function(self, playAnim)
    for cellIndex = 1, self.view.charScrollList.count do
        local cell = self:GetCellByIndex(cellIndex)
        if cell then
            cell:SetSingleModeSelected(true, playAnim)
        end
    end
end
CharFormationList._UpdateMultiSelect = HL.Method(HL.Opt(HL.Boolean)).Return(HL.Table, HL.Table) << function(self, playAnim)
    local result = {}
    local charItemList = {}
    local charInfoList = {}
    for _, cellIndex in pairs(self.m_select2Cell) do
        table.insert(result, cellIndex)
    end
    self.cell2Select = {}
    self.m_select2Cell = {}
    for index, cellIndex in pairs(result) do
        local cell = self:GetCellByIndex(cellIndex)
        self.cell2Select[cellIndex] = index
        self.m_select2Cell[index] = cellIndex
        if cell then
            cell:SetMultiSelect(index, playAnim)
        end
        local charItem = self.m_charItems[cellIndex]
        table.insert(charItemList, charItem)
        local charInfo = { charId = charItem.templateId, charInstId = charItem.instId, isLocked = charItem.isLocked, isTrail = charItem.isTrail, isReplaceable = charItem.isReplaceable }
        table.insert(charInfoList, charInfo)
    end
    return charItemList, charInfoList
end
CharFormationList._GetNextIndex = HL.Method().Return(HL.Number) << function(self)
    for index = 1, self.m_selectNum do
        if not Utils.isInclude(self.cell2Select, index) then
            return index
        end
    end
    return -1
end
CharFormationList._RefreshMode = HL.Method() << function(self)
    local singleSelected = self.m_mode == UIConst.CharListMode.Single
    for cellIndex, _ in pairs(self.cell2Select) do
        local cell = self:GetCellByIndex(cellIndex)
        if cell then
            cell:SetSingleModeSelected(singleSelected)
        end
    end
    if self.m_mode == UIConst.CharListMode.Single or DeviceInfo.usingController then
        local cell = self:GetCellByIndex(self.curSingleSelect)
        if cell then
            cell:SetSingleSelect(true)
        end
    end
end
CharFormationList.SetUpdateCellFunc = HL.Method(HL.Opt(HL.Function, HL.Function)) << function(self, updateFunc, clickFunc)
    self.m_updateFunc = updateFunc
    self.m_clickFunc = clickFunc
end
CharFormationList.OnUpdateCell = HL.Method(HL.Userdata, HL.Number, HL.Opt(HL.Function)) << function(self, object, index)
    local cell = self:GetCellByIndex(index)
    local item = self.m_charItems[index]
    cell:InitCharFormationHeadCell(item, function(arg)
        self:OnClickItem(index)
    end)
    cell:RefreshExInfo(self.info)
    if self.m_mode == UIConst.CharListMode.Single then
        cell:SetSingleModeSelected(true, false)
        cell:SetSingleSelect(self.curSingleSelect == index)
        local selectedCharInfo = self.info.selectedCharInfo
        local isUnavailable = false
        if selectedCharInfo and selectedCharInfo.isLocked then
            if (not selectedCharInfo.isReplaceable or item.templateId ~= selectedCharInfo.charId) and selectedCharInfo.charInstId ~= item.instId then
                isUnavailable = true
            end
        else
            if self.info.lockedTeamData then
                for _, char in pairs(self.info.lockedTeamData.chars) do
                    if char.isLocked and char.charId == item.templateId and char.charInstId ~= item.instId then
                        isUnavailable = true
                        break
                    end
                end
            end
        end
        cell:SetUnavailable(isUnavailable)
    else
        if DeviceInfo.usingController then
            cell:SetSingleSelect(self.curSingleSelect == index)
        end
        cell:SetMultiSelect(self.cell2Select[index], false)
        local isUnavailable = false
        if self.info.lockedTeamData then
            for _, char in pairs(self.info.lockedTeamData.chars) do
                if char.isLocked and not char.isReplaceable and char.charId == item.templateId and char.charInstId ~= item.instId then
                    isUnavailable = true
                    break
                end
            end
        end
        cell:SetUnavailable(isUnavailable)
    end
end
CharFormationList.GetCellByIndex = HL.Method(HL.Number).Return(HL.Forward("CharFormationHeadCell")) << function(self, cellIndex)
    local go = self.view.charScrollList:Get(CSIndex(cellIndex))
    local cell = nil
    if go then
        cell = self.GetCell(go)
    end
    return cell
end
CharFormationList.ShowSelectChars = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, m_charItems, playAnim)
    self.cell2Select = {}
    self.m_charNum = #m_charItems
    for index, charItem in pairs(m_charItems) do
        local cellIndex = self:_GetCharIndex(charItem.instId)
        self.cell2Select[cellIndex] = index
        self.m_select2Cell[index] = cellIndex
    end
    if self.m_mode == UIConst.UIConst.CharListMode.MultiSelect then
        self:_ShowMultiChars(playAnim)
        if DeviceInfo.usingController then
            self:_ShowSingleChars(true)
        end
    else
        self:_ShowSingleChars(playAnim)
    end
end
CharFormationList.SetMode = HL.Method(HL.Any, HL.Any) << function(self, mode, charInstId)
    self.m_mode = mode
    self.curSingleSelect = self:_GetCharIndex(charInstId)
    if self.m_mode == UIConst.CharListMode.MultiSelect and DeviceInfo.usingController and self.curSingleSelect <= 0 then
        self.curSingleSelect = 1
    end
    self.m_originSingleSelect = self.curSingleSelect
    self:_RefreshMode()
end
CharFormationList.GetEmpty = HL.Method().Return(HL.Boolean) << function(self)
    local empty
    if self.m_mode == UIConst.UIConst.CharListMode.MultiSelect then
        empty = self.m_charNum <= 0
    else
        empty = self.curSingleSelect <= 0
    end
    return empty
end
CharFormationList.UpdateCharItems = HL.Method(HL.Table) << function(self, items)
    self.m_charItems = lume.deepCopy(items)
    self.view.sortNode:SortCurData()
end
CharFormationList._GetCellSelectIndex = HL.Method(HL.Number).Return(HL.Number) << function(self, cellIndex)
    if self.cell2Select[cellIndex] ~= nil and self.cell2Select[cellIndex] > 0 then
        return self.cell2Select[cellIndex]
    else
        return -1
    end
end
CharFormationList._RefreshSingleSelect = HL.Method(HL.Number) << function(self, cellIndex)
    if self.curSingleSelect > 0 then
        local oldCell = self:GetCellByIndex(self.curSingleSelect)
        oldCell:SetSingleSelect(false)
    end
    local cell = self:GetCellByIndex(cellIndex)
    cell:SetSingleSelect(true)
    self.curSingleSelect = cellIndex
end
CharFormationList.OnClickItem = HL.Method(HL.Number, HL.Opt(HL.Function, HL.Boolean)) << function(self, cellIndex, playAnim)
    local cell = self:GetCellByIndex(cellIndex)
    local cellSelectIndex = self:_GetCellSelectIndex(cellIndex)
    if cell.isUnavailable then
        Notify(MessageConst.SHOW_TOAST, Language.LUA_TEAM_FORMATION_CAN_NOT_REPLACE)
        return
    end
    if self.m_mode == UIConst.CharListMode.Single then
        if self.curSingleSelect == cellIndex then
            if not DeviceInfo.usingController then
                return
            end
        end
        self:_RefreshSingleSelect(cellIndex)
        if self.m_clickFunc then
            self.m_clickFunc(true, cellIndex, cell.info)
        end
        self.m_charNum = 1
    else
        if DeviceInfo.usingController then
            self:_RefreshSingleSelect(cellIndex)
        end
        if cell.info.isLocked and cellSelectIndex > 0 then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_TEAM_FORMATION_CHAR_LOCKED)
            return
        end
        if cell.isDead and cellSelectIndex < 0 then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_CHAR_IS_DEAD)
            return
        end
        if cell.info.isLocked and cell.info.isReplaceable then
            local replaceSelectedIndex = nil
            for selectedIndex, index in pairs(self.m_select2Cell) do
                local selectedCell = self:GetCellByIndex(index)
                if selectedCell.info.templateId == cell.info.templateId then
                    replaceSelectedIndex = selectedIndex
                end
            end
            if replaceSelectedIndex then
                Notify(MessageConst.SHOW_POP_UP, {
                    content = Language.LUA_TEAM_FORMATION_REPLACE_CHAR,
                    onConfirm = function()
                        local replaceCell = self:GetCellByIndex(self.m_select2Cell[replaceSelectedIndex])
                        self.m_select2Cell[replaceSelectedIndex] = cellIndex
                        self.cell2Select[cellIndex] = replaceSelectedIndex
                        self.m_charItems[cellIndex].selectIndex = replaceSelectedIndex
                        replaceCell:SetMultiSelect(nil, playAnim)
                        local charItemList, charInfoList = self:_UpdateMultiSelect(playAnim)
                        if self.m_clickFunc then
                            self.m_clickFunc(false, cellIndex, cell.info, charItemList, charInfoList)
                        end
                    end,
                })
                return
            end
        end
        if self.m_charNum >= self.m_selectNum and self.cell2Select[cellIndex] == nil and replaceIndex == nil then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_CHAR_FORMATION_MAX_CHAR)
            return
        end
        if cellSelectIndex > 0 then
            local index = self.cell2Select[cellIndex]
            self.m_select2Cell[index] = nil
            self.cell2Select[cellIndex] = nil
            self.m_charItems[cellIndex].selectIndex = nil
            self.m_charNum = self.m_charNum - 1
            cell:SetMultiSelect(nil, playAnim)
        elseif self.m_charNum < self.m_selectNum then
            local curIndex = self:_GetNextIndex()
            self.m_select2Cell[curIndex] = cellIndex
            self.cell2Select[cellIndex] = curIndex
            self.m_charItems[cellIndex].selectIndex = curIndex
            self.m_charNum = curIndex
        end
        local charItemList, charInfoList = self:_UpdateMultiSelect(playAnim)
        if self.m_clickFunc then
            self.m_clickFunc(false, cellIndex, cell.info, charItemList, charInfoList)
        end
    end
end
HL.Commit(CharFormationList)
return CharFormationList