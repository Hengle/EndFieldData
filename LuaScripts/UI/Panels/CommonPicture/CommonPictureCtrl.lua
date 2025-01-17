local uiCtrl = require_ex('UI/Panels/Base/UICtrl')
local PANEL_ID = PanelId.CommonPicture
CommonPictureCtrl = HL.Class('CommonPictureCtrl', uiCtrl.UICtrl)
CommonPictureCtrl.s_messages = HL.StaticField(HL.Table) << {}
CommonPictureCtrl.OnCreate = HL.Override(HL.Any) << function(self, arg)
    self.view.btnClose.onClick:AddListener(function()
        self:Close()
    end)
end
CommonPictureCtrl._OnShowPicture = HL.StaticMethod(HL.String) << function(imageName)
    local self = UIManager:AutoOpen(PANEL_ID)
    self.view.image.sprite = self:LoadSprite(UIConst.UI_SPRITE_SNS_PICTURE, imageName)
end
HL.Commit(CommonPictureCtrl)