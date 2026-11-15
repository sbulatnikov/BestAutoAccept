-- Заглушки игрового API для прогона скриптов BestAutoAccept в texlua
local calls = {}
function LOG( ... ) local t = {} for i = 1, select( "#", ... ) do t[ #t + 1 ] = tostring( ( select( i, ... ) ) ) end calls[ #calls + 1 ] = table.concat( t, " " ) print( "  >> " .. calls[ #calls ] ) end
CALLS = calls

function Global( n, v ) _G[ n ] = v end
unpack = unpack or table.unpack
table.maxn = table.maxn or function( t ) local m = 0 for k in pairs( t ) do if type( k ) == "number" and k > m then m = k end end return m end

-- WString
local WSmt = { __tostring = function( w ) return "WS(" .. w.s .. ")" end, __eq = function( a, b ) return a.s == b.s end }
local function WSt( s ) return setmetatable( { s = s }, WSmt ) end
local rawtype = type
function type( v ) if rawtype( v ) == "table" and getmetatable( v ) == WSmt then return "userdata" end return rawtype( v ) end
function apitype( v ) if rawtype( v ) == "table" and getmetatable( v ) == WSmt then return "WString" end return rawtype( v ) end

CONFIG = {}
userMods = {
	ToWString = function( s ) return WSt( s ) end,
	FromWString = function( w ) if rawtype( w ) == "table" and getmetatable( w ) == WSmt then return w.s end error( "not WString" ) end,
	GetGlobalConfigSection = function( n ) return CONFIG[ n ] and deep( CONFIG[ n ] ) end,
	SetGlobalConfigSection = function( n, t ) CONFIG[ n ] = deep( t ) end,
	SendSelfChatMessage = function( w, lvl ) print( "  [chat:" .. tostring( lvl ) .. "] " .. w.s ) end,
}
function deep( t ) if type( t ) ~= "table" then return t end local r = {} for k, v in pairs( t ) do r[ k ] = deep( v ) end return r end

EVENTS, REACTIONS = {}, {}
local tex = setmetatable( {}, { __index = function( t, k ) return k end } )
common = {
	GetAddonName = function() return "BestAutoAccept" end,
	RegisterEventHandler = function( f, ev ) local prev = EVENTS[ ev ] EVENTS[ ev ] = prev and function( p ) prev( p ) f( p ) end or f end,
	RegisterReactionHandler = function( f, r ) REACTIONS[ r ] = f end,
	GetAbsTimeMs = function() return NOW end,
	LogInfo = function( _, s ) print( "  [mods.txt] " .. ( type( s ) == "table" and s.s or tostring( s ) ) ) end,
	IsValuedObject = function( v ) return false end,
	GetAddonRelatedTextureGroup = function() return { HasTexture = function( _, k ) return true end, GetTexture = function( _, k ) return "tex:" .. k end } end,
	GetPosConverterParams = function() return {} end,
}
NOW = 100000

-- Виджеты: создаются по запросу, помнят родителя и состояние
local Widget = {}
Widget.__index = function( w, k )
	if Widget[ k ] then return Widget[ k ] end
	return function() end
end
local function NewW( name, parent ) return setmetatable( { name = name, parent = parent, kids = {}, visible = false, text = "", pl = { posX = 0, posY = 0, sizeX = 10, sizeY = 10 } }, Widget ) end
function Widget.GetName( w ) return w.name end
function Widget.SetName( w, n ) w.name = n end
function Widget.GetParent( w ) return w.parent end
function Widget.GetChildChecked( w, n, rec )
	if not w.kids[ n ] then w.kids[ n ] = NewW( n, w ) end
	return w.kids[ n ]
end
function Widget.Show( w, on ) w.visible = on end
function Widget.IsVisible( w ) return w.visible end
function Widget.SetVal( w, tag, v ) w.val = v.s end
function Widget.SetVariant( w, v ) w.variant = v end
function Widget.SetBackgroundTexture( w, t ) w.tex = t end
function Widget.GetPlacementPlain( w ) return deep( w.pl ) end
function Widget.SetPlacementPlain( w, p ) w.pl = deep( p ) end
function Widget.GetRealRect( w ) return { x1 = 10, y1 = 10, x2 = 50, y2 = 30, x = 40, y = 20 } end
function Widget.GetText( w ) return WSt( w.text ) end
function Widget.SetText( w, t ) w.text = t.s end
function Widget.GetWidgetDesc( w ) return w end
function Widget.Enable( w, on ) w.enabled = on end
function Widget.GetInstanceId( w ) return tostring( w ) end
mainForm = NewW( "MainForm" )
function mainForm.CreateChildByDesc( _, d ) return NewW( d.name, mainForm ) end

-- Игра
ME = { name = "Я", uid = { u = "me" }, id = { o = "me" } }
STATE = { kind = "none", leader = true, members = {}, friends = { ["Арагорн"] = true }, guild = { ["Луноликая"] = true }, target = nil }
avatar = {
	IsExist = function() return true end,
	GetId = function() return ME.id end,
	GetUniqueId = function() return ME.uid end,
	GetTarget = function() return STATE.target end,
	SelectTarget = function( id ) LOG( "avatar.SelectTarget", id.o ) if STATE.selectWorks then STATE.target = id end end,
	SetFollowTarget = function( b ) LOG( "avatar.SetFollowTarget", b ) end,
	ResurrectReply = function( b ) LOG( "avatar.ResurrectReply", b ) end,
	TeleportOfferReply = function( b ) LOG( "avatar.TeleportOfferReply", b ) end,
	GetUnitList = function() return STATE.units or {} end,
}
object = {
	GetName = function( id ) if id == ME.id then return WSt( ME.name ) end return id and WSt( id.o ) end,
	IsExist = function( id ) return true end,
}
unit = { IsPlayer = function() return true end, GetGuildInfo = function() return nil end }
local function members()
	local t = {}
	for i, n in ipairs( STATE.members ) do t[ i ] = { name = WSt( n ), uniqueId = { u = n } } end
	return t
end
group = {
	IsExist = function() return STATE.kind == "party" end,
	IsLeader = function() return STATE.leader end,
	GetMembers = function() return members() end,
	InviteByName = function( w ) LOG( "group.InviteByName", w.s ) end,
	SetLeader = function( uid ) LOG( "group.SetLeader", uid.u ) end,
	StartReadyCheck = function() LOG( "group.StartReadyCheck" ) end,
	GetReadyCheckInfo = function() return STATE.ready end,
	ReportReadyCheck = function( b ) LOG( "group.ReportReadyCheck", b ) end,
	GetInviteInfo = function() return { invited = true } end,
	Accept = function() LOG( "group.Accept" ) end,
}
raid = {
	IsExist = function() return STATE.kind == "raid" end,
	IsLeader = function() return STATE.leader end,
	GetLeaderHelpers = function() return {} end,
	GetMembers = function() return { members() } end,
	InviteByName = function( w ) LOG( "raid.InviteByName", w.s ) end,
	ChangeLeader = function( uid ) LOG( "raid.ChangeLeader", uid.u ) end,
	StartReadyCheck = function() LOG( "raid.StartReadyCheck" ) end,
	GetReadyCheckInfo = function() return STATE.ready end,
	ReportReadyCheck = function( b ) LOG( "raid.ReportReadyCheck", b ) end,
	Create = function() LOG( "raid.Create" ) STATE.kind = "raid" end,
	GetInviteInfo = function() return { invited = true } end,
	Accept = function() LOG( "raid.Accept" ) end,
}
social = {
	IsFriendListLoaded = function() return true end,
	GetFriendList = function() local t, i = {}, 0 for n in pairs( STATE.friends ) do t[ i ] = n i = i + 1 end return t end,
	GetFriendInfo = function( n ) return { name = WSt( n ) } end,
	GetFriend = function( w ) return STATE.friends[ w.s ] and 1 or nil end,
	IsIgnored = function() return false end,
}
guild = { IsExist = function() return true end, GetMember = function( w ) return STATE.guild[ w.s ] and 1 or nil end }
interaction = {
	HasExchange = function() return false end,
	InviteToExchange = function( w ) LOG( "interaction.InviteToExchange", w.s ) end,
}
ENUM_LFGRole_Tank, ENUM_LFGRole_Healer, ENUM_LFGRole_DamageDealer = 0, 1, 2
lfgLib = { GetRoles = function() return { [ 0 ] = 0, 1, 2 } end, VoteYes = function( r ) LOG( "lfgLib.VoteYes", table.concat( r, "," ) ) end,
	IsRoleAvailable = function( role ) if role == 1 then return nil end return { success = role ~= 0 } end }
questionLib = {
	GetInfo = function( id ) return STATE.question end,
	SendData = function( id, t ) LOG( "questionLib.SendData", t.choice or ( "roles=" .. tostring( t.roles ) ) ) end,
}
CHAT_TYPE_WHISPER = 7
WIDGET_ALIGN_LOW_ABS = 5

READY_CHECK_READY_STATE_UNKNOWN, READY_CHECK_READY_STATE_READY, READY_CHECK_READY_STATE_NOT_READY = 0, 1, 2
function Widget.SetFocus() end

ADDON_STATE_LOADED = 3
RELOADS = {}
common.GetStateManagedAddons = function() return { { name = "Other", state = 3 }, { name = "ContextUniMessageBox", state = STATE.boxState or 3 } } end
common.StateReloadManagedAddon = function( n ) RELOADS[ #RELOADS + 1 ] = n print( "  >> reload " .. n ) end
