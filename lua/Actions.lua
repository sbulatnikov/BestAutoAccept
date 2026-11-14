--------------------------------------------------------------------------------
-- BestAutoAccept / Actions.lua
-- Команды из личных сообщений и автопринятие приглашений.
--------------------------------------------------------------------------------
BAA.Act = {}
local A = BAA.Act
local S, WS = BAA.S, BAA.WS

local GROUP_SIZE = 6

local function ToastCmd( code, text ) if BAA.UI then BAA.UI.Toast( { code = code, text = text } ) end end
local function ToastAcc( icon, text ) if BAA.UI then BAA.UI.Toast( { icon = icon, text = text } ) end end
local function ToastWarn( code, text ) if BAA.UI then BAA.UI.Toast( { code = code, text = text, warn = true } ) end end

--------------------------------------------------------------------------------
-- Формирование
--------------------------------------------------------------------------------
local function Kind()
	if raid.IsExist() then return "raid" end
	if group.IsExist() then return "party" end
	return "none"
end

local function IAmRaidHelper()
	local helpers = raid.GetLeaderHelpers()
	-- Ожидаем: GetLeaderHelpers может вернуть nil — помощников нет
	if type( helpers ) ~= "table" then return false end
	local me = avatar.GetUniqueId()
	for _, uid in pairs( helpers ) do
		if uid == me then return true end
	end
	return false
end

local function CanManageRaid()
	return raid.IsLeader() or IAmRaidHelper()
end

-- Участник нашего формирования: { uniqueId, name } по UniqueId или нику
local function FindMember( uid, name )
	local low = BAA.Lower( name or "" )
	local function match( m )
		if not m then return false end
		if uid and m.uniqueId and m.uniqueId == uid then return true end
		return BAA.Lower( S( m.name ) ) == low
	end
	if raid.IsExist() then
		local groups = raid.GetMembers()
		-- Ожидаем: GetMembers может вернуть nil — тогда в отряде никого не ищем
		if type( groups ) == "table" then
			for _, grp in pairs( groups ) do
				if type( grp ) == "table" then
					for _, m in pairs( grp ) do if match( m ) then return m end end
				end
			end
		end
	elseif group.IsExist() then
		local members = group.GetMembers()
		-- Ожидаем: GetMembers может вернуть nil — тогда в группе никого не ищем
		if type( members ) == "table" then
			for _, m in pairs( members ) do if match( m ) then return m end end
		end
	end
	return nil
end

local function GroupCount()
	local members = group.GetMembers()
	-- Ожидаем: GetMembers может вернуть nil — считаем группу пустой
	if type( members ) ~= "table" then return 0 end
	local n = 0
	for _ in pairs( members ) do n = n + 1 end
	return n
end

--------------------------------------------------------------------------------
-- Команды
--------------------------------------------------------------------------------
A.pendingRaidInvite = nil   -- { name, t }: пригласить, когда группа станет отрядом

local CMD = {}

CMD.invite = function( p, name )
	-- Ожидаем: приглашение может не дойти (игрок не в сети, в зоне, где нельзя приглашать, группа полная).
	-- InviteByName ничего не возвращает — причину игра присылает событием EVENT_GROUP_INVITE_FAILED,
	-- его разбирает A.OnGroupInviteFailed.
	local k = Kind()
	if FindMember( p.senderUniqueId, name ) then
		ToastWarn( "++", name .. " уже в вашем формировании" )
		return
	end
	if k == "raid" then
		if not CanManageRaid() then return ToastWarn( "++", "Не пригласил " .. name .. ": нужны права лидера или помощника" ) end
		raid.InviteByName( WS( name ) )
	elseif k == "party" then
		if not group.IsLeader() then return ToastWarn( "++", "Не пригласил " .. name .. ": приглашать может лидер группы" ) end
		if GroupCount() >= GROUP_SIZE then
			-- группа полная: превращаем в отряд, приглашаем после превращения
			A.pendingRaidInvite = { name = name, t = BAA.tick }
			raid.Create()
			ToastCmd( "++", "Группа полная — создаю отряд для " .. name )
			return
		end
		group.InviteByName( WS( name ) )
	else
		group.InviteByName( WS( name ) )
	end
	A.lastInvite = { name = name, t = BAA.tick }
	ToastCmd( "++", "Пригласил " .. name )
