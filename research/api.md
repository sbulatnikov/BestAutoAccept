# BestAutoAccept: исследование Lua API Аллодов Онлайн

Источники:
- **[D]** локальная официальная документация `/home/claude/baa/src/ModdingDocuments/` (версия 17.0.00). Пути ниже даны относительно `ModdingDocuments/LuaApi/`, если не указано иное.
- **[CL]** история изменений `ModdingDocuments/Changes/ChangelistX_Y_ZZ.html`.
- **[RPL]** наш проверенный в игре аддон `/home/claude/baa/src/RaidPartyLeader/Scripts/*.lua` (файлы в Windows-1251).
- **[PM]** тексты чужого аддона `PartyManager/Texts/*.txt` (UTF-16LE). По ним видно только, что он умеет; сам код я не смотрел.
- **[WEB]** alloder.pro: онлайн-документация (`https://alloder.pro/md/...`, версия 17.1) и форум.

Уверенность: **высокая** — прямо в документации и/или работает в RPL; **средняя** — есть в документации, но в игре никто не проверял, или вывод из нескольких фактов; **низкая** — гипотеза, которую надо проверить в игре.

---

## A. Команды по личным сообщениям

### A0. Получение личного сообщения (общее для команд 1–5)

| что | значение |
|---|---|
| событие | `EVENT_CHAT_MESSAGE`: приходит на каждое сообщение в любом канале. Есть расширенный вариант `EVENT_CHAT_MESSAGE_WITH_OBJECTS`, он приходит вместе с первым |
| поля `EVENT_CHAT_MESSAGE` | `sender: WString` — имя отправителя (игрок или моб); `shard: WString` — сервер отправителя; `senderUniqueId: UniqueId or nil`; `senderId: ObjectId or nil` (nil, если отправитель не отреплицирован, то есть далеко); `chatType: number (enum CHAT_TYPE_...)`; `isEcho: boolean` — наше собственное отправленное сообщение; `recipient: WString` — **только для CHAT_TYPE_WHISPER и только у эха**; `isAlive: boolean`; `msg: WString`; `spamWeight: number` (если ≥100, это спам) |
| дополнительные поля `..._WITH_OBJECTS` | `recipientUniqueId: UniqueId or nil`, `recipientId: ObjectId or nil`, `time = {h,m,s}`, `messages[0..] = { text, spamWeight, item, medal }` (вместо `msg`) |
| как понять, что это личка | `p.chatType == CHAT_TYPE_WHISPER`. Константа упоминается в документации как `CHAT_TYPE_WHISPER`, но страница перечня `CHAT_TYPE_...` удалена из документации в 7.0.00 и 7.0.01 («закрытая ссылка») — **числовых значений нет нигде**. Глобальные enum-константы других типов в рантайме существуют (RPL использует `GROUP_MEMBER_STATE_OFFLINE`, `RAID_MEMBER_RIGHT_*`), значит `CHAT_TYPE_WHISPER` скорее всего тоже есть. Запасной признак: в `EVENT_CHAT_MESSAGE_WITH_OBJECTS` у входящей лички `recipientUniqueId == avatar.GetUniqueId()` (гипотеза) |
| отличить свои исходящие | `p.isEcho == true` (эхо нашего сообщения). Дополнительно: `S(p.sender) == своё имя` (`object.GetName(avatar.GetId())`) |
| ник отправителя | `userMods.FromWString(p.sender)`, при межсерверной активности ещё `p.shard`. Строку в WString — через `userMods.ToWString(s)` |
| id отправителя | `p.senderUniqueId` (постоянный, подходит для `group.SetLeader`, `raid.ChangeLeader`, `group.IsLeader`); `p.senderId` (ObjectId, если отправитель рядом; нужен для `object.GetDistance`, `unit.GetGuildInfo`) |
| ограничения | «в пользовательских аддонах событие может не приходить на турнирах» [D]. WString нельзя использовать как ключ таблицы и сравнивать через `==` (форум, 15.1) — сравнивать только после `FromWString` |
| источник | `EventChatMessage.html`, `EventChatMessageWithObjects.html`; [CL] `Changelist7_0_00.html` и `7_0_01` (удалён `CHAT_TYPE_...`); форум alloder.pro, тема 6928 «Изменения API в 15.1» |
| уверенность | поля — высокая (RPL читает `p.msg`, `p.isEcho`, `p.chatType`); значение `CHAT_TYPE_WHISPER` — **средняя, проверить в игре** |

Как найти юнит отправителя, если `senderId == nil`: `avatar.GetUnitList()` возвращает список ObjectId видимых юнитов (индексы с 1, сам аватар не входит). Сравнивать нужно `FromWString(object.GetName(id))` с ником, лучше вместе с `unit.IsPlayer(id)`. Дистанция: `object.GetDistance(id)` в метрах или nil. Для пользовательских аддонов учитывается только детектируемость объекта. Источник: `FunctionAvatarGetUnitList.html`, `FunctionObjectGetDistance.html`, `FunctionObjectGetName.html`. Уверенность высокая.

Кодировка: `FromWString` возвращает обычную Lua-строку. RPL пишет скрипты в Windows-1251, а `RPL.CharLen` на всякий случай распознаёт и UTF-8: какую кодировку возвращает клиент, однозначно не выяснено. Команды `++ !! ?? ## >>` — чистый ASCII, поэтому нам это не важно. Нужно лишь обрезать пробелы (`RPL.Trim`) и сравнивать точно.

### 1. `++` — пригласить отправителя

