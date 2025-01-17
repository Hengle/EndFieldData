local UIWidgetBase = require_ex('Common/Core/UIWidgetBase')
FacProgressNode = HL.Class('FacProgressNode', UIWidgetBase)
local INVALID_PERCENT = -1
local INVALID_TIME_TEXT_NUMBER = -1
local MAX_PROGRESS_PERCENTAGE = 1.0
local APPROXIMATE_TOLERANCE = 0.1
FacProgressNode._OnFirstTimeInit = HL.Override() << function(self)
end
FacProgressNode.m_fillFullWidth = HL.Field(HL.Number) << -1
FacProgressNode.m_totalProgress = HL.Field(HL.Number) << -1
FacProgressNode.m_lastPercent = HL.Field(HL.Number) << -1
FacProgressNode.m_roundingTime = HL.Field(HL.Number) << -1
FacProgressNode.m_textColor = HL.Field(HL.String) << ""
FacProgressNode.m_onProgressFinished = HL.Field(HL.Function)
FacProgressNode.m_onProgressStarted = HL.Field(HL.Function)
FacProgressNode.m_needNotifyStarted = HL.Field(HL.Boolean) << false
FacProgressNode._OnDestroy = HL.Override() << function(self)
    AudioAdapter.PostEvent("au_ui_fac_producing_loop_stop")
end
FacProgressNode.InitFacProgressNode = HL.Method(HL.Number, HL.Number, HL.Opt(HL.String, HL.Function, HL.Function)) << function(self, productionTime, totalProgress, textColor, onProgressFinished, onProgressStarted)
    LayoutRebuilder.ForceRebuildLayoutImmediate(self.view.progressFill.rectTransform)
    self:_FirstTimeInit()
    self.m_fillFullWidth = self.view.rectTransform.rect.width
    self.m_totalProgress = totalProgress
    self.m_textColor = textColor or ""
    self.m_onProgressFinished = onProgressFinished
    self.m_onProgressStarted = onProgressStarted
    self.m_lastPercent = INVALID_PERCENT
    local roundingTime = math.floor(productionTime)
    self.m_roundingTime = roundingTime
    if productionTime <= 0 or totalProgress <= 0 or isInvalidNumber(roundingTime) then
        self:_RefreshProgressText(INVALID_TIME_TEXT_NUMBER)
    else
        self:_RefreshProgressText(roundingTime)
    end
    self:UpdateProgress(0)
end
FacProgressNode._RefreshProgressText = HL.Method(HL.Number) << function(self, textNumber)
    if textNumber == INVALID_TIME_TEXT_NUMBER then
        self.view.progressText.text = "--"
        return
    end
    if string.isEmpty(self.m_textColor) then
        self.view.progressText.text = string.format(Language["LUA_FAC_PROGRESS_TEXT"], math.floor(textNumber))
    else
        self.view.progressText.text = string.format(Language["LUA_FAC_PROGRESS_COLOR_TEXT"], self.m_textColor, math.floor(textNumber))
    end
end
FacProgressNode.UpdateProgress = HL.Method(HL.Number) << function(self, curProgress)
    if self.m_totalProgress <= 0 then
        self.view.progressFill.rectTransform.offsetMax = Vector2(-self.m_fillFullWidth, self.view.progressFill.rectTransform.offsetMax.y)
        return
    end
    local percent = curProgress / self.m_totalProgress
    if self.m_lastPercent == INVALID_PERCENT then
        self.m_lastPercent = percent
    end
    if percent < self.m_lastPercent then
        if MAX_PROGRESS_PERCENTAGE - self.m_lastPercent <= APPROXIMATE_TOLERANCE then
            if self.m_onProgressFinished ~= nil then
                self.m_onProgressFinished()
            end
            self.m_needNotifyStarted = true
        end
    elseif percent > self.m_lastPercent then
        if self.m_needNotifyStarted and self.m_onProgressStarted ~= nil then
            self.m_onProgressStarted()
            self.m_needNotifyStarted = false
        end
    end
    local xOffset = self.m_fillFullWidth * (1 - percent)
    self.view.progressFill.rectTransform.offsetMax = Vector2(-xOffset, self.view.progressFill.rectTransform.offsetMax.y)
    local textNumber = (1 - percent) * self.m_roundingTime
    self:_RefreshProgressText(math.ceil(textNumber))
    self.m_lastPercent = percent
end
FacProgressNode.SwitchAudioPlayingState = HL.Method(HL.Boolean) << function(self, isPlaying)
    if isPlaying then
        AudioAdapter.PostEvent("au_ui_fac_producing_loop")
    else
        AudioAdapter.PostEvent("au_ui_fac_producing_loop_stop")
    end
end
HL.Commit(FacProgressNode)
return FacProgressNode