end

CMD.leader = function( p, name )
	local k = Kind()
	if k == "none" then return ToastWarn( "!!", "Не передал лидерство " .. name .. ": вы не в группе" ) end
	local isLeader = ( k == "raid" and raid.IsLeader() ) or ( k == "party" and group.IsLeader() )
	if not isLeader then return ToastWarn( "!!", "Не передал лидерство " .. name .. ": вы не лидер" ) end
	local m = FindMember( p.senderUniqueId, name )
	local uid = ( m and m.uniqueId ) or nil
	if not uid then return ToastWarn( "!!", "Не передал лидерство: " .. name .. " не в вашем формировании" ) end
	if k == "raid" then raid.ChangeLeader( uid ) else group.SetLeader( uid ) end
	ToastCmd( "!!", "Передал лидерство: " .. name )
end

CMD.ready = function( p, name )
	local k = Kind()
	if k == "none" then return ToastWarn( "??", "Проверка готовности: вы не в группе" ) end
	local lib = ( k == "raid" ) and raid or group
	local can = ( k == "raid" and CanManageRaid() ) or ( k == "party" and group.IsLeader() )
	if not can then return ToastWarn( "??", "Проверка готовности: нужны права лидера" .. ( k == "raid" and " или помощника" or "" ) ) end
	local info = lib.GetReadyCheckInfo()
	-- Ожидаем: если проверки готовности ещё не было, GetReadyCheckInfo возвращает nil
	if type( info ) == "table" and info.isInProgress then
		return ToastWarn( "??", "Проверка готовности уже идёт" )
	end
	lib.StartReadyCheck()
	ToastCmd( "??", "Проверка готовности по просьбе " .. name )
end

CMD.trade = function( p, name )
	-- Ожидаем: обмен может не начаться (далеко, игрок занят или мёртв). InviteToExchange ничего не возвращает —
	-- причину игра присылает событием EVENT_ITEMS_EXCHANGE_ERROR, его разбирает A.OnExchangeError.
	if interaction.HasExchange() then return ToastWarn( "##", "Не предложил обмен " .. name .. ": обмен уже идёт" ) end
	interaction.InviteToExchange( WS( name ) )
	A.lastTrade = { name = name, t = BAA.tick }
	ToastCmd( "##", "Предложил обмен: " .. name )
end

-- Юнит игрока рядом по нику
local function FindUnit( name )
	local low = BAA.Lower( name )
	local list = avatar.GetUnitList()
	-- Ожидаем: GetUnitList может вернуть nil — никого рядом
	if type( list ) ~= "table" then return nil end
	for _, id in pairs( list ) do
		if unit.IsPlayer( id ) and BAA.Lower( S( object.GetName( id ) ) ) == low then return id end
	end
	return nil
end

CMD.follow = function( p, name )
	local id = p.senderId
	-- Ожидаем: автор сообщения мог уйти из видимости — ищем его среди юнитов рядом по нику
	if id and not object.IsExist( id ) then id = nil end
	id = id or FindUnit( name )
	if not id then return ToastWarn( ">>", "Не могу следовать: " .. name .. " не рядом" ) end
	if avatar.GetTarget() == id then
		avatar.SetFollowTarget( true )
		ToastCmd( ">>", "Следую за " .. name )
	elseif BAA.UI then
		-- Ожидаем: из события цель не выбирается (avatar.SelectTarget работает только по клику) — показываем кнопку
		-- выбрать цель аддон может только по клику игрока (avatar.SelectTarget) — показываем кнопку
		BAA.UI.FollowPrompt( name, id )
	end
end

-- Тип личных сообщений
local function IsWhisper( p )
	-- Ожидаем: если клиент не знает CHAT_TYPE_WHISPER, на команды не реагируем
	return CHAT_TYPE_WHISPER ~= nil and p.chatType == CHAT_TYPE_WHISPER
end