| что | событие / функция | поля / параметры | права и ограничения | источник | уверенность |
|---|---|---|---|---|---|
| пригласить в группу | `group.InviteByName( name: WString )`, альтернатива `group.Invite( unitId )` для юнита рядом | — | Вне группы приглашение создаёт группу, и мы становимся лидером (так работает RPL). В группе приглашать может **только лидер**: иначе придёт `ENUM_GROUP_INVITE_FAILED_NOT_LEADER`. Проверка — `group.CanInvite()` | `FunctionGroupInviteByName.html`, `FunctionGroupCanInvite.html`, [RPL] `Game.lua: G.Invite`, `G.Read` | высокая |
| пригласить в отряд | `raid.InviteByName( name )`, `raid.Invite( unitId )` | — | Приглашают лидер **и помощники** (`RAID_MEMBER_RIGHT_LEADER_HELPER`). `raid.CanInvite( unitId )` по документации принимает unitId или nil, но в RPL вызов без аргумента дал ошибку «wrong params count (0, should be 1)». Поэтому права проверяем сами: `raid.IsLeader()` или своё право помощника | `FunctionRaidInviteByName.html`, `FunctionRaidCanInvite.html`, [RPL] `Game.lua` (комментарий к `st.canInvite`) | высокая |
| результат: ошибка | `EVENT_GROUP_INVITE_FAILED` | `name: WString`, `sysReason`: `ENUM_GROUP_INVITE_FAILED_NOT_EXIST / NOT_LOGGED_IN / CANT_INVITE_SELF / FULL_GROUP / ALREADY_IN / ZONE_NOT_ALLOWED / NOT_LEADER` | — | `EventGroupInviteFailed.html`, `EnumGroupInviteFailed.html` | высокая |
| результат: отказ | `EVENT_GROUP_DECLINE`, `EVENT_GROUP_DECLINE_BUSY`, `EVENT_GROUP_DECLINE_IGNORED`, `EVENT_RAID_DECLINE`, `EVENT_RAID_DECLINE_BUSY`, `EVENT_RAID_DECLINE_IGNORED`, `EVENT_RAID_ALREADY_IN` | `declinerName: WString` | По опыту RPL `*_DECLINE` и `*_BUSY` до аддона **могут не дойти**; запасной путь — системный текст в `EVENT_CHAT_MESSAGE` («отказывается вступить», «занят и не может вступить»; зависит от локализации) | [RPL] `Main.lua: OnDecline, OnCantJoin, OnChatMessage` | высокая |
| ошибка отряда | `EVENT_RAID_FAILED` | `sysReason`: `ENUM_RAID_FAILED_NOT_ENOUGH_RIGHTS / PLAYER_IS_NOT_IN_RAID / PLAYER_ALREADY_IN_RAID / LEADER_CANT_LEAVE / ZONE_NOT_ALLOWED / ALREADY_FULL` | **ника в событии нет** | `EventRaidFailed.html`, `EnumRaidFailed.html`, [RPL] `OnRaidFailed` | высокая |
| игрок не найден | `EVENT_ADDRESSEE_NOT_FOUND` | `name`, `sysRequestType` (`ENUM_RequestAddressByNameType_GroupInvite / RaidInvite / Whisper ...`), `sysCause` (`..._NotExist / _NotLoggedIn`) | — | `EventAddresseeNotFound.html` | высокая |
| группа полная (6 человек) | при `FULL_GROUP` нужно превратить группу в отряд: `raid.Create()` (отряд на 24) или `raid.CreateSmall()` (малый отряд на 12) — их **вызывает лидер группы** — затем дождаться `EVENT_GROUP_CONVERTED` / `EVENT_RAID_APPEARED` и пригласить через `raid.InviteByName` | — | Если мы не лидер полной группы, сделать ничего нельзя: остаётся ответить отправителю или вывести сообщение у себя. Полный отряд даёт `ENUM_RAID_FAILED_ALREADY_FULL` | `FunctionRaidCreate.html`, `FunctionRaidCreateSmall.html`, `EventGroupConverted.html`, [RPL] `OnGroupInviteFailed` (ждёт превращения в отряд и приглашает снова) | высокая |
| автоматическая группа | `group.IsAutomatic()`, `raid.IsAutomatic()`: группы и отряды, собранные подбором; их нельзя распускать и из них нельзя исключать | — | вероятно, приглашать в них тоже нельзя — проверить | `FunctionGroupIsAutomatic.html` | средняя |
| таймаут | события об истечении **исходящего** приглашения нет; в игре приглашение живёт около 30 с | — | — | [RPL] `Util.lua: RPL.INVITE_TIMEOUT`, `Main.lua` (комментарий) | высокая (по RPL) |

### 2. `!!` — передать лидерство отправителю

| что | функция | параметры | права и ограничения | источник | уверенность |
|---|---|---|---|---|---|
| группа | `group.SetLeader( uniqueId )` | `UniqueId` участника группы | Вызывает только лидер (`group.IsLeader()`). Отправитель должен быть в группе: `group.GetMemberInfo( senderUniqueId или ник )` — не nil. Офлайн-участнику передать нельзя (`state == GROUP_MEMBER_STATE_OFFLINE`; в RPL это отдельный тост) | `FunctionGroupSetLeader.html`, `FunctionGroupGetMemberInfo.html`, [RPL] `G.SetLeader`, `OnLeader` | высокая |
| отряд | `raid.ChangeLeader( uniqueId )` | `UniqueId` | Только лидер (`raid.IsLeader()`). Членство: `raid.IsPlayerInAvatarsRaid( WString / ObjectId / UniqueId )` или `raid.GetMemberInfo( id )` | `FunctionRaidChangeLeader.html`, `FunctionRaidIsPlayerInAvatarsRaid.html` | высокая |
| подтверждение | `EVENT_GROUP_LEADER_CHANGED`, `EVENT_RAID_LEADER_CHANGED` (без полей) | — | — | `EventGroupLeaderChanged.html`, `EventRaidLeaderChanged.html` | высокая |
| ник против id | Проверка по нику (WString) «неустойчива к коллизии ников на межсерверных активностях»: предпочитаем `p.senderUniqueId` | — | `senderUniqueId` может быть nil: тогда берём `GetMemberInfo(ник).uniqueId` | `FunctionGroupIsLeader.html` | высокая |

### 3. `??` — запустить проверку готовности

| что | функция / событие | поля | права и ограничения | источник | уверенность |
|---|---|---|---|---|---|
| группа | `group.StartReadyCheck()` | — | лидер группы | `FunctionGroupStartReadyCheck.html`, [RPL] `G.StartReadyCheck`, `st.canReady` | высокая |
| отряд | `raid.StartReadyCheck()` | — | лидер **и помощники** (в RPL: «Проверку готовности запускают лидер и помощники») | `FunctionRaidStartReadyCheck.html`, [RPL] | высокая |
| уже идёт? | `group.GetReadyCheckInfo()` / `raid.GetReadyCheckInfo()` → `nil` или `{ isInProgress, remainingTimeMs, initiatorId: UniqueId, members[0..] = { uniqueId, state: READY_CHECK_READY_STATE_UNKNOWN / READY / NOT_READY } }` | — | не запускать повторно, пока `isInProgress` | `FunctionGroupGetReadyCheckInfo.html` | высокая |
| события | `EVENT_READY_CHECK_STARTED { initiatorId: UniqueId }`, `EVENT_READY_CHECK_INFO_CHANGED`, `EVENT_READY_CHECK_ENDED` | — | — | `EventReadyCheckStarted.html`, `EventReadyCheckEnded.html` | высокая |
| свой ответ | `group.ReportReadyCheck( ready )`, `raid.ReportReadyCheck( ready )` | — | может понадобиться для автоматического ответа «готов» (не входит в ТЗ) | `FunctionGroupReportReadyCheck.html` | высокая |

### 4. `##` — начать обмен с отправителем

| что | функция / событие | поля | права и ограничения | источник | уверенность |
|---|---|---|---|---|---|
| пригласить к обмену | `interaction.InviteToExchange( invitedName: WString )` — **по имени**, ObjectId не нужен | — | Отправитель должен быть рядом. При ошибке придёт `EVENT_ITEMS_EXCHANGE_ERROR`. Не вызывать, если `interaction.HasExchange()` уже true | `FunctionInteractionInviteToExchange.html`, `FunctionInteractionHasExchange.html` | высокая (документация) / средняя (в игре) |
| ошибка | `EVENT_ITEMS_EXCHANGE_ERROR` | `inviter: WString`, `invited: WString`, `error`: `ENUM_MsgStartExchangeResultResult_INVITEDAVATARISBUSY / INVITERAVATARISBUSY / INVITEDAVATARNOTFOUND / TOOFAR / INVITEDAVATARISDEAD / INVITERAVATARISDEAD / YOUAREINVISIBLE / ERROR` и `ENUM_MsgExchangeErrorErrorType_...` | `TOOFAR` — ограничение по дистанции (величина в документации не указана) | `EventItemsExchangeError.html`, `EnumExchangeResult.html` | высокая |
| игнор | `EVENT_ITEMS_EXCHANGE_DECLINE_IGNORED { declinerName }` | — | — | `EventItemsExchangeDeclineIgnored.html` | высокая |
| начало / конец | `EVENT_ITEMS_EXCHANGE_STARTED` (без полей), `EVENT_ITEMS_EXCHANGE_STATE_CHANGED` (без полей), `EVENT_ITEMS_EXCHANGE_FINISHED { state: ItemsExchangeState_INVITATION / INPROGRESS / COMPLETED / CANCELED / FAILED / NOBAGSPACE / LOST }` | — | — | `EventItemsExchange*.html`, `ItemsExchangeState.html` | высокая |
| проверка расстояния заранее | `object.GetDistance( senderId )`, если `senderId` известен | — | необязательно: сервер сам ответит `TOOFAR` | `FunctionObjectGetDistance.html` | высокая |

