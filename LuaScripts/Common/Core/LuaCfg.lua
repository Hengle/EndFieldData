require("LuaUtils")
local setmetatable = setmetatable
local rawset = rawset
local LuaSpark = _G.LuaUtils.LuaSpark
local UnityEngine = CS.UnityEngine
local LuaCfg = {}
local Tables = {}
setmetatable(Tables, {
    __mode = "v",
    __index = function(t, k)
        if type(k) ~= 'string' then
            return nil
        end
        local root = LuaSpark.GetRoot(k)
        if root == nil then
            return nil
        end
        rawset(t, k, root)
        return root
    end
})
LuaCfg.Tables = Tables
local Types = {}
setmetatable(Types, {
    __index = function(t, k)
        if type(k) ~= 'string' then
            return nil
        end
        local type = LuaSpark.GetBeanTypeByName(k)
        if type == nil then
            return nil
        end
        rawset(t, k, type)
        rawset(t, type, k)
        return type
    end
})
LuaCfg.Types = Types
local curEnvLang = CS.Beyond.I18n.I18nUtils.curEnvLang:GetHashCode()
local function I18nGetText(id, text)
    if BEYOND_DEBUG_COMMAND then
        if CS.Beyond.I18n.I18nUtils.GetShowTextIdMode() then
            return id
        end
    end
    if curEnvLang == 0 and text ~= nil then
        return text
    elseif id == nil or id == '' then
        return text
    else
        local found, i18nText = Tables.i18nTextTable:TryGetValue(id)
        if not found or i18nText == nil or i18nText == '' then
            if BEYOND_DEBUG_COMMAND then
                local outText = ''
                if UNITY_EDITOR then
                    local openVisualText = CS.Beyond.I18n.I18nUtils.fakeI18nVisualTextEditorOnly
                    if openVisualText then
                        outText = CS.Beyond.I18n.I18nUtils.GetI18nVisualText(id, text)
                    end
                end
                if string.isEmpty(outText) then
                    outText = string.format("<color=red>!!ERROR!!I18N_NOT_FOUND:%s</color>", id)
                end
                return outText
            else
                return ''
            end
        end
        return i18nText
    end
end
LuaSpark.SetI18nGetTextFunc(I18nGetText, Types.I18nText)
local function Enum2Userdata(enumVal, enumName)
    local csEnum = GEnums[enumName]
    if csEnum == nil then
        return enumVal
    else
        return csEnum.__CastFrom(enumVal)
    end
end
local function Userdata2Enum(csEnum)
    if csEnum == nil then
        return nil
    else
        return csEnum:GetHashCode()
    end
end
LuaSpark.SetExternalEnumConvertFunc(Enum2Userdata, Userdata2Enum)
function LuaCfg.GetType(object)
    local type, typeName = LuaSpark.GetBeanType(object)
    if type ~= nil then
        rawset(Types, typeName, type)
        rawset(Types, type, typeName)
        return type, typeName
    else
        return nil
    end
end
function LuaCfg.GetEntityTypeName(entity)
    return LuaSpark.GetEntityType(entity)
end
function LuaCfg.NameOfType(type)
    return rawget(Types, type)
end
function LuaCfg.IsBean(object)
    return LuaSpark.IsBean(object)
end
function LuaCfg.IsArray(object)
    return LuaSpark.IsArray(object)
end
function LuaCfg.IsMap(object)
    return LuaSpark.IsMap(object)
end
function LuaCfg.DebugString(object)
    return LuaSpark.DebugString(object)
end
function LuaCfg.ToVector3(bean)
    if bean then
        return UnityEngine.Vector3(bean.x, bean.y, bean.z)
    else
        return UnityEngine.Vector3.zero
    end
end
function LuaCfg.ToVector2(bean)
    if bean then
        return UnityEngine.Vector2(bean.x, bean.y)
    else
        return UnityEngine.Vector2.zero
    end
end
function LuaCfg.Contains(arrayOrMap, target)
    if not (LuaSpark.IsMap(arrayOrMap) or LuaSpark.IsArray(arrayOrMap)) then
        return false
    end
    for _, v in pairs(arrayOrMap) do
        if v == target then
            return true
        end
    end
    return false
end
return LuaCfg