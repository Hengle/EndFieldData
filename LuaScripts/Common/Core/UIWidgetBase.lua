UIWidgetBase = HL.Class("UIWidgetBase")
UIWidgetBase.luaWidget = HL.Field(CS.Beyond.Lua.LuaUIWidget)
UIWidgetBase.loader = HL.Field(CS.Beyond.LuaResourceLoader)
UIWidgetBase.gameObject = HL.Field(GameObject)
UIWidgetBase.transform = HL.Field(Transform)
UIWidgetBase.rectTransform = HL.Field(RectTransform)
UIWidgetBase.luaPanel = HL.Field(CS.Beyond.UI.LuaPanel)
UIWidgetBase.luaCustomConfig = HL.Field(CS.Beyond.Lua.LuaCustomConfig)
UIWidgetBase.config = HL.Field(HL.Table)
UIWidgetBase.view = HL.Field(HL.Table)
UIWidgetBase.m_messageCache = HL.Field(HL.Table)
UIWidgetBase.UIWidgetBase = HL.Constructor(CS.Beyond.Lua.LuaUIWidget) << function(self, component)
    self.luaWidget = component
    self.gameObject = component.gameObject
    self.transform = component.transform
    self.rectTransform = component.transform
    self.loader = CS.Beyond.LuaResourceLoader()
    self.view = {}
    local luaRef = self.transform:GetComponent("LuaReference")
    if luaRef then
        luaRef:BindToLua(self.view)
    else
        self.view.gameObject = component.gameObject
        self.view.transform = component.transform
        self.view.rectTransform = component.transform
    end
    self.view.inputGroup = self.transform:GetComponent("InputBindingGroupMonoTarget")
    UIUtils.initLuaCustomConfig(self.view)
    self.config = self.view.config
    self.m_messageCache = {}
    self:_InitMonoLifeCycle()
    self:_OnCreate()
end
UIWidgetBase._OnCreate = HL.Virtual() << function(self)
end
UIWidgetBase.m_isFirstTimeInit = HL.Field(HL.Boolean) << true
UIWidgetBase._FirstTimeInit = HL.Method() << function(self)
    if not self.m_isFirstTimeInit then
        return
    end
    self.m_isFirstTimeInit = false
    self:_OnFirstTimeInit()
end
UIWidgetBase._OnFirstTimeInit = HL.Virtual() << function(self)
end
UIWidgetBase._InitMonoLifeCycle = HL.Method() << function(self)
    self.luaWidget.onEnable = function()
        self:_TryRegisterMessage()
        self:_OnEnable()
    end
    self.luaWidget.onDisable = function()
        self:_OnDisable()
    end
    self.luaWidget.onDestroy = function()
        self:_OnDestroy()
        self:_AfterOnDestroy()
    end
end
UIWidgetBase._OnEnable = HL.Virtual() << function(self)
end
UIWidgetBase._OnDisable = HL.Virtual() << function(self)
end
UIWidgetBase._OnDestroy = HL.Virtual() << function(self)
end
UIWidgetBase._AfterOnDestroy = HL.Method() << function(self)
    TimerManager:ClearAllTimer(self)
    CoroutineManager:ClearAllCoroutine(self)
    MessageManager:UnregisterAll(self)
    self.loader:DisposeAllHandles()
    self.luaWidget.onEnable = nil
    self.luaWidget.onDisable = nil
    self.luaWidget.onDestroy = nil
end
UIWidgetBase._StartTimer = HL.Method(HL.Number, HL.Function, HL.Opt(HL.Boolean)).Return(HL.Number) << function(self, duration, func, unscaled)
    return TimerManager:StartTimer(duration, func, unscaled, self)
end
UIWidgetBase._ClearTimer = HL.Method(HL.Number).Return(HL.Number) << function(self, timer)
    TimerManager:ClearTimer(timer)
    return -1
end
UIWidgetBase._StartCoroutine = HL.Method(HL.Function).Return(HL.Thread) << function(self, func)
    return CoroutineManager:StartCoroutine(func, self)
end
UIWidgetBase._ClearCoroutine = HL.Method(HL.Thread).Return(HL.Any) << function(self, coroutine)
    CoroutineManager:ClearCoroutine(coroutine)
    return nil
end
UIWidgetBase.GetLuaPanel = HL.Method().Return(CS.Beyond.UI.LuaPanel) << function(self)
    if not self.luaPanel then
        self.luaPanel = self.transform:GetComponentInParent(typeof(CS.Beyond.UI.LuaPanel), true)
    end
    return self.luaPanel
end
UIWidgetBase.GetPanelId = HL.Method().Return(HL.Number) << function(self)
    return self:GetLuaPanel().panelId
end
UIWidgetBase.GetUICtrl = HL.Method().Return(HL.Forward('UICtrl')) << function(self)
    local panelId = self:GetLuaPanel().panelId
    local _, ctrl = UIManager:IsOpen(panelId)
    return ctrl
end
UIWidgetBase.RegisterMessage = HL.Method(HL.Number, HL.Function) << function(self, msg, action)
    if not self.gameObject.activeInHierarchy then
        table.insert(self.m_messageCache, { msg = msg, action = action })
        return
    end
    MessageManager:Register(msg, function(msgArg)
        action(msgArg)
    end, self)
end
UIWidgetBase._TryRegisterMessage = HL.Method() << function(self)
    if not self.gameObject.activeInHierarchy then
        return
    end
    if self.m_messageCache == nil or #self.m_messageCache == 0 then
        return
    end
    for _, messageInfo in ipairs(self.m_messageCache) do
        if messageInfo ~= nil then
            self:RegisterMessage(messageInfo.msg, messageInfo.action)
        end
    end
    self.m_messageCache = {}
end
UIWidgetBase.LoadSprite = HL.Method(HL.String, HL.Opt(HL.String)).Return(HL.Opt(Unity.Sprite)) << function(self, path, name)
    return UIUtils.loadSprite(self.loader, path, name)
end
UIWidgetBase.LoadGameObject = HL.Method(HL.String).Return(HL.Opt(GameObject)) << function(self, path)
    local rst = self.loader:LoadGameObject(path)
    return rst
end
UIWidgetBase._RegisterPlayAnimationOut = HL.Method() << function(self)
    local ctrl = self:GetUICtrl()
    ctrl:RegisterPlayOutAnimWidget(self)
end
UIWidgetBase.PlayAnimationOut = HL.Virtual() << function(self)
    logger.error("UIWidgetBase.PlayAnimationOut: No Implementation!")
end
UIWidgetBase.BindInputPlayerAction = HL.Method(HL.String, HL.Function).Return(HL.Number) << function(self, actionId, callback)
    if not self.view.inputGroup then
        logger.error("该 Widget 上没有 InputBindingGroupMonoTarget", self.view.gameObject:PathFromRoot())
        return -1
    end
    local groupId = self.view.inputGroup.groupId
    return UIUtils.bindInputPlayerAction(actionId, callback, groupId)
end
UIWidgetBase.SetViewMetatable = HL.Method(HL.Table) << function(self, otherView)
    setmetatable(self.view, { __index = otherView })
end
HL.Commit(UIWidgetBase)
return UIWidgetBase