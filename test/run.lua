-- Прогон логики BestAutoAccept на заглушках:
--   texlua test/run.lua <папка исходников> <папка скриптов>
-- Скрипты — lua/, пропущенные через tools/strip_debug.py (обычная сборка без отладки).
local ROOT = arg and arg[ 1 ] or "."
local L = ( arg and arg[ 2 ] or ( ROOT .. "/lua" ) ) .. "/"
dofile( ROOT .. "/test/mock.lua" )
for _, f in ipairs( { "LibDnD", "Util", "Config", "Filter", "Probe", "Actions", "UI", "Main" } ) do
	local fh = io.open( L .. f .. ".lua" )
	if fh then fh:close() dofile( L .. f .. ".lua" ) end
end

local function ev( name, p ) print( "EVENT " .. name ) EVENTS[ name ]( p or {} ) end
local function click( r, w, extra )
	print( "CLICK " .. r .. " " .. ( w and w.name or "" ) )
	local p = { widget = w, sender = w and w.name, active = true }
	for k, v in pairs( extra or {} ) do p[ k ] = v end
	REACTIONS[ r ]( p )
end
local function WS( s ) return userMods.ToWString( s ) end
local function whisper( from, text, extra )
	local p = { sender = WS( from ), msg = WS( text ), chatType = CHAT_TYPE_WHISPER, isEcho = false, senderUniqueId = { u = from }, spamWeight = 0 }
	for k, v in pairs( extra or {} ) do p[ k ] = v end
	ev( "EVENT_CHAT_MESSAGE", p )
end
local W = BAA.W