### 5. `>>` — следовать за отправителем

| что | функция / событие | поля | права и ограничения | источник | уверенность |
|---|---|---|---|---|---|
| включить следование | `avatar.SetFollowTarget( isFollow: boolean )` | — | **Следует за ТЕКУЩЕЙ ЦЕЛЬЮ на момент вызова**: параметра «за кем» нет | `FunctionAvatarSetFollowTarget.html` | высокая |
| выбрать цель | `avatar.SelectTarget( unitId )` | — | **Ограничение для пользовательских аддонов: работает только в обработчиках реакций на действия мыши (нажатие кнопки)**, а не в обработчике события чата. Поэтому автоматически «взять отправителя в цель и пойти за ним» из `EVENT_CHAT_MESSAGE`, скорее всего, **не получится** | `FunctionAvatarSelectTarget.html` | высокая (ограничение задокументировано) |
| текущая цель | `avatar.GetTarget()` → ObjectId или nil; `EVENT_AVATAR_TARGET_CHANGED` | — | если отправитель уже в цели, `SetFollowTarget(true)` можно вызвать сразу | `FunctionAvatarGetTarget.html`, `EventAvatarTargetChanged.html` | высокая |
| статус | `EVENT_FOLLOW_MODE_CHANGED { followObjectId: ObjectId or nil }` | — | По событию проверяем, что следуем именно за отправителем; nil — следование выключено | `EventFollowModeChanged.html` | высокая |
| можно ли взять в цель | `unit.CanSelectTarget( unitId )` | — | например, из-за другого плана | `FunctionUnitCanSelectTarget.html` | высокая |
| найти юнит | `p.senderId`, иначе перебор `avatar.GetUnitList()` по имени | — | Юнит должен быть в зоне видимости | см. A0 | высокая |

Рекомендация для `>>`. (1) Если `avatar.GetTarget() == senderId`, сразу `SetFollowTarget(true)`. (2) Иначе один раз попробовать `pcall(avatar.SelectTarget, senderId)`, затем проверить `GetTarget()`. (3) Если не сработало, показать тост или кнопку «Следовать за X». В её обработчике реакции `SelectTarget(id)` и `SetFollowTarget(true)` разрешены. В PartyManager есть кулдаун «Следование за целью» [PM], значит он как-то это делает — сверить с разбором его байткода.

---

## B. Автоматическое принятие

### 6. Приглашение в группу или отряд

| что | событие | поля | функция принятия / отказа | таймаут | кто приглашает | источник | уверенность |
|---|---|---|---|---|---|---|---|
| группа | `EVENT_GROUP_INVITE` | `inviterName: WString`, `inviterShardName: WString` | `group.Accept()` / `group.Decline()`. Без активного приглашения вызов — ошибка, поэтому сначала `group.GetInviteInfo().invited` | `EVENT_GROUP_INVITE_END` (без полей): истекло, принято или отклонено. Около 30 с | только имя и сервер, id нет | `EventGroupInvite.html`, `FunctionGroupAccept.html`, `FunctionGroupGetInviteInfo.html` (`{invited, inviterName, inviterShardName}`), `EventGroupInviteEnd.html` | высокая (документация); в игре нашим кодом не проверено |
| отряд | `EVENT_RAID_INVITE` | `inviterName`, `inviterShardName` | `raid.Accept()` / `raid.Decline()`, перед этим `raid.GetInviteInfo().invited` (функция добавлена в 15.1) | `EVENT_RAID_INVITE_END` | имя и сервер | `EventRaidInvite.html`, `FunctionRaidAccept.html`, `FunctionRaidGetInviteInfo.html` | высокая / средняя |
| ошибка вступления | `EVENT_GROUP_ACCEPT_ERROR`, `EVENT_RAID_CANT_ACCEPT` (без полей) | — | — | — | — | `EventGroupAcceptError.html`, `EventRaidCantAccept.html` | высокая |

Замечание [PM]: в PartyManager есть настройка «Прятать последнее диалоговое окно. Внимание! Оно может оказаться НЕ запросом на принятие приглашения». Видимо, после `Accept()` из аддона **стандартное окно-вопрос клиента остаётся на экране**. Мы его закрыть не можем: пользовательские аддоны не меняют оригинальные интерфейсы (`Creating.html`). Проверить в игре.

### 7. Приглашение в «активность»

В API нет единого «приглашения в активность». Есть несколько механизмов:

| механизм | событие | поля | ответ | таймаут | кто приглашает | источник | уверенность |
|---|---|---|---|---|---|---|---|
| **Подбор группы (LFG), голосование** | `EVENT_LFG_VOTE`; срыв — `EVENT_LFG_VOTE_TERMINATE` | `initiator: WString`, `type: ENUM_LFGVoteType_Join / ENUM_LFGVoteType_Invite`, `destination: LfgDestinationId or nil`, `endTimeMs: int64`, `roles: table of ENUM_LFGRole` (вакантные роли) | `lfgLib.VoteYes( roles )` (для типов Join и Invite передаются выбранные роли: `ENUM_LFGRole_Tank / _Healer / _DamageDealer`; доступные роли даёт `lfgLib.GetRoles()`) / `lfgLib.VoteNo()` | `endTimeMs` | есть: `initiator` (имя) | `EventLfgVote.html`, `FunctionLfgLibVoteYes.html`, `EnumLfgVoteType.html`, `EnumLfgRole.html`, `FunctionLfgLibGetRoles.html` | высокая (документация) |
| **Инстанс-ивенты** (арены, поля боя, Мавзолей и т. п. — «очередь подошла») | `EVENT_MATCH_MAKING_EVENT_TELEPORT_REQUEST`; отмена — `EVENT_MATCH_MAKING_EVENT_TELEPORT_REJECTED { eventId, isTimeout }` | `eventId: ObjectId`, `timeoutMs`, `isDelayedInvite: boolean` (в бою телепорт произойдёт после таймаута) | `matchMaking.InstancedEventTeleportReply( accept )` — **«закрытая ссылка»; описание удалено из документации в 16.0.00**. Скорее всего, для пользовательских аддонов функции нет. Проверить в рантайме: `type(matchMaking.InstancedEventTeleportReply) == "function"` | `timeoutMs` | **нет**: это очередь, а не игрок, поэтому фильтр «друзья / гильдия» неприменим. Что за ивент — `matchMaking.GetEventInfo(eventId)` → `name`, `category`, `mechanicsType` (`ENUM_MatchMakingMechanicsType_RATING_ARENA / GLADIATOR_ARENA / BATTLEGROUND / ...`), `resourceId` | `EventMatchMakingEventTeleportRequest.html`, `EventMatchMakingEventTeleportReject.html`, `FunctionMatchMakingGetEventInfo.html`, `EnumMatchMakingMechanicsType.html`, [CL] `Changelist16_0_00.html` | события — высокая; ответ — **низкая** |
| **Телепорт с одногруппником** (одногруппник «собирается телепортироваться», нас зовут с собой) | `EVENT_TELEPORT_OFFER_REQUEST` | `requesterId: ObjectId` (одногруппник), `timeoutMs` | `avatar.TeleportOfferReply( accept: boolean )` | `timeoutMs` | есть: `object.GetName( requesterId )` | `EventTeleportOfferRequest.html`, `FunctionAvatarTeleportOfferReply.html` | высокая (документация) |
| сохранение в рейдовом инстансе | `EVENT_RAID_SAVE_MAP_QUESTION { timeoutMs, mapName }` | — | `raid.MapSaveResponse( true )` | `timeoutMs` | нет | `EventRaidSaveMapQuestion.html` | высокая; автоматически принимать **не рекомендую**: это привязка к сохранению |
| универсальные вопросы сервера | `EVENT_QUESTION_ADDED { id }` / `EVENT_QUESTION_REMOVED { id }` | `questionLib.GetInfo(id)` → `{ type ("!QuizQuestion" ...), questionData = { text, type: ENUM_QuizQuestionType_UNSPECIFIC / VOTE_KICK / CHOICE_ROLES }, clientData (пары имя–значение, как values в EVENT_CLIENT_MESSAGE), remainingTimeMs, isObserver }` | `questionLib.SendData( id, { choice = 1 } )` — «да», `{ choice = 0 }` — «нет»; `questionLib.Cancel( id )` | `remainingTimeMs` | в `clientData` (имена параметров зависят от вопроса) | `CategoryQuestionLib.html`, `FunctionQuestionLibGetInfo.html`, `FunctionQuestionLibSendData.html`, `TypeQuestionLibQuizQuestion.html`, `EventClientMessage.html` | документация — высокая; что именно сервер так спрашивает — низкая |

