"""Сборка ресурсов BestAutoAccept: виджеты, тексты, текстуры.

Размеры в макете — в «пикселях макета»; в игре всё умножается на S (как в RPL, 1.2).
"""
import os, sys, shutil
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import tex as T
import xdb as X
from xdb import placement as PL, fmt

S = 1.2


def P(v):
    return int(round(v * S))


_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(_ROOT, 'out', 'BestAutoAccept')
PREV = sys.argv[2] if len(sys.argv) > 2 else os.path.join(_ROOT, 'out', 'preview')
for d in ('Widgets', 'Texts'):
    shutil.rmtree(os.path.join(OUT, d), ignore_errors=True)
shutil.rmtree(PREV, ignore_errors=True)
X.setup(OUT, PREV)

# ------------------------------------------------------------------ палитра
ACC = '#BB1ABD'; ACC_B = '#D045D2'; ACC_I = '#E58BE7'; ACC_T = '#F2B8F3'
SEG_ON = '#3A1440'; CHIP_BG = '#2C1230'; CHIP_BR = '#6A2A6E'
BG_WIN = '#17141B'; BG_HDR = '#1D1922'; BG_HOVER = '#1F1A24'; BG_OFF = '#221D27'; BG_IN = '#100E13'
BR_WIN = '#3A2F42'; BR_CTL = '#3A3141'; LINE = '#2A2330'
GOLD = '#D9BE7A'; TXT = '#ECE6EF'; TXT2 = '#BDB4C4'; TXT_OFF = '#8C8393'; TXT_DIS = '#5E5664'
AMBER = '#F5B841'; AMBER_BG = '#2E2410'; AMBER_BR = '#6A5420'
TIP_BG = '#0F0D12'; TIP_BR = '#4A3B52'

F_TITLE = ('AllodsFantasy', 18)
F_SECT = ('AllodsFantasy', 16)
F_BODY = ('AllodsSystem', 16)
F_SMALL = ('AllodsSystem', 14)
F_BTN = ('AllodsSystem', 16)
F_CODE = ('ContentNarrowBold', 16)

# ------------------------------------------------------------------ текстуры


def box(w, h, r, fill=None, border=None, bw=1.2):
    img = T.blank(w, h)
    return T.rrect(img, 0, 0, w, h, r, fill=fill, border=border, bw=bw)


def fr(name, fill, border=None, size=64, r=7, e=None, bw=1.2):
    return X.frame(name, box(size, size, r, fill, border, bw), e or (r + 3))


def solid(name, color, alpha=1.0):
    img = T.blank(4, 4)
    img[...] = T.hex2rgba(color, alpha)
    return X.stretch(name, img)


TRANSP = X.stretch('Transparent', T.blank(4, 4))
LINE_TEX = solid('Line', LINE)
CURSOR = solid('Cursor', ACC_I)
SELECTION = solid('Selection', ACC, 0.45)

WIN_FRAME = fr('WindowFrame', BG_WIN, BR_WIN, 128, 12, 16)
HDR_IMG = T.rrect(T.blank(64, 64), 1.2, 1.2, 62.8, 64, (11, 11, 0, 0), fill=BG_HDR)
HDR_FRAME = X.frame('HeaderBack', HDR_IMG, 14)
HDR_LINE = LINE_TEX
ACCENT_MARK = X.stretch('AccentMark', box(16, 16, 4, ACC))
TIP_FRAME = fr('TipFrame', TIP_BG, TIP_BR, 64, 7)
TIP_WARN = fr('TipWarn', TIP_BG, AMBER, 64, 7)
TOAST_FRAME = fr('ToastFrame', BG_WIN, BR_WIN, 64, 10)
CHIP_ON = fr('ChipOn', CHIP_BG, ACC, 32, 5, 7)
CHIP_ICON = fr('ChipIcon', CHIP_BG, CHIP_BR, 32, 5, 7)
STATUS_ACTIVE = fr('StatusActive', CHIP_BG, CHIP_BR, 32, 11, 12)
STATUS_PAUSE = fr('StatusPause', AMBER_BG, AMBER_BR, 32, 11, 12)
FIELD = fr('FieldFrame', BG_IN, BR_CTL, 32, 6, 9)
FIELD_ERR = fr('FieldFrameErr', BG_IN, AMBER, 32, 6, 9)
FIELD_FOCUS = fr('FieldFrameFocus', BG_IN, ACC_I, 32, 6, 9)
LIST_FRAME = fr('ListFrame', BG_IN, LINE, 64, 7)

