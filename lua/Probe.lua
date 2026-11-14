--------------------------------------------------------------------------------
-- BestAutoAccept / Probe.lua
-- Только для отладочной сборки (tools/build.py --debug): пишет в mods.txt,
-- что приходит от игры. В обычную и релизную сборку файл не попадает.
-- Включить в игре: /baa debug (выключить — так же).
--------------------------------------------------------------------------------
BAA.Probe = {}
local Probe = BAA.Probe

local function Val( v )
	local t = type( v )
	if t == "string" or t == "number" or t == "boolean" or t == "nil" then return tostring( v ) end
	if t == "userdata" then
		local api = apitype( v )
		if api == "WString" then return "W\"" .. userMods.FromWString( v ) .. "\"" end
		if api == "ValuedObjectLua" then
			return "ValuedObject type=" .. tostring( v:GetType() ) .. " text=" .. BAA.S( v:GetText() )
		end
		return tostring( v ) .. " api=" .. tostring( api )
	end
	return t
end

function Probe.Dump( t, prefix, depth, budget )
	budget = budget or { n = 200 }
	depth = depth or 0
	if type( t ) ~= "table" or depth > 4 then return end
	for k, v in pairs( t ) do
		if budget.n <= 0 then return end
		budget.n = budget.n - 1
		if type( v ) == "table" then
			BAA.File( ( prefix or "" ) .. tostring( k ) .. " = {" )
			Probe.Dump( v, ( prefix or "" ) .. "  ", depth + 1, budget )
		else
			BAA.File( ( prefix or "" ) .. tostring( k ) .. " = " .. Val( v ) )
		end
	end
end

function Probe.Question( id, info )
	if not BAA.DEBUG then return end
	BAA.File( "вопрос type=" .. tostring( info.type ) )
	Probe.Dump( info, "  " )
end

function Probe.Event( name )
	return function( p )
		if not BAA.DEBUG then return end
		BAA.File( "событие " .. name )
		Probe.Dump( p, "  " )
	end
end

-- Как игра записывает ответы на вопрос (нужно для выбора роли)
function Probe.QuestionResults( p )
	if not BAA.DEBUG then return end
	local info = questionLib.GetInfo( p.id or p.questionId )
	if type( info ) ~= "table" then return end
	BAA.File( "ответы на вопрос:" )
	Probe.Dump( info.results or {}, "  " )
	BAA.File( "lfgLib.GetRoles:" )
	Probe.Dump( lfgLib.GetRoles() or {}, "  " )
end

-- События, которые печатаются в отладочной сборке
Probe.EVENTS = {
	"EVENT_ITEMS_EXCHANGE_INVITED", "EVENT_ITEMS_EXCHANGE_STARTED", "EVENT_PASSANGER_STATE_CHANGED",
	"EVENT_LFG_VOTE", "EVENT_TELEPORT_OFFER_REQUEST", "EVENT_MATCH_MAKING_EVENT_TELEPORT_REQUEST",
	"EVENT_RESURRECT_REQUESTED", "EVENT_GROUP_INVITE", "EVENT_RAID_INVITE", "EVENT_TAKE_ON_HANDS_REQUEST",
}

-- Состояние API, которое нужно проверить в игре
function Probe.Report()
	local function has( lib, fn ) return ( type( lib ) == "table" and type( lib[ fn ] ) == "function" ) and "есть" or "нет" end
	BAA.File( "проверка API:" )
	BAA.File( "  CHAT_TYPE_WHISPER = " .. tostring( CHAT_TYPE_WHISPER ) )
	BAA.File( "  interaction.AcceptInviteToExchange: " .. has( interaction, "AcceptInviteToExchange" ) )
	BAA.File( "  family.TakeOnHandsResponse: " .. has( family, "TakeOnHandsResponse" ) )
	BAA.File( "  matchMaking.InstancedEventTeleportReply: " .. has( matchMaking, "InstancedEventTeleportReply" ) )
	BAA.File( "  VAL_OBJ_TYPE_INSTANCED_EVENT = " .. tostring( VAL_OBJ_TYPE_INSTANCED_EVENT ) ..
		", VAL_OBJ_TYPE_LFG_DESTINATION = " .. tostring( VAL_OBJ_TYPE_LFG_DESTINATION ) )
end
