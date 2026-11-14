BestAutoAccept — исходники сборки
=================================
lua/       скрипты аддона в UTF-8 (при сборке переводятся в Windows-1251)
gen/       генератор ресурсов: build.py (виджеты, тексты, текстуры DXT5), assemble.py (папка аддона целиком)
test/      заглушки API и прогон логики: texlua test/run.lua
tools/     dxtdec.py (просмотр текстур), render.py (грубый предпросмотр окна)
research/  разбор PartyManager и API игры

Сборка (Python 3 + numpy + Pillow + rsvg-convert):
  python3 gen/assemble.py [папка]   -> по умолчанию out/BestAutoAccept
  Сборка .pak и установка в игру — python tools/build.py BestAutoAccept из C:\Development\Allods (см. README.md там)