# сегменты «На кого реагируем»
SEG = {
    'off': fr('SegOff', BG_OFF, BR_CTL), 'offH': fr('SegOffHover', '#2A2430', '#4A3F52'),
    'on': fr('SegOn', SEG_ON, ACC), 'onH': fr('SegOnHover', '#46184D', ACC_B),
    'blk': fr('SegBlocked', SEG_ON, AMBER),
    'dis': fr('SegDisabled', '#19161C', '#2A2430'),
}
# кнопки шапки и мелкие кнопки-иконки
HB = {
    'n': TRANSP, 'h': fr('IconBtnHover', BG_HOVER, '#3A3141', 32, 6, 9),
    'act': fr('IconBtnActive', CHIP_BG, CHIP_BR, 32, 6, 9), 'actH': fr('IconBtnActiveHover', '#38163D', ACC, 32, 6, 9),
    'pau': fr('IconBtnPause', AMBER_BG, AMBER_BR, 32, 6, 9), 'pauH': fr('IconBtnPauseHover', '#3A2E14', AMBER, 32, 6, 9),
}
ADD = {'n': fr('AddNormal', ACC, ACC_B), 'h': fr('AddHover', '#CC3ACE', '#E070E2'), 'p': fr('AddPressed', '#9E169F', ACC_B)}
FOLLOW = ADD


def switch_tex(name, on, hover=False):
    W, H = 64, 32
    img = T.blank(W, H)
    if on:
        T.rrect(img, 0, 0, W, H, 16, fill='#CC3ACE' if hover else ACC, border=ACC_B, bw=1.8)
        knob = '#FFFFFF'; kx = W - 4 - 22
    else:
        T.rrect(img, 0, 0, W, H, 16, fill='#2C2632' if hover else '#241F28', border='#5A4A62' if hover else TIP_BR, bw=1.8)
        knob = TXT_OFF; kx = 4
    T.rrect(img, kx + 1, 5, kx + 23, 27, 11, fill=knob)
    return X.stretch(name, img)


SW = {'off': switch_tex('SwitchOff', False), 'offH': switch_tex('SwitchOffHover', False, True),
      'on': switch_tex('SwitchOn', True), 'onH': switch_tex('SwitchOnHover', True, True)}


def main_btn(name, fill, border, bw=1.6):
    return X.stretch(name, box(64, 64, 13, fill, border, bw))


MAIN = {
    'on': main_btn('MainOn', ACC, '#D97ADB'), 'onH': main_btn('MainOnHover', '#CC3ACE', '#EFA0F0'),
    'part': main_btn('MainPart', CHIP_BG, ACC), 'partH': main_btn('MainPartHover', '#3A1640', ACC_B),
    'off': main_btn('MainOff', '#1E1A22', BR_CTL), 'offH': main_btn('MainOffHover', '#28222D', '#4A3F52'),
    'pause': main_btn('MainPause', AMBER_BG, AMBER), 'pauseH': main_btn('MainPauseHover', '#3A2E14', '#FFD27A'),
}
RING = X.stretch('MainRing', T.ring(T.blank(64, 64), 1, 1, 63, 63, 15, T.hex2rgba(ACC, 0.65), 2.4))
BAR_BACK = X.stretch('BarBack', box(32, 4, 2, BR_CTL))
BAR_FILL = X.stretch('BarFill', box(32, 4, 2, ACC))
THUMB = fr('ScrollThumb', TIP_BR, None, 16, 4, 5)
THUMB_H = fr('ScrollThumbHover', ACC, None, 16, 4, 5)

# ------------------------------------------------------------------ иконки
GEAR = ('M12.72 6.69 L14.52 7.01 L14.52 8.99 L12.72 9.31 L12.26 10.42 L13.32 11.91 L11.91 13.32 L10.42 12.26 L9.31 12.72 '
        'L8.99 14.52 L7.01 14.52 L6.69 12.72 L5.58 12.26 L4.09 13.32 L2.68 11.91 L3.74 10.42 L3.28 9.31 L1.48 8.99 L1.48 7.01 '
        'L3.28 6.69 L3.74 5.58 L2.68 4.09 L4.09 2.68 L5.58 3.74 L6.69 3.28 L7.01 1.48 L8.99 1.48 L9.31 3.28 L10.42 3.74 '
        'L11.91 2.68 L13.32 4.09 L12.26 5.58Z M10.2 8a2.2 2.2 0 1 1 -4.4 0a2.2 2.2 0 1 1 4.4 0')
