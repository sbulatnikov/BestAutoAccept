--------------------------------------------------------------------------------
-- BestAutoAccept / Main.lua
-- Запуск, события, реакции, команда /baa.
--------------------------------------------------------------------------------
local UI, A = BAA.UI, BAA.Act
local started = false

-- Кнопка может прислать реакцию дважды: при нажатии (active = true) и при
-- отпускании (active = false). Обрабатываем клик один раз.
local pressed = {}
local function Click( name, fn )
	return function( params )
		local w = params.widget
		local key = name .. ":" .. tostring( w and w:GetInstanceId() or params.sender )
		if params.active == true then
			pressed[ key ] = true
		elseif params.active == false and pressed[ key ] then
			pressed[ key ] = nil
			return
		end
		fn( params )
	end
end

-- клик по кнопке сразу после перетаскивания не открывает окно
local dragEnd = nil
local function ButtonDragMoved()
	local id = DnD.Dragging
	local w = id and DnD.Widgets and DnD.Widgets[ id ]
	if not w or w.wtMovable:GetName() ~= "BAAHost" then return false end
	local p, r = DnD.Place, DnD.Reset
	return ( p and r and ( p.posX ~= r.posX or p.posY ~= r.posY ) ) and true or false
end

local function OnMain()
	if ButtonDragMoved() then return end
	if dragEnd and BAA.tick - dragEnd <= 1 then
		dragEnd = nil
		return
	end
	dragEnd = nil
	UI.ToggleWindow()
end

local CLICKS = {
	baa_main = OnMain,
	baa_main_rc = UI.OnPause,
	baa_close = function() UI.ShowWindow( false ) end,
	baa_gear = UI.OnGear,
	baa_pause = UI.OnPause,
	baa_seg = UI.OnSeg,
	baa_cmd_switch = UI.OnCmdSwitch,
	baa_cd_minus = UI.OnCdMinus,
	baa_cd_plus = UI.OnCdPlus,
	baa_acc_switch = UI.OnAccSwitch,
	baa_bl_add = UI.OnBlAdd,
	baa_bl_remove = UI.OnBlRemove,
	baa_follow = UI.OnFollow,
}

local OTHER_REACTIONS = {
	baa_tip = UI.OnPointing,
	baa_cd_up = UI.OnCdUp,
	baa_cd_down = UI.OnCdDown,
	baa_cd_enter = UI.OnCdEnter,
	baa_cd_esc = UI.OnCdEsc,
	baa_cd_focus = UI.OnCdFocus,
	baa_bl_enter = UI.OnBlAdd,
	baa_bl_esc = UI.OnBlEsc,
	baa_bl_changed = UI.OnBlChanged,
}

local function OnSecond()
	BAA.tick = BAA.tick + 1
	UI.OnSecond()
	A.OnSecond()
end

local function OnSlash( p )
	local text = BAA.Lower( BAA.Trim( BAA.S( p.text ) ) )
	if text == "/baa" then UI.ShowWindow( true ) end
	--@debug
	if text == "/baa debug" then
		BAA.DEBUG = not BAA.DEBUG
		BAA.Cfg.Save()
		BAA.Chat( "отладка " .. ( BAA.DEBUG and "включена: пишу в Personal\\Logs\\mods.txt" or "выключена" ) )
		if BAA.DEBUG then BAA.Probe.Report() end
	end
	--@end
end

local function FriendsChanged() BAA.Filter.RebuildFriends() end

local function On( ev, fn )
	common.RegisterEventHandler( fn, ev )
end

local function Start()
	if started then return end
	started = true
	BAA.Cfg.Load()
	UI.Init()

	DnD.Init( BAA.W( "BAAHost" ), BAA.W( "BAAButton" ), true, true )
	DnD.Init( BAA.W( "BAAWindow" ), BAA.W( "Header" ), true, true )
	local stop = DnD.StopDragging
	DnD.StopDragging = function( ... )
		if ButtonDragMoved() then dragEnd = BAA.tick end
		return stop( ... )
	end

	for name, fn in pairs( CLICKS ) do common.RegisterReactionHandler( Click( name, fn ), name ) end
	for name, fn in pairs( OTHER_REACTIONS ) do common.RegisterReactionHandler( fn, name ) end

	--@debug
	for _, ev in ipairs( BAA.Probe.EVENTS ) do On( ev, BAA.Probe.Event( ev ) ) end
	On( "EVENT_QUESTION_RESULTS_CHANGED", BAA.Probe.QuestionResults )
	--@end
	On( "EVENT_SECOND_TIMER", OnSecond )
	On( "EVENT_UNKNOWN_SLASH_COMMAND", OnSlash )
	On( "EVENT_CHAT_MESSAGE", A.OnChatMessage )
	On( "EVENT_GROUP_INVITE_FAILED", A.OnGroupInviteFailed )
	On( "EVENT_ITEMS_EXCHANGE_ERROR", A.OnExchangeError )
	On( "EVENT_GROUP_INVITE", A.OnGroupInvite )
	On( "EVENT_RAID_INVITE", A.OnRaidInvite )
	On( "EVENT_RESURRECT_REQUESTED", A.OnResurrect )
	On( "EVENT_LFG_VOTE", A.OnLfgVote )
	On( "EVENT_TELEPORT_OFFER_REQUEST", A.OnTeleportOffer )
	On( "EVENT_MATCH_MAKING_EVENT_TELEPORT_REQUEST", A.OnMatchTeleport )
	On( "EVENT_ITEMS_EXCHANGE_INVITED", A.OnExchangeInvited )
	On( "EVENT_QUESTION_ADDED", A.OnQuestionAdded )
	On( "EVENT_AVATAR_FRIEND_LIST_LOADED", FriendsChanged )
	On( "EVENT_AVATAR_FRIEND_LIST_CHANGED", FriendsChanged )
	On( "EVENT_AVATAR_FRIEND_ADDED", FriendsChanged )
	On( "EVENT_AVATAR_FRIEND_REMOVED", FriendsChanged )
	-- «Взять на руки»: события нет в документации с 15.0.03, подписка на него проходит без ошибок
	-- Ожидаем: если клиент перестанет знать это событие, ошибка подписки попадёт в mods.txt; подписка стоит последней, чтобы не сорвать остальной запуск
	On( "EVENT_TAKE_ON_HANDS_REQUEST", A.OnTakeOnHands )

	BAA.Filter.RebuildFriends()
	UI.Render()
	BAA.Log( "BestAutoAccept " .. BAA.VERSION .. " загружен" ) --@debug
	if BAA.DEBUG then BAA.Probe.Report() end --@debug
end

common.RegisterEventHandler( Start, "EVENT_AVATAR_CREATED" )
if avatar.IsExist() then Start() end
