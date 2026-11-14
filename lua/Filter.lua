--------------------------------------------------------------------------------
-- BestAutoAccept / Filter.lua
-- На кого реагируем: чёрный список, друзья, согильдейцы.
--------------------------------------------------------------------------------
BAA.Filter = {}
local F = BAA.Filter

local friends = {}      -- [ник в нижнем регистре] = true (вместе с никами альтов)
local friendsLoaded = false

function F.RebuildFriends()
	friends = {}
	friendsLoaded = false
	-- Ожидаем: сразу после входа список друзей ещё не загружен — пересоберём по EVENT_AVATAR_FRIEND_LIST_LOADED
	if not social.IsFriendListLoaded() then return end
	local list = social.GetFriendList()
	-- Ожидаем: GetFriendList может вернуть nil — тогда друзей нет
	if type( list ) ~= "table" then return end
	for _, fid in pairs( list ) do
		local info = social.GetFriendInfo( fid )
		if type( info ) == "table" then
			local n = BAA.S( info.name )
			if n ~= "" then friends[ BAA.Lower( n ) ] = true end
			local alt = BAA.S( info.altName )
			if alt ~= "" then friends[ BAA.Lower( alt ) ] = true end
		end
	end
	friendsLoaded = true
end

function F.IsFriend( name )
	if not friendsLoaded then F.RebuildFriends() end
	if friends[ BAA.Lower( name ) ] then return true end
	return social.GetFriend( BAA.WS( name ) ) ~= nil
end

function F.IsGuildmate( name, unitId )
	-- Ожидаем: игрок не в гильдии — согильдейцев нет
	if not guild.IsExist() then return false end
	if guild.GetMember( BAA.WS( name ) ) ~= nil then return true end
	-- альт согильдейца рядом: сравниваем гильдию юнита со своей
	-- Ожидаем: юнит мог уйти из видимости — тогда гильдию по нему не сравниваем
	if unitId and object.IsExist( unitId ) then
		local a = unit.GetGuildInfo( avatar.GetId() )
		local b = unit.GetGuildInfo( unitId )
		-- Ожидаем: GetGuildInfo возвращает nil, если игрок не в гильдии
		if a and b and a.guildId ~= nil and a.guildId == b.guildId then return true end
	end
	return false
end

-- Можно ли реагировать на игрока. Возвращает true или false, причина
function F.Allowed( name, unitId )
	name = name or ""
	if name == "" then return false, "неизвестен игрок" end
	if BAA.Lower( name ) == BAA.Lower( BAA.MyName() ) then return false, "это вы" end
	if BAA.Cfg.IsBlacklisted( name ) then return false, "в чёрном списке" end
	if social.IsIgnored( BAA.WS( name ) ) then return false, "в игноре" end
	local r = BAA.cfg.react
	if r.all then return true end
	if r.friends and F.IsFriend( name ) then return true end
	if r.guild and F.IsGuildmate( name, unitId ) then return true end
	return false, "не друг и не согильдеец"
end