ICON_PATHS = {
    'gear': ([GEAR], 1.3), 'pause': (['M5.5 3.5v9M10.5 3.5v9'], 1.8), 'play': (['M5 3l8 5-8 5z'], 1.7),
    'close': (['M4 4l8 8M12 4l-8 8'], 1.8), 'clock': (['M3 8a5 5 0 1 0 10 0a5 5 0 1 0 -10 0M8 5v3l2 1.5'], 1.6),
    'minus': (['M4 8h8'], 1.8), 'plus': (['M4 8h8M8 4v8'], 1.8),
    'check2': (['M1.5 8.5l3 3 6.5-6.5M8 11.5l6.5-6.5'], 1.9),
    'ban': (['M2.5 8a5.5 5.5 0 1 0 11 0a5.5 5.5 0 1 0 -11 0M4.2 11.8l7.6-7.6'], 1.5),
    'x': (['M4 4l8 8M12 4l-8 8'], 1.9),
    'group': (['M3.5 5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0M1.5 14c0-2.8 2-4.5 4.5-4.5s4.5 1.7 4.5 4.5M9.8 3.2a2 2 0 1 1 1.4 3.6M11.5 9.6c1.9.3 3 1.8 3 4.4'], 1.5),
    'activity': (['M3.5 15V2M3.5 2.5h9l-2 3 2 3h-9'], 1.5),
    'vehicle': (['M0.8 11.6a2.6 2.6 0 1 0 5.2 0a2.6 2.6 0 1 0 -5.2 0M10 11.6a2.6 2.6 0 1 0 5.2 0a2.6 2.6 0 1 0 -5.2 0M3.4 11.6L5.2 8.6M12.6 11.6L10.6 5.2h2'], 1.5,
                ['M4.6 8.9L6.4 6.6h2.2l0.8 1.2h1.6l0.9 1.6l-1.4 2.6h-3.4z']),
    'carry': (['M4.5 9V5a1 1 0 0 1 2 0v3.5M6.5 8V3.5a1 1 0 0 1 2 0V8M8.5 8V4.5a1 1 0 0 1 2 0V8.5M10.5 8.5V6a1 1 0 0 1 2 0v4c0 2.5-1.8 4.5-4.3 4.5H7.5c-1.5 0-2.4-.6-3.3-1.6L2 10.5a1 1 0 0 1 1.5-1.3L4.5 10'], 1.5),
    'res': (['M8 1v14M6 3.5h4M3.5 6.5h9M5.5 10.5l5 2'], 1.6),
    'ready': (['M2 8a6 6 0 1 0 12 0a6 6 0 1 0 -12 0M5.2 8.3l2 2 3.7-4.2'], 1.6),
}


def ic(kind, color, size=32):
    spec = ICON_PATHS[kind]
    img = T.svg_icon(spec[0], color, size, spec[1])
    if len(spec) > 2:
        T.paste(img, T.svg_icon(spec[2], color, size, 0, fill=True), 0, 0)
    return img


def icon_tex(name, kind, color, key=None, size=32):
    img = ic(kind, color, size)
    if key:
        return X.icon(key, name, img)
    return X.stretch(name, img)


ACC_KEYS = ['group', 'activity', 'vehicle', 'carry', 'res', 'ready']
for k in ACC_KEYS:
    icon_tex('Acc_%s_On' % k, k, ACC_I, 'ACC_%s_ON' % k.upper())
    icon_tex('Acc_%s_Off' % k, k, TXT_DIS, 'ACC_%s_OFF' % k.upper())
    icon_tex('Acc_%s_Toast' % k, k, ACC_T, 'ACC_%s_TOAST' % k.upper())
icon_tex('Gear', 'gear', TXT2, 'GEAR')
icon_tex('GearOn', 'gear', ACC_T, 'GEAR_ON')
icon_tex('Pause', 'pause', TXT2, 'PAUSE')
icon_tex('Play', 'play', AMBER, 'PLAY')
icon_tex('MainIconOn', 'check2', '#FFFFFF', 'MAIN_ON', 64)
icon_tex('MainIconPart', 'check2', ACC_T, 'MAIN_PART', 64)
icon_tex('MainIconOff', 'check2', '#6E6575', 'MAIN_OFF', 64)
icon_tex('MainIconPause', 'pause', AMBER, 'MAIN_PAUSE', 64)
CLOSE_IC = icon_tex('Close', 'close', TXT2)
CLOCK_IC = icon_tex('Clock', 'clock', TXT2)
MINUS_IC = icon_tex('Minus', 'minus', TXT2)
PLUS_IC = icon_tex('Plus', 'plus', TXT2)
BAN_IC = icon_tex('Ban', 'ban', TXT_OFF)
X_IC = icon_tex('Remove', 'x', TXT2)
X.write_icon_group()

# ------------------------------------------------------------------ форматы текста


def F(name, f, color, alignx='left', **kw):
    return fmt(name, f[0], f[1], color, alignx, **kw)


# ------------------------------------------------------------------ виджеты
W_, H_ = 360, 544           # окно (макет)
WW, WH = P(W_), P(H_)
HDR = 40


def tv(name, x, y, w, h, fref, **kw):
    return X.textview(name, PL(x, y, w, h), fref, **kw)