Про конкретные активности из ТЗ (Астрал, Охотничьи угодья / Дикие земли, Безвременье / Искажения, Арена героев). PartyManager держит для них отдельные пункты в разделе «Режим автоответчика»: Astral, HeroesArena («Мавзолей искр»), HuntingGrounds («Дикие земли», «Устарело в 7.0»), TimeVoid («Искажения / Таинственные земли») [PM]. Отдельных событий-приглашений для них в API **нет**: категории `CategoryHuntingGrounds`, `CategoryAstralLua`, `CategoryProceduralDungeonLib` и т. п. ничего похожего не содержат. Это либо инстанс-ивенты matchMaking (тип различаем через `matchMaking.GetEventInfo`), либо LFG-направления (`lfgLib.GetDestinationCategories / GetDestinations`), либо телепорт с одногруппником. Как именно PartyManager принимает эти приглашения, должен показать разбор его байткода. Уверенность: низкая.

### 8. Приглашение к обмену

| что | значение |
|---|---|
| событие | `EVENT_ITEMS_EXCHANGE_INVITED` — «Главному игроку предложено поторговать с другим игроком». **Полей нет** |
| кто приглашает | Документированного поля нет. Варианты: `interaction.GetExchangeInviter()` → `{ playerId: ObjectId, money, primaryConfirmed, finalConfirmed, items }` («nil, если обмен не начат» — работает ли на этапе приглашения, неизвестно), затем `object.GetName( playerId )`. Состояние: `interaction.IsExchangeInInvitation()`, `interaction.IsAvatarExchangeInviter()` |
| функция принятия | **В публичном API её нет.** `interaction.AcceptInviteToExchange( inviterName )` вместе с `PrimaryConfirmExchange`, `FinalConfirmExchange`, `PlaceExchangeItem` и `SetExchangeMoney` **удалены из документации в 4.0.03**. Похоже, торговлю целенаправленно закрыли для аддонов. Проверить в рантайме: `type(interaction.AcceptInviteToExchange)`. Непроверенная гипотеза: ответное `interaction.InviteToExchange( inviterName )` может принять встречное приглашение |
| отклонить | `interaction.CancelExchange()` |
| таймаут | не задокументирован |
| источник | `EventItemsExchangeInvited.html`, `FunctionInteractionGetExchangeInviter.html`, `FunctionInteractionIsExchangeInInvitation.html`, [CL] `Changelist4_0_03.html` |
| уверенность | событие — высокая; принятие — **низкая** (в PartyManager есть пункт «Принимать торг» [PM] — сверить с разбором) |

### 9. Транспорт и двухместные маунты («Молния», AirMoto)

| что | значение |
|---|---|
| стать пассажиром | Отдельного события-приглашения «сесть в транспорт» или «сесть на маунт» в API **нет**. Есть только состояние: `avatar.IsPassangerState()` (пассажир, например, на двухместном маунте) и `EVENT_PASSANGER_STATE_CHANGED { passangerState: boolean }` |
| как приходит приглашение | Текст PartyManager: `[<r name="caster"/>] предлагает вам занять пассажирское место Молнии. Вы согласны?` [PM]. Тег `<r name="caster"/>` — это подстановка параметра по имени, как у пар имя–значение в `EVENT_CLIENT_MESSAGE` и в `clientData` questionLib. **Гипотеза: это `EVENT_QUESTION_ADDED` типа `!QuizQuestion`, а в `clientData` лежит параметр `caster` (objectId или text)**. Ответ: `questionLib.SendData( id, { choice = 1 } )`. Второй кандидат — `EVENT_CLIENT_MESSAGE` с `sysId = "ENUM_MESSAGE_BOX"` / `"ENUM_MODAL_MESSAGE"`, но на него ответить нечем |
| корабль | Механизма «пригласить на корабль» в API не найдено. Возможные варианты: `EVENT_TELEPORT_OFFER_REQUEST` (пункт 7) или questionLib. `hangar.LendShip` и `social.LendMount` — передача корабля или маунта побратиму, а не приглашение |
| кто приглашает | для questionLib — из `clientData` (параметр `caster`) |
| таймаут | `remainingTimeMs` у вопроса |
| источник | `FunctionAvatarIsPassangerState.html`, `EventPassangerStateChanged.html`, `CategoryQuestionLib.html`, `EventClientMessage.html`, [PM] `Texts/AirMotoQuestion.txt` |
| уверенность | **низкая**: нужен зонд (см. «Готовые фрагменты», зонд questionLib) |

### 10. «Взять на руки» (переноска персонажа)

| что | значение |
|---|---|
| название в API | `EVENT_TAKE_ON_HANDS_REQUEST` (запрос) и `family.TakeOnHandsResponse( takeOnHands: boolean )` (ответ). Семейная механика: супруги, `CategoryFamily` |
| статус | **Обе страницы удалены из документации в 15.0.03** (в старых версиях было и `EventFamilyTakeOnHandsRequest`; WEB, таблица истории API). В текущей `CategoryFamily` (и онлайн 17.1) их нет. Возможно, механику перенесли в questionLib или закрыли |
| поля запроса | неизвестны (документация удалена) |
| проверка в рантайме | `type(family) == "table" and type(family.TakeOnHandsResponse) == "function"`; регистрацию `EVENT_TAKE_ON_HANDS_REQUEST` обернуть в pcall. Иначе ловить через зонд questionLib |
| источник | [CL] `Changelist15_0_03.html` («Удалены документы»), `CategoryFamily.html`, https://alloder.pro/t/AO_Lua_API_history.html |
| уверенность | имена — высокая (как были); работоспособность — **низкая** |

### 11. Воскрешение от другого игрока

| что | значение |
|---|---|
| событие | `EVENT_RESURRECT_REQUESTED` |
| поля | `resurrecterName: WString`, `unitId: ObjectId (not nil)` — кто воскрешает, `timeOutMs: number` (именно `timeOutMs`, с большой O) |
| ответ | `avatar.ResurrectReply( accept: boolean )` |
| таймаут | `timeOutMs`; если не ответить вовремя, придёт `EVENT_RESURRECT_REJECTED { resurrecterName, unitId or nil }` |
| кто | имя и ObjectId: можно проверить гильдию через `unit.GetGuildInfo( unitId )` |
| доп. условие | В PartyManager настройка звучит как «принимать запрос на воскрешение **вне боя**» [PM]; бой проверяется через `object.IsInCombat( avatar.GetId() )` |
| источник | `EventResurrectRequested.html`, `EventResurrectRejected.html`, `FunctionAvatarResurrectReply.html`, `FunctionObjectIsInCombat.html` |
| уверенность | высокая (документация) |

