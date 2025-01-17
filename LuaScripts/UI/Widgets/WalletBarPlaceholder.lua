local PlaceholderBaseWidget = require_ex('UI/Widgets/PlaceholderBaseWidget')
WalletBarPlaceholder = HL.Class('WalletBarPlaceholder', PlaceholderBaseWidget)
WalletBarPlaceholder.m_moneyIds = HL.Field(HL.Table)
WalletBarPlaceholder.m_useItemIcon = HL.Field(HL.Boolean) << false
WalletBarPlaceholder.InitWalletBarPlaceholder = HL.Method(HL.Table, HL.Opt(HL.Boolean)) << function(self, moneyIds, useItemIcon)
    self:_InitPlaceholder({ moneyIds = moneyIds, useItemIcon = useItemIcon == true })
end
WalletBarPlaceholder._InitPlaceholder = HL.Override(HL.Opt(HL.Table)) << function(self, args)
    self.m_playAnimationOutMsg = MessageConst.PLAY_WALLET_BAR_OUT_ANIM
    self.m_showMsg = MessageConst.SHOW_WALLET_BAR
    self.m_hideMsg = MessageConst.HIDE_WALLET_BAR
    self.m_moneyIds = args.moneyIds
    self.m_useItemIcon = args.useItemIcon == true
    WalletBarPlaceholder.Super._InitPlaceholder(self, args)
end
WalletBarPlaceholder.GetArgs = HL.Override().Return(HL.Table) << function(self)
    local trans = DeviceInfo.usingController and self.view.controllerPosition or self.view.transform
    local uiCam = self.luaPanel.uiCamera
    local targetScreenRect = UIUtils.getTransformScreenRect(trans, uiCam)
    local pos = UIUtils.screenPointToUI(Vector2(targetScreenRect.xMax, targetScreenRect.yMin), uiCam, self.luaPanel.transform)
    return { panelId = self.m_panelId, moneyIds = self.m_moneyIds, offset = self.config.PANEL_ORDER_OFFSET, paddingRight = self.luaPanel.transform.rect.width / 2 - pos.x, paddingTop = self.luaPanel.transform.rect.height / 2 + pos.y, useMoneyCellAction = self.config.USE_ACTION, useItemIcon = self.m_useItemIcon }
end
HL.Commit(WalletBarPlaceholder)
return WalletBarPlaceholder