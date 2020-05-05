local module = {
	owner = "Boxofkrain#0000", -- Do NOT change this nickname
}

-->> Maps system <<--
local maps = {7686143, 7116265, 7115212, 7115134, 7686473}
local mapHashes = { }
local mapsToAdd = { }

local currentRound = 1

local shuffle = function(t)
	local len = #t
	for i = len, 1, -1 do
		local rand = math.random(i)
		t[i], t[rand] = t[rand], t[i]
	end
	return t
end

eventFileLoaded = function(id, data)
	local counter = 0
	maps, mapHashes = { }, { }
	for code in string.gmatch(data, "[^@]+") do
		counter = counter + 1

		code = tonumber(code) or code
		maps[counter] = code
		mapHashes[code] = true
	end
	maps = shuffle(maps)
end

eventFileLoaded(nil, "7686481@7686143@7686479@7116265@7115134@5965735@7519027@7521273@7615568@6692309@7520442@7520354@6690430@7687793@7686715@6515535@7115212@6268044@7615565@7687784@7115166@7686475@7686473@7519258@7687973@7688053@7688058@7691308@7686895@7687795@7691327@7693218@7108998@7110637@7120425@7687874@7687254@5577824@7714773@7690475@7690397@7690461")

local mapCode = function(x)
	if string.sub(x, 1, 1) == "@" then
		x = string.sub(x, 2)
	end

	local str = x
	x = tonumber(x)
	return x, not not x and #str > 3
end

-->> Maps system <<--

local translate
do
	local translations = {
		en = {
			greeting = "Hey! Nice to see you in funcorp-#sizerace! All the information you need is in Help tab.",
			help = "Help",
			guide = "Welcome to #sizerace! Change size of your mouse and win different maps with different difficulty level. You can change size of your mouse every 2 seconds. Be the fastest and have fun!\n\n<b>Use keys X, C, V, B, N to change your size</b>\n\n<a href='event:close'>Close</a>"
		},
		br = {
			greeting = "Oi! Bom te ver aqui no funcorp-#sizerace! Todas as informações que você precisa estão na aba Ajuda.",
			help = "Ajuda",
			guide = "Bem-vindo ao #sizerace! Mude o tamanho do seu rato e vença diferentes mapas com diferentes níveis de dificuldade. Você pode mudar o tamanho do seu rato a cada 2 segundos. Seja o mais rápido e divirta-se!\n\n<b>Use as teclas X, C, V, B, N para mudar seu tamanho</b>\n\n<a href='event:close'>Fechar</a>"
		},
		pl = {
			greeting = "Hejka! Miło Cię widzieć na funcorp-#sizerace! Wszystkie potrzebne informacje znajdziesz w zakładce Pomoc.",
			help = "Pomoc",
			guide = "Witaj w #sizerace! Zmieniaj rozmiar swojej myszki i przechodź najróżniejsze mapy z różnym poziomem trudności. Możesz zmieniać swój rozmiar co 2 sekundy, dlatego każdy błąd poskutkuje stratą cennego czasu. Bądź najszybszy i baw się dobrze!\n\n<b>Użyj klawiszy X, C, V, B, N aby zmieniać rozmiar!</b>\n\n<a href='event:close'>Zamknij</a>"
		}
	}

	translate = translations[tfm.get.room.community] or translations.en
end

local split = function(value, pattern, f)
	local out, c = {}, 0
	for v in string.gmatch(value, pattern) do
		c = c + 1
		out[c] = (not f and v or f(v))
	end
	return out
end

function getKeys(X, C, V, B, N)
	return {
		[88] = X,
		[67] = C,
		[86] = V,
		[66] = B,
		[78] = N
	}
end
local defaultKeys = getKeys(0.3, 0.6, 1, 2.1, 3.5)
local keys = defaultKeys

local lastMapUpdatedKeys = false
local gameTime = 90
local miceInfo = { }

function eventNewGame()
	local updatedKeys = false

	currentRound = currentRound + 1
	if currentRound > #maps then
		currentRound = 1
		maps = shuffle(maps)
	end

	for nick in next, tfm.get.room.playerList do
		tfm.exec.changePlayerSize(nick, 1)
	end

	local xml = tfm.get.room.xmlMapInfo
	if xml then
		xml = xml.xml

		local xmlSizes = string.match(xml, "size=\"(.-)\"")
		local xmlTime = string.match(xml, "time=\"(.-)\"")

		if (xmlSizes) then
			mapSizes = split(xmlSizes, "[^,]+")

			if (#mapSizes > 2) then
				table.sort(mapSizes)			

				keys = getKeys(mapSizes[1], mapSizes[2], mapSizes[3], mapSizes[4], mapSizes[5])
				updatedKeys = true
				lastMapUpdatedKeys = true
			end
		end
		if (xmlTime) then
			xmlTime = tonumber(xmlTime)
			if (xmlTime >= 60 and xmlTime <= 120) then
				gameTime = xmlTime
			end
		end
	end

	if not updatedKeys and lastMapUpdatedKeys then
		keys = defaultKeys
	end

	tfm.exec.setGameTime(gameTime)
end

function eventPlayerDied(nick)
	tfm.exec.changePlayerSize(nick, 1)
	tfm.exec.respawnPlayer(nick)
end

function eventKeyboard(nick, key)
	if (keys[key]) then
		local time = os.time()
		if (time > miceInfo[nick].lastTransform) then
			tfm.exec.changePlayerSize(nick, keys[key])
			miceInfo[nick].lastTransform = time + 2000
		end
	end
end

function eventTextAreaCallback(id, nick, call)
	if call=="help" then
		ui.addTextArea(1, "<p align='center'><font size='16'>#sizerace</font>\n\n" .. translate.guide, nick, 5, 50, 300, nil, 0x324650, 0x212F36, 0.5, true)
	elseif call=="close" then
		ui.removeTextArea(1, nick)
	end
end

function eventLoop(currentTime, remainingTime)
	if remainingTime <= 500 then
		tfm.exec.newGame(maps[currentRound])
	end
end

function eventNewPlayer(nick)
	for v in next, defaultKeys do
		system.bindKeyboard(nick, v, true, true)
	end

	miceInfo[nick] = {lastTransform = 0}

	ui.addTextArea(0, "<p align='center'><a href='event:help'>" .. translate.help, nick, 5, 28, 65, nil, 0x324650, 0x212F36, 0.5, true)
	tfm.exec.chatMessage("<font color='#92CF91'>" .. translate.greeting, nick)
end


for nick in next, tfm.get.room.playerList do
	eventNewPlayer(nick)
end

tfm.exec.disableAfkDeath()
tfm.exec.disableAutoNewGame()
tfm.exec.disableAutoShaman()
tfm.exec.disableAutoTimeLeft()
system.disableChatCommandDisplay()
tfm.exec.newGame(maps[currentRound])