---

## C. Фильтр «на кого реагируем»: все, друзья, согильдейцы

| что | функции / события | поля | ограничения | источник | уверенность |
|---|---|---|---|---|---|
| друг по нику | `social.GetFriend( name: WString )` → friendId (ObjectId из списка друзей, **не id игрока**) или nil | — | Работает только после загрузки списка | `FunctionSocialGetFriend.html` | высокая |
| весь список | `social.GetFriendList()` → таблица friendId с индексами **с 0**; `social.GetFriendInfo( friendId )` → `{ name, altName, isLogged, isAlt, sysOnlineStatus (ENUM_AvatarOnlineStatus_Offline / Online / OnAlt / Shadow), isBestFriend, isSimpleFriend, isSpouse, level, zoneName, ... }` | — | `raceClass`, `sex`, `mapId`, `moodEmote` заполняются с задержкой | `FunctionSocialGetFriendList.html`, `FunctionSocialGetFriendInfo.html` | высокая |
| загрузка | `social.IsFriendListLoaded()`; `EVENT_AVATAR_FRIEND_LIST_LOADED`, `EVENT_AVATAR_FRIEND_LIST_CHANGED`, `EVENT_AVATAR_FRIEND_ADDED { name }`, `EVENT_AVATAR_FRIEND_REMOVED { name }` | — | Сразу после входа список может быть не загружен: кэш нужно перестроить по событию | `FunctionSocialIsFriendListLoaded.html`, `EventAvatarFriendListLoaded.html` | высокая |
| альт друга | Если друг сидит на другом перерождении (`isAlt`, `altName`), его сообщение придёт с ником альта. В кэш друзей класть **и `name`, и `altName`**. Похожая ситуация: `EVENT_CHAT_SENT_TO_ALT { altName }`, когда мы пишем другу, который на альте | — | — | `FunctionSocialGetFriendInfo.html`, `EventChatSentToAlt.html` | средняя |
| игнор | `social.IsIgnored( ObjectId or WString )` | — | Сразу после входа возможен ложный отрицательный результат; проверять `social.IsIgnoreListLoaded()` | `FunctionSocialIsIgnored.html` | высокая |
| в гильдии ли мы | `guild.IsExist()`, `guild.GetName()` | — | — | `FunctionGuildIsExist.html` | высокая |
| согильдеец по нику (онлайн и офлайн) | `guild.GetMember( playerName: WString )` → memberId (**не id игрока**) или nil; `guild.GetMemberInfo( memberId )` → `{ name, playerId (nil, если не в игре или не отреплицирован), onlineStatus: "ENUM_AvatarOnlineStatus_...", level, rank..., zoneName, ... }` | — | В список входят и офлайн-участники. Альт согильдейца (`OnAlt`) пишет с другим ником, и по нику мы его не найдём | `FunctionGuildGetMember.html`, `FunctionGuildGetMemberInfo.html`, `EnumAvatarOnlineStatus.html` | высокая |
| весь список | `guild.GetMembers()` → таблица memberId с индексами **с 0** | — | — | `FunctionGuildGetMembers.html` | высокая |
| согильдеец по юниту рядом | `unit.GetGuildInfo( unitId )` → `{ name, rank, level, guildId }` или nil; сравнить `guildId` со своим (`unit.GetGuildInfo( avatar.GetId() )`) | — | нужен ObjectId: `senderId`, `unitId` воскрешающего, `requesterId` | `FunctionUnitGetGuildInfo.html` | высокая |
| события гильдии | `EVENT_GUILD_APPEARED` (при входе в игру тоже), `EVENT_GUILD_DISAPPEARED`, `EVENT_GUILD_LIST_CHANGED`, `EVENT_GUILD_MEMBER_ADDED / _REMOVED / _CHANGED / _ONLINE_STATUS_CHANGED { id, name }` (в онлайн-версии 17.1 добавлено `playerId`) | — | Список приходит асинхронно, после `EVENT_GUILD_APPEARED`. `EVENT_GUILD_MEMBER_REMOVED` приходит и при простом обновлении данных с сервера: настоящий вывод из гильдии — `EVENT_GUILD_MEMBER_KICKED` | `EventGuild*.html`, онлайн `https://alloder.pro/md/LuaApi/EventGuildMemberAdded.html` | высокая |
| ник в запросах «кто приглашает» | группа и отряд — `inviterName`; LFG — `initiator`; воскрешение — `resurrecterName` и `unitId`; телепорт — `requesterId`; обмен — неизвестно (см. 8) | — | — | — | — |

Сравнение ников: WString не годится как ключ таблицы и для `==`. Переводим в строку `FromWString`, кэшируем `{ [ник] = true }`. Регистр: ник в игре уникален с точностью до регистра, но `string.lower` знает только латиницу; для кириллицы в 1251 есть `RPL.Lower`. Сначала проверить, совпадают ли строки один в один.

---

## D. Общая инфраструктура