-- Задержка: команда выполняется через N секунд после сообщения (0 — сразу).
-- Пока команда ждёт, такая же от того же игрока не ставится второй раз.
local waiting = {}   -- [команда:ник] = { cmd, name, p, due }

local function Run( cmd, p, name )
	CMD[ cmd.k ]( p, name )
end

function A.OnChatMessage( p )
	if p.isEcho then return end
	local text = BAA.Trim( S( p.msg ) )
	local cmd = BAA.CMD_BY_CODE[ text ]
	if not cmd then return end
	local name = S( p.sender )
	--@debug
	BAA.Log( "сообщение", text, "от", name, "chatType=" .. tostring( p.chatType ), "WHISPER=" .. tostring( CHAT_TYPE_WHISPER ),
		"senderId=" .. tostring( p.senderId ), "spam=" .. tostring( p.spamWeight ),
		"фильтр:", select( 2, BAA.Filter.Allowed( name, p.senderId ) ) or "да" )
	--@end
	if not IsWhisper( p ) then return end
	if ( p.spamWeight or 0 ) >= 100 then return end
	if BAA.cfg.paused then return end
	local st = BAA.cfg.cmds[ cmd.k ]
	if not st.on then return end
	if not BAA.Filter.Allowed( name, p.senderId ) then return end
	local key = cmd.k .. ":" .. BAA.Lower( name )
	if waiting[ key ] then return end
	if st.cd <= 0 then return Run( cmd, p, name ) end
	waiting[ key ] = { cmd = cmd, name = name, due = BAA.tick + st.cd,
		p = { senderUniqueId = p.senderUniqueId, senderId = p.senderId } }
end

-- Группа стала отрядом: зовём того, ради кого её превращали
function A.OnSecond()
	for key, w in pairs( waiting ) do
		if BAA.tick >= w.due then
			waiting[ key ] = nil
			-- за время ожидания настройки могли измениться
			if not BAA.cfg.paused and BAA.cfg.cmds[ w.cmd.k ].on and BAA.Filter.Allowed( w.name, w.p.senderId ) then
				Run( w.cmd, w.p, w.name )
			end
		end
	end
	local pr = A.pendingRaidInvite
	if pr then
		if raid.IsExist() then
			A.pendingRaidInvite = nil
			raid.InviteByName( WS( pr.name ) )
			ToastCmd( "++", "Пригласил " .. pr.name )
		elseif BAA.tick - pr.t > 10 then
			A.pendingRaidInvite = nil
			ToastWarn( "++", "Не получилось создать отряд для " .. pr.name )
		end
	end
end

local INVITE_FAILED_TEXT = {
	ENUM_GROUP_INVITE_FAILED_NOT_EXIST = "такого игрока нет",
	ENUM_GROUP_INVITE_FAILED_NOT_LOGGED_IN = "игрок не в игре",
	ENUM_GROUP_INVITE_FAILED_CANT_INVITE_SELF = "нельзя пригласить себя",
	ENUM_GROUP_INVITE_FAILED_FULL_GROUP = "группа полная",
	ENUM_GROUP_INVITE_FAILED_ALREADY_IN = "игрок уже в группе",
	ENUM_GROUP_INVITE_FAILED_ZONE_NOT_ALLOWED = "здесь приглашать нельзя",
	ENUM_GROUP_INVITE_FAILED_NOT_LEADER = "вы не лидер",
}

function A.OnGroupInviteFailed( p )
	local reason = tostring( p.sysReason )
	local name = S( p.name )
	BAA.Log( "приглашение не удалось", name, reason ) --@debug
	local last = A.lastInvite
	if not last or BAA.tick - last.t > 5 then return end
	if reason == "ENUM_GROUP_INVITE_FAILED_FULL_GROUP" and group.IsLeader() and not raid.IsExist() then
		A.pendingRaidInvite = { name = last.name, t = BAA.tick }
		raid.Create()
		return
	end
	ToastWarn( "++", "Не пригласил " .. ( name ~= "" and name or last.name ) .. ": " .. ( INVITE_FAILED_TEXT[ reason ] or reason ) )
end