def icon_panel(name, x, y, s, tex_href, **kw):
    return X.panel(name, PL(x, y, s, s), back=tex_href, transparent=True, **kw)


# --- главная кнопка
X.panel('BAAIcon', PL(0, 0, 14, 14, 'WIDGET_ALIGN_CENTER', 'WIDGET_ALIGN_CENTER'), back='Textures/MainIconOn.Stretch.(WidgetLayerSimpleTexture).xdb', transparent=True)
main_vars = []
for k in ('on', 'part', 'off', 'pause'):
    main_vars.append({'normal': MAIN[k], 'hover': MAIN[k + 'H'], 'pressed': MAIN[k + 'H'], 'reaction': 'baa_main', 'rclick': 'baa_main_rc'})
X.button('BAAButton', PL(5, 5, 24, 24), main_vars, children=['BAAIcon.(WidgetPanel).xdb'])
X.panel('BAARing', PL(0, 0, 34, 34), back=RING, transparent=True, visible=False)
X.panel('BAABarFill', PL(0, 0, 16, 3), back=BAR_FILL, transparent=True)
X.panel('BAABar', PL(9, 24, 16, 3), back=BAR_BACK, children=['BAABarFill.(WidgetPanel).xdb'], transparent=True, visible=False)
X.panel('BAAHost', PL(440, 10, 34, 34), children=['BAARing.(WidgetPanel).xdb', 'BAAButton.(WidgetButton).xdb', 'BAABar.(WidgetPanel).xdb'],
        pick_children=True, priority=800)

# --- шапка окна
F('TitleText', F_TITLE, TXT, literal='BestAutoAccept')
F('StatusActiveText', F_SMALL, ACC_T, 'center', literal='Активен')
F('StatusPauseText', F_SMALL, AMBER, 'center', literal='Пауза')
X.panel('AccentMark', PL(P(12), P(15), 12, 12), back=ACCENT_MARK, transparent=True)
tv('TitleText', P(28), 0, 170, P(HDR), '../Texts/TitleText.txt')
X.textview('StatusActiveText', PL(0, 0, P(62), P(20)), '../Texts/StatusActiveText.txt')
X.textview('StatusPauseText', PL(0, 0, P(62), P(20)), '../Texts/StatusPauseText.txt')
X.panel('StatusActive', PL(0, 0, P(62), P(20)), back=STATUS_ACTIVE, children=['StatusActiveText.(WidgetTextView).xdb'], transparent=True)
X.panel('StatusPause', PL(0, 0, P(62), P(20)), back=STATUS_PAUSE, children=['StatusPauseText.(WidgetTextView).xdb'], transparent=True, visible=False)
X.panel('StatusChip', PL(P(190), P(10), P(62), P(20)), children=['StatusActive.(WidgetPanel).xdb', 'StatusPause.(WidgetPanel).xdb'],
        transparent=True, pointing='baa_tip')