| что | функция / событие | подробности | источник | уверенность |
|---|---|---|---|---|
| старт аддона | `EVENT_AVATAR_CREATED { id }` и `if avatar.IsExist() then Start() end` | `avatar.GetId()` при старте скриптов может быть nil | `EventAvatarCreated.html`, `FunctionAvatarGetId.html`, [RPL] `Main.lua` (конец файла) | высокая |
| регистрация событий | `common.RegisterEventHandler( fn, "EVENT_NAME", filter?, registerPersonal? )` | `filter` — таблица точных значений полей: обработчик вызывается только при совпадении. Допустимы number, string, boolean, wstring, indexable userdata. Отписка — `common.UnRegisterEventHandler` с теми же параметрами. В старом `Creating.html`: «только одна функция-обработчик на событие», в новой странице функции: «может быть несколько». Безопаснее один обработчик на событие | `FunctionCommonRegisterEventHandler.html`, `Creating.html` | высокая |
| персональные события | `common.EnablePersonalEvent( sysEventName, objectId )` нужно **только** для `EVENT_HEALING_RECEIVED`, `EVENT_UNIT_DAMAGE_RECEIVED`, `EVENT_OBJECT_BUFF_*`, `EVENT_OBJECT_HEALTH_CHANGED`, `EVENT_MANA_RECEIVED` и т. п. Для BestAutoAccept **не нужны** | онлайн `https://alloder.pro/md/LuaApi/FunctionCommonEnablePersonalEvent.html` | высокая |
| реакции кнопок | `common.RegisterReactionHandler( fn, "reaction_name" )` | кнопка может прислать реакцию дважды (`params.active = true`, затем `false`): RPL обрабатывает клик один раз | `FunctionCommonRegisterReactionHandler.html`, [RPL] `Main.lua: Reaction` | высокая |
| таймер | `EVENT_SECOND_TIMER { timeMs, elapsedMs }` — раз в секунду | основа кулдаунов и задержек (RPL: `RPL.tick`) | `EventSecondTimer.html`, [RPL] `OnSecond` | высокая |
| точное время | `common.GetAbsTimeMs()` — игровой таймер, мс, тикает раз в кадр | кулдауны с точностью до кадра; троттлинг событий в RPL | `FunctionCommonGetAbsTimeMs.html`, [RPL] `OnChanged` | высокая |
| задержка меньше секунды | `common.RegisterFrameHandler( fn( elapsedMs, timeMs ), needHit )` и `common.HitFrameHandler` | Жёсткие ограничения: в обработчике кадра нельзя работать с конфигами, отправлять события, писать в лог; при `needHit = false` — не дольше 3 мс, иначе после 100 нарушений блокировка. Один обработчик на аддон | `FunctionCommonRegisterFrameHandler.html` | высокая |
| будущее API | `common.DelayedCall( delayMs, fn, ... )`, `common.CancelDelayedCall`, `common.GetDelayedCalls` — **только в «Будущем патче»**, в 17.0 их нет. Проверять `if common.DelayedCall then` | онлайн `https://alloder.pro/md/Changes/Changelistnext_version_preview.html` | высокая |
| настройки на всех персонажей | `userMods.GetGlobalConfigSection( name )` → table or nil; `userMods.SetGlobalConfigSection( name, tbl or nil )` | Секция записывается целиком. В RPL та же секция `common.GetAddonName()` хранит и позиции окон LibDnD, поэтому писать её всю, не затирая чужие ключи. Файл `Mods/Configs/<Addon>/user.cfg` правится только при закрытой игре | `FunctionUserModsGetGlobalConfigSection.html`, [RPL] `Storage.lua: LoadSettings` | высокая |
| настройки на персонажа | `userMods.GetAvatarConfigSection( name )` / `userMods.SetAvatarConfigSection( name, tbl )` | Читать через pcall. Хранить строковые ключи, а не числа enum: числа меняются между версиями (правило RPL) | `FunctionUserModsGetAvatarConfigSection.html`, [RPL] `Storage.lua` | высокая |
| имя аддона | `common.GetAddonName()` — имя из ресурса (RPL использует его для секции конфига); `common.GetAddonSysName()` — настоящее имя `"UserAddon/<папка>"` | для конфигов достаточно `GetAddonName()` | `FunctionCommonGetAddonName.html`, `FunctionCommonGetAddonSysName.html` | высокая |
| вывод в свой чат | `userMods.SendSelfChatMessage( WString, "message" / "notice" / "warning" / "error" )` → «Системные → Дополнения»; другим игрокам не уходит | на случай ошибки — `common.LogInfo( "common", ... )` в `Personal\Logs\mods.txt` (лог клиента часто выключен) | `FunctionUserModsSendSelfChatMessage.html`, [RPL] `Util.lua: RPL.Chat` | высокая |
| ответить отправителю в чат | **функции отправки сообщения другим игрокам в API не найдено**: есть только `mission.SetChatInputText / SetChatInputType` (заполнить строку ввода; нажать Enter должен сам игрок) | `FunctionMissionSetChatInputType.html` | средняя |
| слеш-команда настроек | `EVENT_UNKNOWN_SLASH_COMMAND { text: WString }` (например, `/baa`) | так сделан `/rplprobe` в RPL | `EventUnknownSlashCommand.html`, [RPL] `Probe.lua` | высокая |
| строки | `userMods.ToWString( s )` / `userMods.FromWString( ws )`; FromWString вызывать через pcall | WString не ключ таблицы; UniqueId и ObjectId — индексируемые userdata, сравниваются по значению и годятся как ключи (проверено зондом RPL; форум 15.1) | `FunctionUserModsToWString.html`, [RPL] `Util.lua: RPL.S` | высокая |
| ограничения Lua | LuaJIT 2.1; нет `require`, `load*`, `dofile`, `getfenv` и `setfenv`, библиотек `os`, `io`, `debug`; глобальные переменные только через `Global( name, value )` | `Creating.html`, форум 15.1 | высокая |

---

## Риски и неясности

1. **`CHAT_TYPE_WHISPER`.** Числового значения в документации нет: страница удалена в 7.0.00 и 7.0.01. Если глобальной константы в рантайме нет, нужна калибровка: попросить друга написать в личку и вывести `p.chatType` в чат (у RPL такой вывод уже есть в режиме отладки). Резервный признак — `recipientUniqueId == avatar.GetUniqueId()` в `EVENT_CHAT_MESSAGE_WITH_OBJECTS`. Проверять только в игре.
2. **`>>` (следование)** упирается в `avatar.SelectTarget`, а он для аддонов работает только по клику. Из события чата, скорее всего, не сработает. Нужна кнопка или тост с подтверждением, либо следовать только за тем, кто уже в цели.
3. **Принятие обмена (8).** `interaction.AcceptInviteToExchange` удалена из публичного API в 4.0.03 вместе со всем управлением торговлей. Может не существовать; проверка — `type(...)`. Кто приглашает, тоже не задокументировано (`EVENT_ITEMS_EXCHANGE_INVITED` без полей).
4. **Активности (7).** Ответ на очередь инстанс-ивентов `matchMaking.InstancedEventTeleportReply` — «закрытая ссылка», удалена из документации в 16.0.00. Реально доступны `lfgLib.VoteYes`, `avatar.TeleportOfferReply`, `questionLib.SendData`. Что именно приходит при приглашении в Астрал, Безвременье и на Арену героев, станет ясно только в игре или из разбора PartyManager.
5. **AirMoto и «взять на руки» (9, 10).** Отдельных событий нет: `EVENT_TAKE_ON_HANDS_REQUEST` и `family.TakeOnHandsResponse` удалены в 15.0.03. Гипотеза — questionLib с параметром `caster`. Проверить зондом.
6. **Окно-вопрос клиента** после `group.Accept()` или `raid.Accept()` может остаться на экране (судя по настройке PartyManager «Прятать последнее диалоговое окно»). Закрыть оригинальный интерфейс аддон не может.
7. **Локализация.** Системные тексты отказов («отказывается вступить», «занят и не может вступить»), к которым RPL прибегает как к запасному пути, есть только на русском клиенте. Имена ивентов из `matchMaking.GetEventInfo().name` и LFG-направлений локализованы: различать активности лучше по `mechanicsType`, `resourceId`, `category`, а не по тексту.
8. **События могут не дойти:** `EVENT_GROUP_DECLINE` и `*_BUSY` (опыт RPL); `EVENT_CHAT_MESSAGE` на турнирах (документация). Об истечении исходящего приглашения события нет — нужен свой таймаут около 30 с.
9. **Альты.** Сообщение от друга или согильдейца, который сидит на альте, придёт с другим ником: фильтр по нику его не узнает. Для друзей помогает `altName`; для гильдии — только `unit.GetGuildInfo(senderId)`, если отправитель рядом.
10. **Межсерверные активности.** Ники могут совпадать: везде, где возможно, используем `senderUniqueId`. `p.shard` позволяет отличить «чужой сервер». Приглашает ли `InviteByName` игрока с другого сервера, неизвестно.
11. **`raid.CanInvite()` без аргумента** в игре давал ошибку (RPL), хотя документация и форум 15.1 говорят, что аргумент необязателен. Права проверяем сами: лидер или помощник.
12. **Изменения API из ChangeList, затрагивающие нас:** 4.0.01 — удалены `EVENT_GUILD_MEMBER_ONLINE/OFFLINE` (теперь `EVENT_GUILD_MEMBER_ONLINE_STATUS_CHANGED`); 4.0.03 — торговля; 5.0.01 — удалены `EVENT_ITEMS_EXCHANGE_CANCELED/COMPLETED` (теперь `..._FINISHED { state }`) и `raid.GetLeaderHelperName`; 6.0.01 — удалены `raid.GetLeaderName`, `GetLeaderHelperNames`, `group.GetMemberInfoByPersistentId` (всё теперь через UniqueId); 7.0.00 — изменён `group.SetLeader( uniqueId )`; 6.0.02 — изменены `EVENT_GROUP_INVITE` и `EVENT_RAID_INVITE`; 15.0.02 — удалён `raid.IsPlayerInAvatarsRaidById` (теперь `IsPlayerInAvatarsRaid( uniqueId )`); 15.0.03 — удалены `group.GetLeaderUniqueId`, `GetMemberInfoById`, `GetMemberIndexByName` и take-on-hands; 16.0.00 — удалены `group.GetLeaderIndex` и `matchMaking.InstancedEventTeleportReply`; 15.1 (форум) — `raid.GetMembers` индексируется с 1; «Будущий патч» — изменены `EVENT_GUILD_MEMBER_*` (`playerId`), добавлены `common.DelayedCall`, `object.IsPlayer`, удалён `userMods.SendEvent`.
13. **Антиспам и безопасность.** Любой «рандом» может прислать `!!` и забрать лидерство. По умолчанию фильтр «друзья + гильдия»; кулдауны на команды (у PartyManager они настраиваются отдельно по каждой команде); `!!` только если отправитель уже в нашем формировании. Проверять `spamWeight < 100`.
14. **Права на операции из обработчика события.** Документация ограничивает «только по клику» `SelectTarget`, `guild.Invite` и `guild.InviteByName`, `RunUsableDeviceAction` и некоторые другие. Для `group.Accept`, `InviteByName`, `SetLeader`, `StartReadyCheck`, `ResurrectReply`, `InviteToExchange` таких оговорок нет. RPL зовёт `InviteByName` и `SetLeader` из таймера и по клику — работает.

