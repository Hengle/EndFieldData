local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.PuzzlePickupToast
PuzzlePickupToastCtrl = HL.Class('PuzzlePickupToastCtrl', uiCtrl.UICtrl)
PuzzlePickupToastCtrl.m_animationWrapper = HL.Field(HL.Userdata)
PuzzlePickupToastCtrl.m_toastTimerId = HL.Field(HL.Number) << -1
PuzzlePickupToastCtrl.s_messages = HL.StaticField(HL.Table) << { [MessageConst.INTERRUPT_MAIN_HUD_TOAST] = 'InterruptMainHudToast', }
PuzzlePickupToastCtrl.OnBlockPickup = HL.StaticMethod(HL.Any) << function(arg)
    LuaSystemManager.mainHudToastSystem:AddRequest("PuzzlePickup", function()
        local ctrl = UIManager:AutoOpen(PANEL_ID)
        ctrl:ShowPickupToast()
    end)
end
PuzzlePickupToastCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.m_animationWrapper = self:GetAnimationWrapper()
end
PuzzlePickupToastCtrl.ShowPickupToast = HL.Method() << function(self)
    self.m_toastTimerId = self:_StartTimer(self.view.config.SHOW_TOAST_DURATION, function()
        self.m_animationWrapper:PlayOutAnimation(function()
            self:Close()
            Notify(MessageConst.ON_ONE_MAIN_HUD_TOAST_FINISH, "PuzzlePickup")
        end)
    end)
end
PuzzlePickupToastCtrl.InterruptMainHudToast = HL.Method() << function(self)
    self.m_toastTimerId = self:_ClearTimer(self.m_toastTimerId)
    self:Close()
end
HL.Commit(PuzzlePickupToastCtrl)