def hdr_button(name, x, icon_href, reaction, variants=('n',)):
    vs = []
    for v in variants:
        if v == 'n':
            vs.append({'normal': HB['n'], 'hover': HB['h'], 'pressed': HB['h'], 'reaction': reaction})
        elif v == 'act':
            vs.append({'normal': HB['act'], 'hover': HB['actH'], 'pressed': HB['actH'], 'reaction': reaction})
        elif v == 'pau':
            vs.append({'normal': HB['pau'], 'hover': HB['pauH'], 'pressed': HB['pauH'], 'reaction': reaction})
    icon_panel(name + 'Icon', (P(28) - P(16)) // 2, (P(28) - P(16)) // 2, P(16), icon_href)
    return X.button(name, PL(P(x), P(6), P(28), P(28)), vs, children=[name + 'Icon.(WidgetPanel).xdb'], force_pointing='baa_tip')


hdr_button('HdrGear', 262, 'Textures/Gear.Stretch.(WidgetLayerSimpleTexture).xdb', 'baa_gear', ('n', 'act'))
hdr_button('HdrPause', 294, 'Textures/Pause.Stretch.(WidgetLayerSimpleTexture).xdb', 'baa_pause', ('n', 'pau'))
hdr_button('HdrClose', 326, CLOSE_IC, 'baa_close')
X.panel('Header', PL(0, 0, WW, P(HDR)), back=HDR_FRAME,
        children=['AccentMark.(WidgetPanel).xdb', 'TitleText.(WidgetTextView).xdb', 'StatusChip.(WidgetPanel).xdb',
                  'HdrGear.(WidgetButton).xdb', 'HdrPause.(WidgetButton).xdb', 'HdrClose.(WidgetButton).xdb'])
X.panel('HeaderLine', PL(1, P(HDR) - 1, WW - 2, 1), back=HDR_LINE, transparent=True)

# --- основная страница (координаты макета минус шапка)


def Y(v):
    return P(v - HDR)


F('SectTitle', F_SECT, GOLD)
tv('WhoTitle', P(12), Y(52), P(200), P(20), '../Texts/SectTitle.txt', transparent=False, pointing='baa_tip')

F('Seg.On', F_BTN, '#FFFFFF', 'center', tag='button_label')
F('Seg.Off', F_BTN, TXT2, 'center', tag='button_label')
F('Seg.Dis', F_BTN, TXT_DIS, 'center', tag='button_label')
seg_children = []
for i, (nm, label) in enumerate((('SegAll', 'Все'), ('SegFriends', 'Друзья'), ('SegGuild', 'Согильдейцы'))):
    t = X.text_file(nm, label)
    vs = [
        {'normal': SEG['off'], 'hover': SEG['offH'], 'pressed': SEG['offH'], 'disabled': SEG['dis'], 'text': t,
         'fmt': '../Texts/Seg.Off.txt', 'fmt_dis': '../Texts/Seg.Dis.txt', 'reaction': 'baa_seg'},
        {'normal': SEG['on'], 'hover': SEG['onH'], 'pressed': SEG['onH'], 'disabled': SEG['dis'], 'text': t,
         'fmt': '../Texts/Seg.On.txt', 'fmt_dis': '../Texts/Seg.Dis.txt', 'reaction': 'baa_seg'},
        {'normal': SEG['blk'], 'hover': SEG['blk'], 'pressed': SEG['blk'], 'disabled': SEG['dis'], 'text': t,
         'fmt': '../Texts/Seg.On.txt', 'fmt_dis': '../Texts/Seg.Dis.txt', 'reaction': 'baa_seg'},
    ]
    x = 12 + i * 114
    seg_children.append(X.button(nm, PL(P(x), Y(80), P(108), P(28)), vs, force_pointing='baa_tip'))

X.panel('Line1', PL(P(12), Y(121), P(336), 1), back=LINE_TEX, transparent=True)
X.panel('Line2', PL(P(12), Y(325), P(336), 1), back=LINE_TEX, transparent=True)
tv('CmdTitle', P(12), Y(134), P(200), P(20), '../Texts/SectTitle.txt', transparent=False, pointing='baa_tip')
X.panel('CdHead', PL(P(298), Y(136), P(16), P(16)), back=CLOCK_IC, pointing='baa_tip')
tv('AccTitle', P(12), Y(338), P(200), P(20), '../Texts/SectTitle.txt', transparent=False, pointing='baa_tip')

# строки команд (общие файлы детей, строки отличаются только Y)
RH = P(30)
F('CmdCode', F_CODE, ACC_T, 'center')
F('RowName', F_BODY, TXT)
F('CdUnit', F_SMALL, TXT_OFF, 'left')
F('CdEdit', F_BODY, TXT, 'left')
X.textview('CmdCode', PL(0, 0, P(34), P(20)), '../Texts/CmdCode.txt')
X.panel('CmdChip', PL(P(12), (RH - P(20)) // 2, P(34), P(20)), back=CHIP_ON, children=['CmdCode.(WidgetTextView).xdb'],
        pointing='baa_tip')
tv('CmdName', P(56), 0, P(154), RH, '../Texts/RowName.txt', transparent=False, pointing='baa_tip')
sw_vars = [
    {'normal': SW['off'], 'hover': SW['offH'], 'pressed': SW['offH'], 'reaction': 'baa_cmd_switch', 'push': 0},
    {'normal': SW['on'], 'hover': SW['onH'], 'pressed': SW['onH'], 'reaction': 'baa_cmd_switch', 'push': 0},
]
X.button('CmdSwitch', PL(P(220), (RH - 20) // 2, 40, 20), sw_vars)
BW = P(84); BH = P(24); SB = 26
icon_panel('CdMinusIcon', (SB - 12) // 2, (BH - 12) // 2, 12, MINUS_IC)
icon_panel('CdPlusIcon', (SB - 12) // 2, (BH - 12) // 2, 12, PLUS_IC)
step_v = lambda r: [{'normal': TRANSP, 'hover': HB['h'], 'pressed': HB['h'], 'reaction': r, 'push': 0}]
X.button('CdMinus', PL(0, 0, SB, BH), step_v('baa_cd_minus'), children=['CdMinusIcon.(WidgetPanel).xdb'])
X.button('CdPlus', PL(BW - SB, 0, SB, BH), step_v('baa_cd_plus'), children=['CdPlusIcon.(WidgetPanel).xdb'])
X.panel('CdSep1', PL(SB, 3, 1, BH - 6), back=LINE_TEX, transparent=True)
X.panel('CdSep2', PL(BW - SB - 1, 3, 1, BH - 6), back=LINE_TEX, transparent=True)
X.editline('CdEdit', PL(SB + 8, 0, 26, BH), '../Texts/CdEdit.txt', CURSOR, SELECTION, 2, 'baa_cd_enter', 'baa_cd_esc',
           focus='baa_cd_focus', filter_alias='INTEGER')
tv('CdUnit', SB + 38, 0, 12, BH, '../Texts/CdUnit.txt')
X.panel('CdFocus', PL(0, 0, BW, BH), back=FIELD_FOCUS, transparent=True, visible=False)
X.panel('CdBox', PL(P(264), (RH - BH) // 2, BW, BH), back=FIELD,
        children=['CdFocus.(WidgetPanel).xdb', 'CdMinus.(WidgetButton).xdb', 'CdSep1.(WidgetPanel).xdb', 'CdEdit.(WidgetEditLine).xdb',
                  'CdUnit.(WidgetTextView).xdb', 'CdSep2.(WidgetPanel).xdb', 'CdPlus.(WidgetButton).xdb'],
        wheel=('baa_cd_up', 'baa_cd_down'), pointing='baa_tip')
cmd_rows = []
for i in range(5):
    cmd_rows.append(X.panel('CmdRow%d' % (i + 1), PL(0, Y(162 + 30 * i), WW, RH),
                            children=['CmdChip.(WidgetPanel).xdb', 'CmdName.(WidgetTextView).xdb', 'CmdSwitch.(WidgetButton).xdb',
                                      'CdBox.(WidgetPanel).xdb'], pick_children=True))

# строки автопринятия
AH = P(28)
X.panel('AccIcon', PL(P(12), (AH - P(16)) // 2, P(16), P(16)), back='Textures/Acc_group_On.Stretch.(WidgetLayerSimpleTexture).xdb',
        pointing='baa_tip')
tv('AccName', P(38), 0, P(260), AH, '../Texts/RowName.txt', transparent=False, pointing='baa_tip')
acc_sw = [dict(v, reaction='baa_acc_switch') for v in sw_vars]
X.button('AccSwitch', PL(WW - P(12) - 40, (AH - 20) // 2, 40, 20), acc_sw)
# строка с задержкой ответа (проверка готовности): то же поле, что у команд, слева от переключателя
ACC_CD_X = WW - P(12) - 40 - P(10) - BW
tv('AccName', P(38), 0, ACC_CD_X - P(38) - P(6), AH, '../Texts/RowName.txt', transparent=False, pointing='baa_tip', fname='AccNameCd')
X.panel('CdBox', PL(ACC_CD_X, (AH - BH) // 2, BW, BH), back=FIELD,
        children=['CdFocus.(WidgetPanel).xdb', 'CdMinus.(WidgetButton).xdb', 'CdSep1.(WidgetPanel).xdb', 'CdEdit.(WidgetEditLine).xdb',
                  'CdUnit.(WidgetTextView).xdb', 'CdSep2.(WidgetPanel).xdb', 'CdPlus.(WidgetButton).xdb'],
        wheel=('baa_cd_up', 'baa_cd_down'), pointing='baa_tip', fname='AccCdBox')
ACC_WITH_CD = {5}
acc_rows = []
for i in range(len(ACC_KEYS)):
    kids = ['AccIcon.(WidgetPanel).xdb', 'AccName.(WidgetTextView).xdb', 'AccSwitch.(WidgetButton).xdb']
    if i in ACC_WITH_CD:
        kids = ['AccIcon.(WidgetPanel).xdb', 'AccNameCd.(WidgetTextView).xdb', 'AccCdBox.(WidgetPanel).xdb', 'AccSwitch.(WidgetButton).xdb']
    acc_rows.append(X.panel('AccRow%d' % (i + 1), PL(0, Y(366 + 28 * i), WW, AH), children=kids, pick_children=True))

X.panel('MainPage', PL(0, P(HDR), WW, WH - P(HDR)),
        children=['WhoTitle.(WidgetTextView).xdb'] + seg_children + ['Line1.(WidgetPanel).xdb', 'CmdTitle.(WidgetTextView).xdb',
                                                                      'CdHead.(WidgetPanel).xdb'] + cmd_rows +
        ['Line2.(WidgetPanel).xdb', 'AccTitle.(WidgetTextView).xdb'] + acc_rows, pick_children=True)

# --- страница настроек: чёрный список
F('BlCount', F_SMALL, TXT_OFF, 'right')
F('BlEdit', F_BODY, TXT)
F('BlHint', F_BODY, '#6E6575')
F('AddBtn', F_BTN, '#FFFFFF', 'center', tag='button_label')
F('BlEmpty', F_BODY, '#6E6575', 'center')
F('BlRowName', F_BODY, TXT)
tv('BlTitle', P(12), Y(52), P(200), P(20), '../Texts/SectTitle.txt', transparent=False, pointing='baa_tip')
tv('BlCount', P(160), Y(52), P(188), P(20), '../Texts/BlCount.txt')
IW, IH = P(232), P(30)
X.panel('BlInputErr', PL(0, 0, IW, IH), back=FIELD_ERR, transparent=True, visible=False)
X.editline('BlEdit', PL(P(10), 0, IW - P(20), IH), '../Texts/BlEdit.txt', CURSOR, SELECTION, 14, 'baa_bl_enter', 'baa_bl_esc',
           changed='baa_bl_changed')
tv('BlHint', P(10), 0, IW - P(20), IH, '../Texts/BlHint.txt')
X.panel('BlInput', PL(P(12), Y(80), IW, IH), back=FIELD,
        children=['BlInputErr.(WidgetPanel).xdb', 'BlHint.(WidgetTextView).xdb', 'BlEdit.(WidgetEditLine).xdb'])
add_t = X.text_file('BlAdd', '+ Добавить')
X.button('BlAdd', PL(P(252), Y(80), P(96), P(30)),
         [{'normal': ADD['n'], 'hover': ADD['h'], 'pressed': ADD['p'], 'text': add_t, 'fmt': '../Texts/AddBtn.txt', 'reaction': 'baa_bl_add'}])

LW, LH = P(336), P(372)       # ниже списка — строка «Показывать уведомления»
CW, CH = LW - 8, LH - 8
ROWW = CW - 14
X.button('BlScrollInc', PL(0, 0, 1, 1), [{'normal': TRANSP}])
X.button('BlScrollDec', PL(0, 0, 1, 1), [{'normal': TRANSP}])
X.button('BlThumb', PL(0, 0, 8, 48, 'WIDGET_ALIGN_CENTER'), [{'normal': THUMB, 'hover': THUMB_H, 'pressed': THUMB_H, 'push': 0}])
X.glide_slider('BlSlider', PL(0, 0, None, None, 'WIDGET_ALIGN_BOTH', 'WIDGET_ALIGN_BOTH'), 'BlThumb.(WidgetButton).xdb', P(28))
X.glide_scrollbar('BlScroll', PL(0, 0, 10, None, 'WIDGET_ALIGN_HIGH', 'WIDGET_ALIGN_BOTH', hx=0),
                  'BlScrollInc.(WidgetButton).xdb', 'BlScrollDec.(WidgetButton).xdb', 'BlSlider.(WidgetGlideSlider).xdb')
X.scroll_container('BlList', PL(4, 4, CW, CH), 'BlScroll.(WidgetGlideScrollBar).xdb')
tv('BlEmpty', 0, 0, LW, LH, '../Texts/BlEmpty.txt')
X.panel('BlBox', PL(P(12), Y(120), LW, LH), back=LIST_FRAME,
        children=['BlEmpty.(WidgetTextView).xdb', 'BlList.(WidgetScrollableContainer).xdb'])
# шаблон строки списка
BRH = P(28)
icon_panel('BlRowIcon', P(8), (BRH - P(14)) // 2, P(14), BAN_IC)
tv('BlRowName', P(30), 0, ROWW - P(30) - P(30), BRH, '../Texts/BlRowName.txt')
icon_panel('BlRemoveIcon', (P(24) - 13) // 2, (P(24) - 13) // 2, 13, X_IC)
X.button('BlRemove', PL(ROWW - P(28), (BRH - P(24)) // 2, P(24), P(24)),
         [{'normal': TRANSP, 'hover': HB['h'], 'pressed': HB['h'], 'reaction': 'baa_bl_remove', 'push': 0}],
         children=['BlRemoveIcon.(WidgetPanel).xdb'])
X.panel('BlRow', PL(0, 0, ROWW, BRH), children=['BlRowIcon.(WidgetPanel).xdb', 'BlRowName.(WidgetTextView).xdb', 'BlRemove.(WidgetButton).xdb'],
        pick_children=True, visible=False)

# уведомления: один переключатель под чёрным списком
X.panel('Line3', PL(P(12), Y(501), P(336), 1), back=LINE_TEX, transparent=True)
tv('NotifyName', P(12), 0, P(260), AH, '../Texts/RowName.txt', transparent=False, pointing='baa_tip')
X.button('NotifySwitch', PL(WW - P(12) - 40, (AH - 20) // 2, 40, 20), [dict(v, reaction='baa_notify_switch') for v in sw_vars])
X.panel('NotifyRow', PL(0, Y(506), WW, AH), children=['NotifyName.(WidgetTextView).xdb', 'NotifySwitch.(WidgetButton).xdb'],
        pick_children=True)

X.panel('SettingsPage', PL(0, P(HDR), WW, WH - P(HDR)),
        children=['BlTitle.(WidgetTextView).xdb', 'BlCount.(WidgetTextView).xdb', 'BlInput.(WidgetPanel).xdb', 'BlAdd.(WidgetButton).xdb',
                  'BlBox.(WidgetPanel).xdb', 'BlRow.(WidgetPanel).xdb', 'Line3.(WidgetPanel).xdb', 'NotifyRow.(WidgetPanel).xdb'],
        pick_children=True, visible=False)

# --- подсказка
F('TipText', F_SMALL, TXT, 'left', aligny='top')
X.panel('TipBack', PL(0, 0, None, None, 'WIDGET_ALIGN_BOTH', 'WIDGET_ALIGN_BOTH'), back=TIP_FRAME, transparent=True)
X.panel('TipBackWarn', PL(0, 0, None, None, 'WIDGET_ALIGN_BOTH', 'WIDGET_ALIGN_BOTH'), back=TIP_WARN, transparent=True, visible=False)
X.textview('TipText', PL(10, 7, None, None, 'WIDGET_ALIGN_BOTH', 'WIDGET_ALIGN_BOTH', hx=10, hy=5), '../Texts/TipText.txt', multiline=True)
X.panel('Tooltip', PL(0, 0, 300, 40), children=['TipBack.(WidgetPanel).xdb', 'TipBackWarn.(WidgetPanel).xdb', 'TipText.(WidgetTextView).xdb'],
        transparent=True, visible=False, priority=990)

X.panel('BAAWindow', PL(440, 80, WW, WH), back=WIN_FRAME,
        children=['Header.(WidgetPanel).xdb', 'HeaderLine.(WidgetPanel).xdb', 'MainPage.(WidgetPanel).xdb',
                  'SettingsPage.(WidgetPanel).xdb'], visible=False, priority=900)

# --- уведомления
TW, TH = P(380), P(36)
F('ToastText', F_BODY, '#DCD4E2')
X.textview('ToastCode', PL(0, 0, P(34), P(22)), '../Texts/CmdCode.txt')
X.panel('ToastChip', PL(P(6), (TH - P(22)) // 2, P(34), P(22)), back=CHIP_ON, children=['ToastCode.(WidgetTextView).xdb'], transparent=True)
X.panel('ToastIconImg', PL((P(34) - P(16)) // 2, (P(22) - P(16)) // 2, P(16), P(16)),
        back='Textures/Acc_group_Toast.Stretch.(WidgetLayerSimpleTexture).xdb', transparent=True)
X.panel('ToastIcon', PL(P(6), (TH - P(22)) // 2, P(34), P(22)), back=CHIP_ICON, children=['ToastIconImg.(WidgetPanel).xdb'],
        transparent=True, visible=False)
tv('ToastText', P(50), 0, TW - P(50) - P(12), TH, '../Texts/ToastText.txt')
toasts = []
for i in range(3):
    toasts.append(X.panel('Toast%d' % (i + 1), PL(0, P(120 + 42 * i), TW, TH, 'WIDGET_ALIGN_CENTER'), back=TOAST_FRAME,
                          children=['ToastChip.(WidgetPanel).xdb', 'ToastIcon.(WidgetPanel).xdb', 'ToastText.(WidgetTextView).xdb'],
                          transparent=True, visible=False, priority=950))
# предложение «Следовать за …» (SelectTarget работает только по клику)
fol_t = X.text_file('FollowButton', 'Следовать')
X.button('FollowButton', PL(TW - P(6) - P(96), (P(44) - P(30)) // 2, P(96), P(30)),
         [{'normal': ADD['n'], 'hover': ADD['h'], 'pressed': ADD['p'], 'text': fol_t, 'fmt': '../Texts/AddBtn.txt', 'reaction': 'baa_follow'}])
tv('FollowText', P(12), 0, TW - P(12) - P(96) - P(14), P(44), '../Texts/ToastText.txt')
X.panel('FollowPrompt', PL(0, P(120 + 42 * 3), TW, P(44), 'WIDGET_ALIGN_CENTER'), back=TOAST_FRAME,
        children=['FollowText.(WidgetTextView).xdb', 'FollowButton.(WidgetButton).xdb'], pick_children=True, visible=False, priority=951)

X.form('MainForm', ['BAAWindow.(WidgetPanel).xdb', 'BAAHost.(WidgetPanel).xdb'] + toasts +
       ['FollowPrompt.(WidgetPanel).xdb', 'Tooltip.(WidgetPanel).xdb'])

# --- описание аддона
X.text_file('AddonName', 'BestAutoAccept')
X.text_file('AddonDescription', 'Команды в личке (++ !! ?? ## >>) и автопринятие приглашений')
print('ok', len(os.listdir(X.WID)), 'widgets', len(os.listdir(X.TEXDIR)), 'texture files')