---

## Готовые фрагменты кода

Стиль RPL: Windows-1251, `Global`, `Guard` / pcall, хелперы `S` и `WS`. Все имена событий и функций взяты из документации; то, что надо проверить, помечено `-- ПРОВЕРИТЬ`.

```lua
Global( "BAA", {} )
BAA.tick = 0

local function S( v )
	if v == nil then return "" end
	if type( v ) == "string" then return v end
	local ok, r = pcall( userMods.FromWString, v )
	return ( ok and type( r ) == "string" ) and r or tostring( v )
end
local function WS( s ) return userMods.ToWString( s or "" ) end
local function Trim( s ) return ( string.gsub( s or "", "^%s*(.-)%s*$", "%1" ) ) end
local function Chat( t, lvl ) pcall( userMods.SendSelfChatMessage, WS( "[BAA] " .. tostring( t ) ), lvl or "message" ) end

local function Guard( name, fn )
	return function( p )
		local ok, err = pcall( fn, p )
		if not ok then Chat( name .. ": " .. tostring( err ), "error" ) end
	end
end

local function MyName() return avatar.IsExist() and S( object.GetName( avatar.GetId() ) ) or "" end
```

### Фильтр «друзья / гильдия» с кэшем

```lua
local friends = {}   -- [ник] = true (и ники альтов)

local function RebuildFriends()
	friends = {}
	if not social.IsFriendListLoaded() then return end
	local list = social.GetFriendList() or {}
	for i = 0, GetTableSize( list ) - 1 do
		local info = social.GetFriendInfo( list[ i ] )
		if info then
			friends[ S( info.name ) ] = true
			local alt = S( info.altName )
			if alt ~= "" then friends[ alt ] = true end
		end
	end
end

local function IsGuildmate( name, unitId )
	if not guild.IsExist() then return false end
	if guild.GetMember( WS( name ) ) then return true end        -- онлайн и офлайн, по нику
	if unitId and object.IsExist( unitId ) then                   -- альт / рядом: по guildId
		local a, b = unit.GetGuildInfo( avatar.GetId() ), unit.GetGuildInfo( unitId )
		return a and b and a.guildId ~= nil and a.guildId == b.guildId or false
	end
	return false
end

-- cfg.react = { all = false, friends = true, guild = true }
function BAA.Allowed( name, unitId )
	if name == "" or name == MyName() then return false end
	if social.IsIgnored( WS( name ) ) then return false end
	if BAA.cfg.react.all then return true end
	if BAA.cfg.react.friends and friends[ name ] then return true end
	if BAA.cfg.react.guild and IsGuildmate( name, unitId ) then return true end
	return false
end
```

### Команды по личным сообщениям

```lua
local COOLDOWN = { ["++"] = 5, ["!!"] = 5, ["??"] = 15, ["##"] = 5, [">>"] = 3 }
local last = {}  -- [команда .. ник] = tick

local function IsWhisper( p )
	if CHAT_TYPE_WHISPER ~= nil then return p.chatType == CHAT_TYPE_WHISPER end  -- ПРОВЕРИТЬ, что константа есть
	return BAA.cfg.whisperType ~= nil and p.chatType == BAA.cfg.whisperType      -- калибровка (см. зонд)
end

local function Kind()
	if raid.IsExist() then return "raid" end
	if group.IsExist() then return "party" end
	return "none"
end

local function IAmRaidManager()
	if raid.IsLeader() then return true end
	local helpers = raid.GetLeaderHelpers() or {}
	local me = avatar.GetUniqueId()
	for _, uid in pairs( helpers ) do if uid == me then return true end end
	return false
end

local function SenderUid( p, name )
	if p.senderUniqueId then return p.senderUniqueId end
	local k = Kind()
	local info = ( k == "raid" and raid.GetMemberInfo( WS( name ) ) ) or ( k == "party" and group.GetMemberInfo( WS( name ) ) ) or nil
	return info and info.uniqueId
end

local CMD = {}
CMD["++"] = function( p, name )
	local k = Kind()
	if k == "raid" then
		if IAmRaidManager() then raid.InviteByName( WS( name ) ) else Chat( "Нужны права лидера или помощника", "warning" ) end
	elseif k == "party" then
		if group.IsLeader() then group.InviteByName( WS( name ) ) else Chat( "Приглашать может только лидер", "warning" ) end
	else
		group.InviteByName( WS( name ) )  -- вне группы: создаём группу, мы лидер
	end
	BAA.pendingInvite = { name = name, t = BAA.tick }  -- для FULL_GROUP -> raid.Create()
end
CMD["!!"] = function( p, name )
	local uid, k = SenderUid( p, name ), Kind()
	if not uid then return end
	if k == "raid" and raid.IsLeader() then raid.ChangeLeader( uid )
	elseif k == "party" and group.IsLeader() then group.SetLeader( uid ) end
end
CMD["??"] = function( p, name )
	local k = Kind()
	local info = ( k == "raid" and raid.GetReadyCheckInfo() ) or ( k == "party" and group.GetReadyCheckInfo() ) or nil
	if info and info.isInProgress then return end
	if k == "raid" and IAmRaidManager() then raid.StartReadyCheck()
	elseif k == "party" and group.IsLeader() then group.StartReadyCheck() end
end
CMD["##"] = function( p, name )
	if not interaction.HasExchange() then interaction.InviteToExchange( WS( name ) ) end
end
CMD[">>"] = function( p, name )
	local id = p.senderId or BAA.FindUnit( name )
	if not id then Chat( name .. " не рядом", "warning" ) return end
	if avatar.GetTarget() ~= id then pcall( avatar.SelectTarget, id ) end   -- для аддонов работает только по клику
	if avatar.GetTarget() == id then avatar.SetFollowTarget( true )
	else BAA.OfferFollowButton( id, name ) end                              -- кнопка: в реакции SelectTarget + SetFollowTarget
end

function BAA.FindUnit( name )
	for _, id in ipairs( avatar.GetUnitList() or {} ) do
		if unit.IsPlayer( id ) and S( object.GetName( id ) ) == name then return id end
	end
end

local function OnChatMessage( p )
	if p.isEcho or not IsWhisper( p ) then return end
	if ( p.spamWeight or 0 ) >= 100 then return end
	local name, text = S( p.sender ), Trim( S( p.msg ) )
	local fn = CMD[ text ]
	if not fn or not BAA.Allowed( name, p.senderId ) then return end
	local key = text .. name
	if last[ key ] and BAA.tick - last[ key ] < ( COOLDOWN[ text ] or 3 ) then return end
	last[ key ] = BAA.tick
	fn( p, name )
end

-- группа полная: превращаем в отряд и приглашаем повторно (как в RPL)
local function OnGroupInviteFailed( p )
	if p.sysReason == "ENUM_GROUP_INVITE_FAILED_FULL_GROUP" and group.IsLeader() and BAA.pendingInvite then
		raid.Create()                          -- или raid.CreateSmall()
		BAA.reinviteAfterConvert = BAA.pendingInvite.name
	end
end
local function OnConverted()
	if BAA.reinviteAfterConvert and raid.IsExist() then
		raid.InviteByName( WS( BAA.reinviteAfterConvert ) )
		BAA.reinviteAfterConvert = nil
	end
end
```