assert( BAA.cfg.react.friends and BAA.cfg.react.guild and not BAA.cfg.react.all )
click( "baa_main", W( "BAAButton" ) )
assert( W( "BAAWindow" ).visible, "окно не открылось" )
-- сегменты
click( "baa_seg", W( "SegFriends" ) )       -- friends off (guild still on)
assert( not BAA.cfg.react.friends )
click( "baa_seg", W( "SegGuild" ) )         -- last one: blocked
assert( BAA.cfg.react.guild, "последний снялся" )
assert( W( "SegGuild" ).variant == 2 )
click( "baa_seg", W( "SegAll" ) )
assert( BAA.cfg.react.all and not BAA.cfg.react.guild )
click( "baa_seg", W( "SegAll" ) )
assert( not BAA.cfg.react.all and BAA.cfg.react.guild and not BAA.cfg.react.friends, "память выбора" )
click( "baa_seg", W( "SegFriends" ) )
-- команды
local row3 = W( "CmdRow3" )
click( "baa_cmd_switch", BAA.Child( row3, "CmdSwitch" ) )
assert( BAA.cfg.cmds.ready.on == false )
click( "baa_cmd_switch", BAA.Child( row3, "CmdSwitch" ) )
local box1 = BAA.Child( W( "CmdRow1" ), "CdBox" )
click( "baa_cd_plus", BAA.Child( box1, "CdPlus" ) )
assert( BAA.cfg.cmds.invite.cd == 5, BAA.cfg.cmds.invite.cd )
REACTIONS.baa_cd_down( { widget = box1 } )
assert( BAA.cfg.cmds.invite.cd == 0 )
local edit = BAA.Child( box1, "CdEdit" )
REACTIONS.baa_cd_focus( { widget = edit, active = true } )
edit.text = "42"
REACTIONS.baa_cd_enter( { widget = edit } )
assert( BAA.cfg.cmds.invite.cd == 30, BAA.cfg.cmds.invite.cd )
REACTIONS.baa_cd_focus( { widget = edit, active = true } )
edit.text = "abc"
REACTIONS.baa_cd_focus( { widget = edit, active = false } )
assert( BAA.cfg.cmds.invite.cd == 30 and edit.text == "30", edit.text )
edit.text = "9999"; REACTIONS.baa_cd_enter( { widget = edit } )
assert( BAA.cfg.cmds.invite.cd == 30 )
BAA.cfg.cmds.invite.cd = 0
-- автопринятие
click( "baa_acc_switch", BAA.Child( W( "AccRow3" ), "AccSwitch" ) )
assert( BAA.cfg.acc.vehicle == false )
assert( W( "BAAButton" ).variant == 1 )
click( "baa_acc_switch", BAA.Child( W( "AccRow3" ), "AccSwitch" ) )
-- подсказки
REACTIONS.baa_tip( { widget = BAA.Child( W( "CmdRow2" ), "CmdName" ), active = true } )
assert( W( "Tooltip" ).visible and W( "TipText" ).val:find( "лидерство" ) )
REACTIONS.baa_tip( { widget = W( "SegFriends" ), active = false } )
assert( not W( "Tooltip" ).visible )
-- чёрный список
click( "baa_gear", W( "HdrGear" ) )
assert( W( "SettingsPage" ).visible )
local ed = W( "BlEdit" )
ed.text = "Борогрим"; click( "baa_bl_add", W( "BlAdd" ) )
ed.text = "  борогрим "; click( "baa_bl_add", W( "BlAdd" ) )
print( "BL:", table.concat( BAA.cfg.bl, "," ) )
ed.text = "Ки"; click( "baa_bl_add", W( "BlAdd" ) )
assert( W( "BlInputErr" ).visible )
ed.text = "Злобоглаз"; click( "baa_bl_add", W( "BlAdd" ) )
assert( #BAA.cfg.bl == 2, #BAA.cfg.bl )
assert( W( "BlCount" ).val == "2 персонажа", W( "BlCount" ).val )
local rowW = { name = "BlRemove", GetParent = function() return { GetName = function() return "BlRow1" end } end, GetInstanceId = function() return "x" end }
REACTIONS.baa_bl_remove( { widget = rowW, active = true } )
assert( #BAA.cfg.bl == 1 and BAA.cfg.bl[ 1 ] == "Борогрим" )
assert( CONFIG.BestAutoAccept.baa.bl[ 1 ] == "Борогрим" )
click( "baa_gear", W( "HdrGear" ) )

click( "baa_main_rc", W( "BAAButton" ) ) assert( BAA.cfg.paused and W( "BAAButton" ).variant == 3 )
click( "baa_main_rc", W( "BAAButton" ) ) assert( not BAA.cfg.paused )
print( "\n=== команды ===" )
BAA.cfg.cmds.invite.cd = 2
whisper( "Арагорн", "++" )          -- друг, вне группы: ждёт 2 с
whisper( "Арагорн", "++" )          -- уже ждёт
assert( #CALLS == 0, "сработало без задержки" )
ev( "EVENT_SECOND_TIMER" ) assert( #CALLS == 0 )
ev( "EVENT_SECOND_TIMER" ) assert( #CALLS == 1 and CALLS[ 1 ] == "group.InviteByName Арагорн", CALLS[ 1 ] )
BAA.cfg.cmds.invite.cd = 0
whisper( "Борогрим", "++" )         -- ЧС
whisper( "Чужой", "++" )            -- не друг
whisper( "Луноликая", " ++ " )      -- согильдейка, пробелы
STATE.kind = "party"; STATE.members = { "Я", "Луноликая", "Арагорн" }
NOW = NOW + 60000
whisper( "Арагорн", "!!" )
whisper( "Арагорн", "??" )
whisper( "Арагорн", "##" )
STATE.units = { { o = "Арагорн" } }
whisper( "Арагорн", ">>", { senderId = { o = "Арагорн" } } )
assert( W( "FollowPrompt" ).visible )
click( "baa_follow", W( "FollowButton" ) )
STATE.members = { "Я", "a", "b", "c", "d", "e" }
NOW = NOW + 60000
whisper( "Арагорн", "++" )
ev( "EVENT_SECOND_TIMER" )
whisper( "Арагорн", "++", { chatType = 1 } ) -- не личка
BAA.cfg.paused = true; NOW = NOW + 60000; whisper( "Арагорн", "??" ); BAA.cfg.paused = false

print( "\n=== автопринятие ===" )
ev( "EVENT_GROUP_INVITE", { inviterName = WS( "Луноликая" ) } )
ev( "EVENT_RAID_INVITE", { inviterName = WS( "Чужой" ) } )
ev( "EVENT_RESURRECT_REQUESTED", { resurrecterName = WS( "Арагорн" ), unitId = { o = "Арагорн" } } )
ev( "EVENT_LFG_VOTE", { initiator = WS( "Арагорн" ), roles = { 2 } } )
ev( "EVENT_TELEPORT_OFFER_REQUEST", { requesterId = { o = "Луноликая" } } )
STATE.question = { type = "x", questionData = { questionCustomData = { text = WS( "<html>[<r name=\"caster\"/>] предлагает вам занять пассажирское место Молнии. Вы согласны?</html>" ) } },
	clientData = { [ 0 ] = { name = "caster", text = WS( "Арагорн" ) } } }
ev( "EVENT_QUESTION_ADDED", { id = 1 } )
STATE.question = { type = "x", questionData = { questionCustomData = { text = WS( "Хотите на руки?" ) } }, clientData = {} }
ev( "EVENT_QUESTION_ADDED", { id = 2 } )
STATE.question = { type = "QuizQuestion", questionData = { questionCustomData = { text = WS( "<html>Выбрано сражение: «<r name=\"event\"/>». Вы готовы вступить в очередь?</html>" ) } }, clientData = { [ 0 ] = { name = "event" } } }
ev( "EVENT_QUESTION_ADDED", { id = 5 } )
local n0 = #CALLS
STATE.question = { type = "QuizQuestion", questionData = { questionCustomData = { sysType = "ENUM_QuizQuestionType_CHOICE_ROLES", text = WS( "x" ) } }, clientData = { [ 0 ] = { name = "event" } } }
ev( "EVENT_QUESTION_ADDED", { id = 6 } )
assert( CALLS[ #CALLS ]:find( "roles=6" ), CALLS[ #CALLS ] )
for i = 1, 6 do ev( "EVENT_SECOND_TIMER" ) end
assert( not W( "Toast1" ).visible )
ev( "EVENT_UNKNOWN_SLASH_COMMAND", { text = WS( "/baa" ) } )
assert( W( "BAAWindow" ).visible )
print( "\n=== проверка готовности ===" )
local function uid( n ) for _, m in pairs( group.GetMembers() ) do if m.name.s == n then return m.uniqueId end end end
STATE.kind = "party"; STATE.members = { "Я", "Луноликая", "Арагорн", "Чужой" }
local MEMBERS = group.GetMembers()
group.GetMembers = function() return MEMBERS end
ME.uid = MEMBERS[ 1 ].uniqueId
local function check( left, mine ) STATE.ready = { isInProgress = true, remainingTimeMs = left, members = { { uniqueId = ME.uid, state = mine or 0 } } } end
-- строка 7: переключатель и поле задержки
local row6 = W( "AccRow6" )
local box6 = BAA.Child( row6, "CdBox" )
assert( BAA.cfg.acc.ready == true and BAA.cfg.accCd.ready == 0 )
click( "baa_cd_plus", BAA.Child( box6, "CdPlus" ) )
assert( BAA.cfg.accCd.ready == 5 and BAA.cfg.cmds.invite.cd == 0 )
local e7 = BAA.Child( box6, "CdEdit" )
REACTIONS.baa_cd_focus( { widget = e7, active = true } ); e7.text = "99"; REACTIONS.baa_cd_enter( { widget = e7 } )
assert( BAA.cfg.accCd.ready == 30 and e7.text == "30", e7.text )
REACTIONS.baa_cd_down( { widget = box6 } ) assert( BAA.cfg.accCd.ready == 25 )
REACTIONS.baa_tip( { widget = box6, active = true } ) assert( W( "TipText" ).val:find( "через 25" ), W( "TipText" ).val )
BAA.cfg.accCd.ready = 0
local n = #CALLS
check( 30000 ); ev( "EVENT_READY_CHECK_STARTED", { initiatorId = MEMBERS[ 3 ].uniqueId } )   -- друг, сразу
assert( #CALLS == n + 1 and CALLS[ #CALLS ] == "group.ReportReadyCheck true", CALLS[ #CALLS ] )
assert( #RELOADS == 0 ) ev( "EVENT_SECOND_TIMER" )
assert( #RELOADS == 1 and RELOADS[ 1 ] == "ContextUniMessageBox", "окно игры не закрыто" )
ev( "EVENT_SECOND_TIMER" ) assert( #RELOADS == 1, "перезагрузка повторилась" )
ev( "EVENT_READY_CHECK_STARTED", { initiatorId = MEMBERS[ 4 ].uniqueId } )   -- чужой
ev( "EVENT_READY_CHECK_STARTED", { initiatorId = ME.uid } )                  -- сам
assert( #CALLS == n + 1, "ответил чужому или себе" )
BAA.cfg.accCd.ready = 3
ev( "EVENT_READY_CHECK_STARTED", { initiatorId = MEMBERS[ 2 ].uniqueId } )
ev( "EVENT_SECOND_TIMER" ) ev( "EVENT_SECOND_TIMER" ) assert( #CALLS == n + 1 )
ev( "EVENT_SECOND_TIMER" ) assert( #CALLS == n + 2, "не ответил после задержки" )
-- ответил сам за время задержки
ev( "EVENT_READY_CHECK_STARTED", { initiatorId = MEMBERS[ 2 ].uniqueId } )
check( 30000, 2 ) for i = 1, 4 do ev( "EVENT_SECOND_TIMER" ) end assert( #CALLS == n + 2, "перебил ручной ответ" )
-- проверка закончилась раньше
check( 30000 ); ev( "EVENT_READY_CHECK_STARTED", { initiatorId = MEMBERS[ 2 ].uniqueId } )
ev( "EVENT_READY_CHECK_ENDED" ) for i = 1, 4 do ev( "EVENT_SECOND_TIMER" ) end assert( #CALLS == n + 2 )
-- задержка длиннее остатка проверки: укорачиваем
BAA.cfg.accCd.ready = 30; check( 5000 ); ev( "EVENT_READY_CHECK_STARTED", { initiatorId = MEMBERS[ 2 ].uniqueId } )
for i = 1, 3 do ev( "EVENT_SECOND_TIMER" ) end assert( #CALLS == n + 3, "не уложился в остаток" )
-- выключено / пауза
click( "baa_acc_switch", BAA.Child( row6, "AccSwitch" ) ) assert( BAA.cfg.acc.ready == false )
BAA.cfg.accCd.ready = 0; check( 30000 ); ev( "EVENT_READY_CHECK_STARTED", { initiatorId = MEMBERS[ 2 ].uniqueId } )
assert( #CALLS == n + 3 )
click( "baa_cd_plus", BAA.Child( box6, "CdPlus" ) ) assert( BAA.cfg.accCd.ready == 0, "поле меняется у выключенного" )
click( "baa_acc_switch", BAA.Child( row6, "AccSwitch" ) )
assert( CONFIG.BestAutoAccept.baa.accCd.ready == 0 and CONFIG.BestAutoAccept.baa.acc.ready == true )
ev( "EVENT_SECOND_TIMER" ) assert( #RELOADS == 3, #RELOADS )   -- по одной на каждый ответ аддона
STATE.boxState = 2; BAA.cfg.accCd.ready = 0; check( 30000 ); ev( "EVENT_READY_CHECK_STARTED", { initiatorId = MEMBERS[ 2 ].uniqueId } )
ev( "EVENT_SECOND_TIMER" ) assert( #RELOADS == 3, "перезагрузил незагруженный аддон" )
if BAA.DEBUG ~= nil then
	print( "\n=== отладочная сборка ===" )
	ev( "EVENT_UNKNOWN_SLASH_COMMAND", { text = WS( "/baa debug" ) } )
	ev( "EVENT_QUESTION_ADDED", { id = 3 } )
else
	assert( BAA.Log == nil and BAA.Probe == nil, "в обычной сборке осталась отладка" )
end
print( "\nALL OK" )
