local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.SpaceshipStation
SpaceshipStationCtrl = HL.Class('SpaceshipStationCtrl', uiCtrl.UICtrl)
SpaceshipStationCtrl.s_messages = HL.StaticField(HL.Table) << { [MessageConst.SPACESHIP_ON_SET_ROOM_STATION_SUCC] = 'OnSetRoomStationSucc', }
SpaceshipStationCtrl.m_roomId = HL.Field(HL.String) << ''
SpaceshipStationCtrl.m_isControlCenter = HL.Field(HL.Boolean) << false
SpaceshipStationCtrl.m_charEffectCells = HL.Field(HL.Forward('UIListCache'))
SpaceshipStationCtrl.m_getCharCell = HL.Field(HL.Function)
SpaceshipStationCtrl.m_maxStationCharNum = HL.Field(HL.Number) << -1
SpaceshipStationCtrl.m_maxLvStationCharNum = HL.Field(HL.Number) << -1
SpaceshipStationCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.closeBtn.onClick:AddListener(function()
        PhaseManager:PopPhase(PhaseId.SpaceshipStation)
    end)
    self.view.confirmBtn.onClick:AddListener(function()
        self:_OnClickConfirm()
    end)
    self.view.resetBtn.onClick:AddListener(function()
        self:_OnClickReset()
    end)
    local roomId = arg.roomId
    self.m_roomId = roomId
    self.m_isControlCenter = roomId == Tables.spaceshipConst.controlCenterRoomId
    self:_InitFilter()
    self:_InitSort()
    self.m_getCharCell = UIUtils.genCachedCellFunction(self.view.charScrollList)
    self.view.charScrollList.onUpdateCell:AddListener(function(obj, csIndex)
        self:_OnUpdateCell(self.m_getCharCell(obj), LuaIndex(csIndex))
    end)
    self.m_charEffectCells = UIUtils.genCellCache(self.view.charEffectCell)
    local spaceship = GameInstance.player.spaceship
    local room = spaceship.rooms:get_Item(roomId)
    self.m_maxStationCharNum = room.maxStationCharNum
    self.m_maxLvStationCharNum = room.maxLvStationCount
    local roomData = Tables.spaceshipRoomInsTable[roomId]
    self.view.nameTxt.text = roomData.name
    local roomTypeData = Tables.spaceshipRoomTypeTable[roomData.roomType]
    self.view.bigBgIcon:LoadSprite(UIConst.UI_SPRITE_SPACESHIP_ROOM, roomTypeData.bg .. "_shallow")
    local color = UIUtils.getColorByString(roomTypeData.color)
    self.view.colorBg.color = color
    if self.m_isControlCenter then
        self.view.colorDecoForCC.color = color
        self.view.colorDecoForCC.gameObject:SetActive(true)
        self.view.colorDeco.gameObject:SetActive(false)
    else
        self.view.colorDeco.color = color
        self.view.colorDecoForCC.gameObject:SetActive(false)
        self.view.colorDeco.gameObject:SetActive(true)
    end
    self.view.lvDotNode:InitLvDotNode(room.lv, spaceship:GetRoomMaxLvByType(room.type), color)
    self:_UpdateCharacters()
    self:_UpdateStationInfos()
end
SpaceshipStationCtrl.m_filterTags = HL.Field(HL.Table)
local FilterType = { Skill = 1, WorkState = 2, }
SpaceshipStationCtrl._InitFilter = HL.Method() << function(self)
    local inited = false
    local filterTagGroups = { { title = Language.LUA_SPACESHIP_FILTER_TITLE_SKILL, tags = {}, }, { title = Language.LUA_SPACESHIP_FILTER_TITLE_WORK_STATE, tags = { { name = Language.LUA_SPACESHIP_FILTER_TITLE_WORK_STATE_NONE, type = FilterType.WorkState, isWorking = false, isResting = false, }, { name = Language.LUA_SPACESHIP_FILTER_TITLE_WORK_STATE_RESTING, type = FilterType.WorkState, isWorking = false, isResting = true, }, { name = Language.LUA_SPACESHIP_FILTER_TITLE_WORK_STATE_WORKING, type = FilterType.WorkState, isWorking = true, isResting = false, }, }, }, }
    for t, v in pairs(Tables.spaceshipRoomTypeTable) do
        table.insert(filterTagGroups[1].tags, { name = v.name, type = FilterType.Skill, roomType = GEnums.SpaceshipRoomType.__CastFrom(t), order = t, })
    end
    table.sort(filterTagGroups[1].tags, Utils.genSortFunction({ "order" }, true))
    self.m_filterTags = nil
    self.view.filterBtn:InitFilterBtn({
        tagGroups = filterTagGroups,
        onConfirm = function(tags)
            if not inited then
                return
            end
            self:_ApplyFilter(tags)
        end,
        getResultCount = function(tags)
            return self:_GetContentFilterResultCount(tags)
        end,
    })
    inited = true