### Автопринятие

```lua
local function OnGroupInvite( p )
	if BAA.cfg.autoInvite and BAA.Allowed( S( p.inviterName ) ) and group.GetInviteInfo().invited then group.Accept() end
end
local function OnRaidInvite( p )
	if BAA.cfg.autoInvite and BAA.Allowed( S( p.inviterName ) ) and raid.GetInviteInfo().invited then raid.Accept() end
end
local function OnResurrect( p )   -- { resurrecterName, unitId, timeOutMs }
	if not BAA.cfg.autoRes or object.IsInCombat( avatar.GetId() ) then return end
	if BAA.Allowed( S( p.resurrecterName ), p.unitId ) then avatar.ResurrectReply( true ) end
end
local function OnTeleportOffer( p ) -- { requesterId, timeoutMs }
	local name = p.requesterId and S( object.GetName( p.requesterId ) ) or ""
	if BAA.cfg.autoTeleport and BAA.Allowed( name, p.requesterId ) then avatar.TeleportOfferReply( true ) end
end
local function OnLfgVote( p )      -- { initiator, type, destination, endTimeMs, roles }
	if BAA.cfg.autoLfg and BAA.Allowed( S( p.initiator ) ) then lfgLib.VoteYes( lfgLib.GetRoles() ) end  -- ПРОВЕРИТЬ, какие роли передавать
end
local function OnMatchTeleport( p ) -- { eventId, timeoutMs, isDelayedInvite }: инициатора нет
	if BAA.cfg.autoQueue and type( matchMaking.InstancedEventTeleportReply ) == "function" then  -- ПРОВЕРИТЬ: функция закрыта
		matchMaking.InstancedEventTeleportReply( true )
	end
end
local function OnExchangeInvited()
	local inv = interaction.GetExchangeInviter()                -- ПРОВЕРИТЬ: есть ли на этапе приглашения
	local name = inv and inv.playerId and S( object.GetName( inv.playerId ) ) or ""
	if not ( BAA.cfg.autoTrade and BAA.Allowed( name, inv and inv.playerId ) ) then return end
	if type( interaction.AcceptInviteToExchange ) == "function" then   -- ПРОВЕРИТЬ: удалена из документации в 4.0.03
		interaction.AcceptInviteToExchange( WS( name ) )
	end
end
```

### Зонд questionLib, AirMoto и «на руки» (сначала только печатает)

```lua
local function Dump( t, pfx, depth )
	depth = depth or 0
	if type( t ) ~= "table" or depth > 3 then return end
	for k, v in pairs( t ) do
		Chat( ( pfx or "" ) .. tostring( k ) .. " = " .. ( type( v ) == "table" and "{...}" or S( v ) ), "notice" )
		if type( v ) == "table" then Dump( v, ( pfx or "" ) .. "  ", depth + 1 ) end
	end
end

local function OnQuestionAdded( p )
	local info = questionLib.GetInfo( p.id )
	if not info then return end
	Chat( "question type=" .. tostring( info.type ), "notice" )
	Dump( info.questionData, "  q." ); Dump( info.clientData, "  c." )
	-- после проверки: найти в clientData параметр name == "caster" (objectId / text),
	-- проверить фильтр и ответить «да»:
	-- questionLib.SendData( p.id, { choice = 1 } )
end
```

### Калибровка типа личного сообщения

```lua
-- /baa calib: следующая входящая личка (не эхо) от игрока сохраняет chatType
local function OnChatProbe( p )
	if not BAA.calib or p.isEcho or not p.senderUniqueId then return end
	BAA.cfg.whisperType = p.chatType
	BAA.calib = nil
	Chat( "тип лички = " .. tostring( p.chatType ) .. ", CHAT_TYPE_WHISPER = " .. tostring( CHAT_TYPE_WHISPER ), "notice" )
	-- сохранить: userMods.SetGlobalConfigSection( common.GetAddonName(), BAA.cfg )
end
```

### Запуск

```lua
local function Start()
	if BAA.started then return end
	BAA.started = true
	local ok, g = pcall( userMods.GetGlobalConfigSection, common.GetAddonName() )
	BAA.cfg = ( ok and type( g ) == "table" ) and g or {}
	BAA.cfg.react = BAA.cfg.react or { all = false, friends = true, guild = true }
	local function On( fn, ev ) common.RegisterEventHandler( Guard( ev, fn ), ev ) end
	On( function() BAA.tick = BAA.tick + 1 end, "EVENT_SECOND_TIMER" )
	On( OnChatMessage, "EVENT_CHAT_MESSAGE" )
	On( OnGroupInviteFailed, "EVENT_GROUP_INVITE_FAILED" )
	On( OnConverted, "EVENT_GROUP_CONVERTED" ); On( OnConverted, "EVENT_RAID_APPEARED" )
	On( OnGroupInvite, "EVENT_GROUP_INVITE" ); On( OnRaidInvite, "EVENT_RAID_INVITE" )
	On( OnResurrect, "EVENT_RESURRECT_REQUESTED" )
	On( OnTeleportOffer, "EVENT_TELEPORT_OFFER_REQUEST" )
	On( OnLfgVote, "EVENT_LFG_VOTE" )
	On( OnMatchTeleport, "EVENT_MATCH_MAKING_EVENT_TELEPORT_REQUEST" )
	On( OnExchangeInvited, "EVENT_ITEMS_EXCHANGE_INVITED" )
	On( OnQuestionAdded, "EVENT_QUESTION_ADDED" )
	On( RebuildFriends, "EVENT_AVATAR_FRIEND_LIST_LOADED" ); On( RebuildFriends, "EVENT_AVATAR_FRIEND_LIST_CHANGED" )
	-- событие удалено из документации в 15.0.03: регистрируем через pcall
	pcall( common.RegisterEventHandler, Guard( "take", function( p ) Dump( p, "hands." ) end ), "EVENT_TAKE_ON_HANDS_REQUEST" )
	RebuildFriends()
end
common.RegisterEventHandler( Guard( "start", Start ), "EVENT_AVATAR_CREATED" )
if avatar.IsExist() then Guard( "start", Start )() end
```