local EXCHANGE_ERR = {
	ENUM_MsgStartExchangeResultResult_TOOFAR = "слишком далеко",
	ENUM_MsgStartExchangeResultResult_INVITEDAVATARISBUSY = "игрок занят",
	ENUM_MsgStartExchangeResultResult_INVITERAVATARISBUSY = "вы заняты",
	ENUM_MsgStartExchangeResultResult_INVITEDAVATARNOTFOUND = "игрок не найден",
	ENUM_MsgStartExchangeResultResult_INVITEDAVATARISDEAD = "игрок мёртв",
	ENUM_MsgStartExchangeResultResult_INVITERAVATARISDEAD = "вы мертвы",
	ENUM_MsgStartExchangeResultResult_YOUAREINVISIBLE = "вы невидимы",
}

function A.OnExchangeError( p )
	local err = tostring( p.error )
	BAA.Log( "ошибка обмена", err, S( p.invited ) ) --@debug
	local last = A.lastTrade
	if not last or BAA.tick - last.t > 5 then return end
	ToastWarn( "##", "Обмен с " .. last.name .. " не начат: " .. ( EXCHANGE_ERR[ err ] or err ) )
end

--------------------------------------------------------------------------------
-- Автопринятие
--------------------------------------------------------------------------------
local function AccOn( k ) return not BAA.cfg.paused and BAA.cfg.acc[ k ] end

local function Check( k, name, unitId )
	if BAA.cfg.paused or not BAA.cfg.acc[ k ] then return false end
	local ok = BAA.Filter.Allowed( name, unitId )
	return ok
end

function A.OnGroupInvite( p )
	local name = S( p.inviterName )
	if not Check( "group", name ) then return end
	local info = group.GetInviteInfo()
	-- Ожидаем: приглашение могли уже отозвать — тогда invited = false
	if info and info.invited then
		group.Accept()
		ToastAcc( "GROUP", "Принял приглашение в группу от " .. name )
	end
end

function A.OnRaidInvite( p )
	local name = S( p.inviterName )
	if not Check( "group", name ) then return end
	local info = raid.GetInviteInfo()
	-- Ожидаем: приглашение могли уже отозвать — тогда invited = false
	if info and info.invited then
		raid.Accept()
		ToastAcc( "GROUP", "Принял приглашение в отряд от " .. name )
	end
end

function A.OnResurrect( p )
	local name = S( p.resurrecterName )
	if not Check( "res", name, p.unitId ) then return end
	avatar.ResurrectReply( true )
	ToastAcc( "RES", "Принял воскрешение от " .. name )
end