end
SpaceshipStationCtrl._ApplyFilter = HL.Method(HL.Opt(HL.Table)) << function(self, tags)
    self.m_filterTags = tags
    self:_GenCurCharInfos()
    self:_UpdateCharacters(true)
end
SpaceshipStationCtrl._IsFilterValid = HL.Method(HL.Table, HL.Opt(HL.Table)).Return(HL.Boolean) << function(self, info, tags)
    tags = tags or self.m_filterTags
    if not tags then
        return true
    end
    local groups = {}
    for _, v in ipairs(tags) do
        local list = groups[v.type]
        if not list then
            list = {}
            groups[v.type] = list
        end
        table.insert(list, v)
    end
    for _, list in pairs(groups) do
        local isPass
        for _, v in ipairs(list) do
            if v.type == FilterType.Skill then
                if info.char:HasSkillForRoom(v.roomType) then
                    isPass = true
                    break
                end
            elseif v.type == FilterType.WorkState then
                if v.isWorking == info.char.isWorking and v.isResting == info.char.isResting then
                    isPass = true
                    break
                end
            end
        end
        if not isPass then
            return false
        end
    end
    return true
end
SpaceshipStationCtrl._GetContentFilterResultCount = HL.Method(HL.Table).Return(HL.Number) << function(self, tags)
    local count = 0
    for _, v in ipairs(self.m_allCharInfos) do
        if self:_IsFilterValid(v, tags) then
            count = count + 1
        end
    end
    return count
