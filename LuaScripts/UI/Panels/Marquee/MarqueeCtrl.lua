local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.Marquee
MarqueeCtrl = HL.Class('MarqueeCtrl', uiCtrl.UICtrl)
MarqueeCtrl.s_messages = HL.StaticField(HL.Table) << {}
MarqueeCtrl.m_tweenCore = HL.Field(HL.Any)
MarqueeCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
end
MarqueeCtrl.OnClose = HL.Override() << function(self)
    self.m_tweenCore:Kill()
    self.m_tweenCore = nil
end
MarqueeCtrl._PlayMarquee = HL.Method(HL.Table) << function(self, arg)
    if self.m_tweenCore then
        self.m_tweenCore:Kill()
    end
    local text, speed = unpack(arg)
    local textNode = self.view.textNode
    textNode.text = text
    LayoutRebuilder.ForceRebuildLayoutImmediate(textNode.transform)
    local textWidth = textNode.transform.rect.width
    local maskWidth = self.view.mask.rect.width
    local duration = (maskWidth + textWidth) / speed
    textNode.transform.anchoredPosition = Vector2(maskWidth, textNode.transform.anchoredPosition.y)
    self.m_tweenCore = textNode.transform:DOAnchorPosX(-textWidth, duration):SetEase(CS.DG.Tweening.Ease.Linear):OnComplete(function()
        self:PlayAnimationOutAndClose()
    end)
end
MarqueeCtrl.OnMarqueeStart = HL.StaticMethod(HL.Table) << function(arg)
    local isOpen, ctrl = UIManager:IsOpen(PANEL_ID)
    if not isOpen then
        ctrl = UIManager:Open(PANEL_ID)
    end
    ctrl:_PlayMarquee(arg)
end
HL.Commit(MarqueeCtrl)