-- Подбор группы: голосование
-- Все роли, доступные персонажу. Правило то же, что в окне игры (ClassActivityRolePlate,
-- ScriptAddonAPI.GetSelectedRoles): роль есть в lfgLib.GetRoles(), и lfgLib.IsRoleAvailable
-- не ответил явным отказом (success = false). Если он вернул nil, роль считается доступной.
local function AvailableRoles()
	local list = {}
	local mine = lfgLib.GetRoles()
	-- Ожидаем: GetRoles может вернуть nil — ролей нет, в очередь не встаём
	if type( mine ) ~= "table" then return list end
	for _, role in pairs( mine ) do
		local info = lfgLib.IsRoleAvailable( role )
		-- Ожидаем: IsRoleAvailable возвращает nil при ошибке проверки — роль считаем доступной, как окно игры
		local refused = type( info ) == "table" and info.success == false
		--@debug
		BAA.Log( "роль", tostring( role ), refused and "недоступна" or "доступна",
			"(IsRoleAvailable: " .. ( type( info ) == "table" and tostring( info.success ) or tostring( info ) ) .. ")" )
		--@end
		if not refused then list[ #list + 1 ] = role end
	end
	table.sort( list )
	return list
end

function A.OnLfgVote( p )
	local name = S( p.initiator )
	if not Check( "activity", name ) then return end
	local roles = AvailableRoles()
	if #roles == 0 then return end
	lfgLib.VoteYes( roles )
	ToastAcc( "ACTIVITY", "Принял приглашение в активность от " .. name )
end

-- Одногруппник зовёт телепортироваться с ним
function A.OnTeleportOffer( p )
	local id = p.requesterId
	-- Ожидаем: одногруппник мог уйти из видимости — имени нет, фильтр не пропустит
	local name = ( id and object.IsExist( id ) ) and S( object.GetName( id ) ) or ""
	if not Check( "activity", name, id ) then return end
	avatar.TeleportOfferReply( true )
	ToastAcc( "ACTIVITY", "Принял телепорт от " .. name )
end

-- Очередь инстанс-ивентов: функция ответа закрыта с 16.0 — отвечаем, только если она есть
function A.OnMatchTeleport( p )
	if not AccOn( "activity" ) then return end
	-- Ожидаем: функции ответа может не быть (закрыта с 16.0) — тогда не отвечаем
	if type( matchMaking ) == "table" and type( matchMaking.InstancedEventTeleportReply ) == "function" then
		matchMaking.InstancedEventTeleportReply( true )
		ToastAcc( "ACTIVITY", "Принял приглашение в активность" )
	end
end

-- Предложение обмена: встречное предложение тому, кто зовёт
function A.OnExchangeInvited( p )
	local inv = interaction.GetExchangeInviter()
	-- Ожидаем: если обмен уже отменён, GetExchangeInviter возвращает nil
	local id = type( inv ) == "table" and inv.playerId or nil
	local name = ( id and object.IsExist( id ) ) and S( object.GetName( id ) ) or ""
	BAA.Log( "предложение обмена от", name ~= "" and name or "?" ) --@debug
	if name == "" then return end
	if not Check( "trade", name, id ) then return end
	-- Ожидаем: принять обмен функцией можно не во всех клиентах — иначе встречное предложение
	if type( interaction.AcceptInviteToExchange ) == "function" then
		interaction.AcceptInviteToExchange( WS( name ) )
		ToastAcc( "TRADE", "Принял обмен от " .. name )
	else
		interaction.InviteToExchange( WS( name ) )
		A.lastTrade = { name = name, t = BAA.tick }
		ToastAcc( "TRADE", "Встречное предложение обмена: " .. name )
	end
end

-- «Взять на руки»: событие и ответ убраны из документации в 15.0.03 — отвечаем, только если функция есть
function A.OnTakeOnHands( p )
	local name = ""
	-- Ожидаем: поля события не описаны в документации — перебираем возможные имена
	for _, f in ipairs( { "name", "casterName", "initiatorName", "requesterName", "playerName" } ) do
		name = S( p[ f ] )
		if name ~= "" then break end
	end
	if name == "" then
		for _, f in ipairs( { "id", "unitId", "playerId", "casterId", "objectId", "requesterId" } ) do
			local id = p[ f ]
			-- Ожидаем: в поле может лежать не идентификатор, или юнит уже ушёл
			if type( id ) == "number" and object.IsExist( id ) then
				name = S( object.GetName( id ) )
				if name ~= "" then break end
			end
		end
	end
	if not Check( "carry", name ) then return end
	-- Ожидаем: функции ответа может не быть — тогда не отвечаем
	if type( family ) == "table" and type( family.TakeOnHandsResponse ) == "function" then
		family.TakeOnHandsResponse( true )
		ToastAcc( "CARRY", "На ручках у " .. name )
	end
end

--------------------------------------------------------------------------------
-- Вопросы (questionLib): мотоцикл и транспорт, «на руки», активности
--------------------------------------------------------------------------------
local VEHICLE_WORDS = { "пассажир", "транспорт", "мотоцикл", "молни", "passenger", "vehicle", "transport" }
local CARRY_WORDS = { "на руки", "на ручки", "на руках", "в руки", "on hands", "carry" }

local function HasWord( text, words )
	local low = BAA.Lower( text )
	for _, w in ipairs( words ) do
		if string.find( low, BAA.Lower( w ), 1, true ) then return true end
	end
	return false
end

-- Кто задал вопрос: в clientData лежит { name = "caster", text = WString ника }
local Str = BAA.S

local function FindCaster( info )
	local cd = info.clientData
	if type( cd ) ~= "table" then return nil end
	for _, item in pairs( cd ) do
		if type( item ) == "table" and Str( item.name ) == "caster" then
			local s = Str( item.text )
			if s == "" then s = Str( item.value ) end
			if s ~= "" then return s end
		end
	end
	return nil
end

local function QuestionText( info )
	local q = info.questionData
	local parts = {}
	if type( q ) == "table" then
		local c = q.questionCustomData
		if type( c ) == "table" then parts[ #parts + 1 ] = S( c.text ) end
		parts[ #parts + 1 ] = S( q.text )
		parts[ #parts + 1 ] = S( q.name )
	end
	parts[ #parts + 1 ] = tostring( info.type or "" )
	return table.concat( parts, " " )
end

local QUEUE_WORDS = { "вступить в очередь", "выбрано сражение", "join the queue" }

-- Приглашение в активность: в данных вопроса есть объект ивента или направления
local function IsActivityQuestion( info )
	local cd = info.clientData
	if type( cd ) ~= "table" then return false end
	local types = {}
	for _, v in pairs( { VAL_OBJ_TYPE_INSTANCED_EVENT or false, VAL_OBJ_TYPE_LFG_DESTINATION or false } ) do
		if v then types[ v ] = true end
	end
	for _, item in pairs( cd ) do
		if type( item ) == "table" then
			if Str( item.name ) == "event" then return true end
			for _, v in pairs( item ) do
				-- Ожидаем: в данных вопроса лежат разные объекты API — тип спрашиваем только у ValuedObject
				if type( v ) == "userdata" and apitype( v ) == "ValuedObjectLua" and types[ v:GetType() ] then
					return true
				end
			end
		end
	end
	return false
end

function A.OnQuestionAdded( p )
	-- Ожидаем: вопрос могли уже закрыть — GetInfo возвращает nil
	local info = questionLib.GetInfo( p.id )
	if type( info ) ~= "table" then return end
	BAA.Probe.Question( p.id, info ) --@debug
	if info.isObserver then return end
	-- Вопрос с выбором роли. Игра отвечает так же (ClassVotePopup / ClassQuizQuestion):
	-- SendData( id, { roles = маска } ), маска = сумма 2^роль по выбранным ролям.
	local custom = type( info.questionData ) == "table" and info.questionData.questionCustomData
	if type( custom ) == "table" and tostring( custom.sysType ) == "ENUM_QuizQuestionType_CHOICE_ROLES" then
		if not AccOn( "activity" ) then return end
		local roles = AvailableRoles()
		if #roles == 0 then return end
		local mask = 0
		for _, role in ipairs( roles ) do mask = mask + math.pow( 2, role ) end
		BAA.Log( "выбор роли: ролей", #roles, "маска", mask ) --@debug
		questionLib.SendData( p.id, { roles = mask } )
		ToastAcc( "ACTIVITY", "Встал в очередь на активность" )
		return
	end
	local text = QuestionText( info )
	local caster = FindCaster( info ) or ""
	local kind = nil
	if HasWord( text, CARRY_WORDS ) then kind = "carry"
	elseif HasWord( text, VEHICLE_WORDS ) then kind = "vehicle"
	elseif HasWord( text, QUEUE_WORDS ) or IsActivityQuestion( info ) then kind = "activity" end
	if not kind then return end
	BAA.Log( "вопрос:", kind, "от", caster ~= "" and caster or "?" ) --@debug
	if kind == "activity" then
		if not AccOn( "activity" ) then return end
	else
		if caster == "" then
			-- не знаем, кто зовёт: принимаем, только если реагируем на всех
			if not ( AccOn( kind ) and BAA.cfg.react.all ) then return end
		elseif not Check( kind, caster ) then
			return
		end
	end
	questionLib.SendData( p.id, { choice = 1 } )
	local who = caster ~= "" and caster or ""
	if kind == "vehicle" then ToastAcc( "VEHICLE", who ~= "" and ( "Сел в транспорт " .. who ) or "Сел в транспорт" )
	elseif kind == "carry" then ToastAcc( "CARRY", who ~= "" and ( "На ручках у " .. who ) or "На ручках!" )
	else ToastAcc( "ACTIVITY", "Принял приглашение в активность" ) end
end