end
SpaceshipStationCtrl._InitSort = HL.Method() << function(self)
    local sortOptions = { { name = Language.LUA_SPACESHIP_CHAR_SORT_DEFAULT, decKeys = { "chosenSortId", "isCurRoomSortId", "workingStateSortId", "stamina", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" }, incKeys = { "reverseChosenSortId", "isCurRoomSortId", "workingStateSortId", "stamina", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" }, }, { name = Language.LUA_SPACESHIP_CHAR_SORT_STAMINA, decKeys = { "chosenSortId", "stamina", "isCurRoomSortId", "workingStateSortId", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" }, incKeys = { "reverseChosenSortId", "stamina", "isCurRoomSortId", "workingStateSortId", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" }, }, { name = Language.LUA_SPACESHIP_CHAR_SORT_SKILL, decKeys = { "chosenSortId", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "isCurRoomSortId", "workingStateSortId", "stamina", "id" }, incKeys = { "reverseChosenSortId", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "isCurRoomSortId", "workingStateSortId", "stamina", "id" }, }, { name = Language.LUA_SPACESHIP_CHAR_SORT_WORKING_STATE, decKeys = { "chosenSortId", "workingStateSortId", "stamina", "isCurRoomSortId", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" }, incKeys = { "reverseChosenSortId", "workingStateSortId", "stamina", "isCurRoomSortId", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" }, }, }
    if self.m_isControlCenter then
        table.insert(sortOptions, { name = Language.LUA_SPACESHIP_CHAR_SORT_FRIENDSHIP, decKeys = { "chosenSortId", "friendship", "isCurRoomSortId", "workingStateSortId", "stamina", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" }, incKeys = { "reverseChosenSortId", "friendship", "isCurRoomSortId", "workingStateSortId", "stamina", "validSkillCount", "validSkillCountIgnoreUnlock", "maxSkillSortId", "id" }, showFriendship = true, })
    end
    self.view.sortNode:InitSortNode(sortOptions, function(data, isIncremental)
        self:_ApplySortOption(data, isIncremental, true)
    end, 0, nil, true)
end
SpaceshipStationCtrl._ApplySortOption = HL.Method(HL.Opt(HL.Table, HL.Boolean, HL.Boolean)) << function(self, sortData, isIncremental, needUpdateList)
    sortData = sortData or self.view.sortNode:GetCurSortData()
    if isIncremental == nil then
        isIncremental = self.view.sortNode.isIncremental
    end
    local spaceship = GameInstance.player.spaceship
    for _, info in ipairs(self.m_curCharInfos) do
        local chosenIndex = lume.find(self.m_chosenCharIdList, info.id)
        if chosenIndex then
            info.chosenSortId = math.maxinteger - chosenIndex
            info.reverseChosenSortId = -info.chosenSortId
        else
            info.chosenSortId = 0
            info.reverseChosenSortId = 0
        end
        info.friendship = info.char.friendship
        info.stamina = spaceship:GetCharCurStamina(info.id)
        info.isCurRoomSortId = info.char.stationedRoomId == self.m_roomId and 1 or 0
        if string.isEmpty(info.char.stationedRoomId) then
            info.workingStateSortId = 1
        else
            info.workingStateSortId = info.char.isWorking and -1 or 0
        end
    end
    local keys = isIncremental and sortData.incKeys or sortData.decKeys
    table.sort(self.m_curCharInfos, Utils.genSortFunction(keys, isIncremental))
    self.m_showFriendship = keys.showFriendship == true
    self.m_curCharInfoReverseMap = {}
    for k, v in ipairs(self.m_curCharInfos) do
        self.m_curCharInfoReverseMap[v.id] = k
    end
    if needUpdateList then
        self.view.charScrollList:UpdateCount(#self.m_curCharInfos)
    end
end
SpaceshipStationCtrl.m_allCharInfos = HL.Field(HL.Table)
SpaceshipStationCtrl.m_allCharInfoReverseMap = HL.Field(HL.Table)
SpaceshipStationCtrl.m_curCharInfos = HL.Field(HL.Table)
SpaceshipStationCtrl.m_curCharInfoReverseMap = HL.Field(HL.Table)
SpaceshipStationCtrl.m_chosenCharIdList = HL.Field(HL.Table)
SpaceshipStationCtrl._GenAllCharInfos = HL.Method() << function(self)
    self.m_allCharInfos = {}
    self.m_chosenCharIdList = {}
    self.m_allCharInfoReverseMap = {}
    local spaceship = GameInstance.player.spaceship
    local room = spaceship.rooms:get_Item(self.m_roomId)
    local roomType = room.type
    for _, id in pairs(room.stationedCharList) do
        table.insert(self.m_chosenCharIdList, id)
    end
    local index = 1
    for id, char in pairs(spaceship.characters) do
        local info = { id = id, char = char, validSkillCount = 0, validSkillCountIgnoreUnlock = 0, maxSkillSortId = math.mininteger, }
        local charSkillData = Tables.spaceshipCharSkillTable[id]
        for _, v in pairs(charSkillData.skillList) do
            local skillId = v.skillId
            local skillData = Tables.spaceshipSkillTable[skillId]
            if skillData.roomType == roomType then
                info.validSkillCountIgnoreUnlock = info.validSkillCountIgnoreUnlock + 1
                if char.skills:ContainsValue(skillId) then
                    info.validSkillCount = info.validSkillCount + 1
                end
                if skillData.sortId > info.maxSkillSortId then
                    info.maxSkillSortId = skillData.sortId
                end
            end
        end
        self.m_allCharInfos[index] = info
        self.m_allCharInfoReverseMap[id] = index
        index = index + 1
    end
end
SpaceshipStationCtrl._GenCurCharInfos = HL.Method() << function(self)
    self.m_curCharInfos = {}
    for _, v in ipairs(self.m_allCharInfos) do
        if self:_IsFilterValid(v) then
            table.insert(self.m_curCharInfos, v)
        end
    end
    self:_ApplySortOption()
end
SpaceshipStationCtrl.m_showFriendship = HL.Field(HL.Boolean) << false
SpaceshipStationCtrl._UpdateCharacters = HL.Method(HL.Opt(HL.Boolean)) << function(self, notGen)
    if not notGen then
        self:_GenAllCharInfos()
        self:_GenCurCharInfos()
    end
    local count = #self.m_curCharInfos
    self.view.charScrollList:UpdateCount(count)
    self.view.charListEmptyNode.gameObject:SetActive(count == 0)
end
SpaceshipStationCtrl._OnUpdateCell = HL.Method(HL.Forward("SSCharHeadCell"), HL.Number) << function(self, cell, index)
    local indexOfLineHead = index - ((index - 1) % self.view.charScrollList.countPerLine)
    local lineHeadCell = self.m_getCharCell(indexOfLineHead)
    local contentScreenRect = UIUtils.getUIRectOfRectTransform(self.view.content, self.uiCamera)
    local charInfo = self.m_curCharInfos[index]
    cell:InitSSCharHeadCell({
        charId = charInfo.id,
        targetRoomId = self.m_roomId,
        onClick = function()
            self:_OnClickChar(index)
        end,
        tipsPositionTrans = lineHeadCell.transform,
        padding = { bottom = self.view.transform.rect.height - contentScreenRect.yMax, },
    })
    cell.gameObject.name = "Char-" .. charInfo.id
    self:_UpdateCharCellChooseState(charInfo.id, cell)
    local chosenIndex = lume.find(self.m_chosenCharIdList, charInfo.id)
    cell:SetChooseState(chosenIndex)
    local showFriendship = self.m_isControlCenter or self.m_showFriendship
    cell.view.friendshipNode.gameObject:SetActive(showFriendship)
end
SpaceshipStationCtrl._UpdateCharChooseState = HL.Method(HL.String) << function(self, charId)
    local index = self.m_curCharInfoReverseMap[charId]
    if not index then
        return
    end
    local cell = self.m_getCharCell(index)
    if cell then
        self:_UpdateCharCellChooseState(charId, cell)
    end
end
SpaceshipStationCtrl._UpdateCharCellChooseState = HL.Method(HL.String, HL.Forward("SSCharHeadCell")) << function(self, charId, cell)
    local chosenIndex = lume.find(self.m_chosenCharIdList, charId)
    cell:SetChooseState(chosenIndex)
end
SpaceshipStationCtrl._OnClickChar = HL.Method(HL.Number) << function(self, index)
    local charInfo = self.m_curCharInfos[index]
    self:_ToggleChooseChar(charInfo.id)
end
SpaceshipStationCtrl._UpdateStationInfos = HL.Method() << function(self)
    local spaceship = GameInstance.player.spaceship
    local room = spaceship.rooms:get_Item(self.m_roomId)
    local roomData = Tables.spaceshipRoomInsTable[room.id]
    local roomLvTable = SpaceshipUtils.getRoomLvTableByType(room.roomType)
    local roomTypeData = Tables.spaceshipRoomTypeTable[roomData.roomType]
    local attrs = SpaceshipUtils.preCalcRoomAttrs(self.m_roomId, self.m_chosenCharIdList)
    self.view.ssRoomEffectInfoNode:InitSSRoomEffectInfoNode({ attrInfoList = attrs, color = UIUtils.getColorByString(roomTypeData.color), })
    local contentScreenRect = UIUtils.getUIRectOfRectTransform(self.view.content, self.uiCamera)
    local padding = { bottom = self.view.transform.rect.height - contentScreenRect.yMax, }
    self.m_charEffectCells:Refresh(self.m_maxLvStationCharNum, function(cell, index)
        local charId = self.m_chosenCharIdList[index]
        cell.gameObject.name = "Cell-" .. index
        cell.indexTxt.text = index
        local isEmpty = string.isEmpty(charId)
        local isLocked = index > self.m_maxStationCharNum
        if isEmpty then
            if isLocked then
                local needLv
                for k = room.lv + 1, room.maxLv do
                    local roomLvData = roomLvTable[k]
                    if roomLvData.stationMaxCount >= index then
                        needLv = k
                        break
                    end
                end
                cell.lockedTxt.text = string.format(Language.LUA_SPACESHIP_ROOM_UNLOCK_STATION_HINT, roomData.name, needLv)
                cell.simpleStateController:SetState("Locked")
            else
                cell.simpleStateController:SetState("Empty")
            end
        else
            cell.simpleStateController:SetState("Normal")
            cell.headCell:InitSSCharHeadCell({
                charId = charId,
                targetRoomId = self.m_roomId,
                onClick = function()
                    cell.headCell:ShowTips()
                end,
                posType = UIConst.UI_TIPS_POS_TYPE.RightTop,
                padding = padding,
            })
            cell.headCell.view.friendshipNode.gameObject:SetActive(self.m_isControlCenter)
            cell.charSkillNode:InitSSCharSkillNode(charId, self.m_roomId)
            cell.delBtn.onClick:RemoveAllListeners()
            cell.delBtn.onClick:AddListener(function()
                self:_ToggleChooseChar(charId)
            end)
            if not cell.warnCells then
                cell.warnCells = UIUtils.genCellCache(cell.skillEffectWarnCell)
            end
            local warnTextList = {}
            local char = spaceship.characters:get_Item(charId)
            if not string.isEmpty(char.stationedRoomId) and char.stationedRoomId ~= self.m_roomId then
                local otherRoomData = Tables.spaceshipRoomInsTable[char.stationedRoomId]
                table.insert(warnTextList, { state = "InOtherRoom", text = Language.LUA_SPACESHIP_CHAR_STATION_WARNING_LEAVE_ROOM, roomColor = SpaceshipUtils.getRoomColor(char.stationedRoomId), roomName = otherRoomData.name })
            end
            local info = self.m_allCharInfos[self.m_allCharInfoReverseMap[charId]]
            if info.validSkillCount == 0 then
                table.insert(warnTextList, { state = "NoSkill", text = Language.LUA_SPACESHIP_CHAR_STATION_WARNING_NO_SKILL, })
            end
            if not string.isEmpty(char.stationedRoomId) and not char.isWorking then
                table.insert(warnTextList, { state = "IsResting", text = Language.LUA_SPACESHIP_CHAR_STATION_WARNING_REST, })
            end
            cell.warnCells:Refresh(#warnTextList, function(warnCell, warnIndex)
                local warnInfo = warnTextList[warnIndex]
                warnCell.simpleStateController:SetState(warnInfo.state)
                warnCell.text.text = warnInfo.text
                if warnInfo.roomName then
                    warnCell.roomBG.gameObject:SetActive(true)
                    warnCell.roomBG.color = warnInfo.roomColor
                    warnCell.roomName.text = warnInfo.roomName
                else
                    warnCell.roomBG.gameObject:SetActive(false)
                end
            end)
        end
    end)
    local curCount = #self.m_chosenCharIdList
    self.view.stationCountDotNode:InitLvDotNode(curCount, self.m_maxStationCharNum)
    self.view.stationCountTxt.text = string.format(Language.LUA_SPACESHIP_STATION_CHAR_COUNT_FORMAT, curCount, self.m_maxStationCharNum)
end
SpaceshipStationCtrl._ToggleChooseChar = HL.Method(HL.String) << function(self, charId)
    local chosenIndex = lume.find(self.m_chosenCharIdList, charId)
    if chosenIndex then
        table.remove(self.m_chosenCharIdList, chosenIndex)
        self:_UpdateCharChooseState(charId)
        for _, v in ipairs(self.m_chosenCharIdList) do
            self:_UpdateCharChooseState(v)
        end
    else
        local curCount = #self.m_chosenCharIdList
        if curCount >= self.m_maxStationCharNum then
            Notify(MessageConst.SHOW_TOAST, Language.LUA_SPACESHIP_STATION_CHAR_MAX)
            return
        end
        table.insert(self.m_chosenCharIdList, charId)
        self:_UpdateCharChooseState(charId)
        if self.m_isControlCenter then
            Utils.triggerVoice("sim_assign_ship", charId)
        else
            Utils.triggerVoice("sim_assign_comm", charId)
        end
    end
    self:_UpdateStationInfos()
end
SpaceshipStationCtrl._OnClickReset = HL.Method() << function(self)
    local oldChars = self.m_chosenCharIdList
    self.m_chosenCharIdList = {}
    for _, v in ipairs(oldChars) do
        self:_UpdateCharChooseState(v)
    end
    self:_UpdateStationInfos()
end
SpaceshipStationCtrl.OnSetRoomStationSucc = HL.Method(HL.Table) << function(self, _)
    PhaseManager:PopPhase(PhaseId.SpaceshipStation)
end
SpaceshipStationCtrl._OnClickConfirm = HL.Method() << function(self)
    local spaceship = GameInstance.player.spaceship
    local room = spaceship.rooms:get_Item(self.m_roomId)
    local notChanged = #self.m_chosenCharIdList == room.stationedCharList.Count
    if notChanged then
        for k, id in pairs(room.stationedCharList) do
            if self.m_chosenCharIdList[LuaIndex(k)] ~= id then
                notChanged = false
                break
            end
        end
    end
    if notChanged then
        PhaseManager:PopPhase(PhaseId.SpaceshipStation)
        return
    end
    GameInstance.player.spaceship:SetRoomStation(self.m_roomId, self.m_chosenCharIdList)
end
HL.Commit(SpaceshipStationCtrl)