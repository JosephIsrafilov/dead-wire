class_name BookshelfInspect
extends Node3D

## The shelf of division volumes by the east wall.
##
## Same contract as every other inspectable surface: it hands the office a block
## of authored text and never reads game state. Nothing here knows what happened
## tonight.

signal inspected(text: String)

@export var prompt_message: String = "Осмотреть книжный шкаф"

const SHELF_TEXT_EN: String = """BLACK CREEK STATION — DIVISION VOLUMES
────────────────────────────────────────
GENERAL ORDER 12 (bound, 1884):
    Every operator will acknowledge receipt of each order. An order
    acknowledged is an order executed.

TARIFF SCHEDULE, EAST DIVISION:
    Message, ten words or under ............... 25c
    Each additional word ....................... 2c
    Night service, eleven to six .............. free

NOTICE — QUARANTINE, JUNE 1885:
    Water supply and mine junction cars remain restricted pending
    inspection. This notice has not been withdrawn.

NEWSPAPER CUTTING, OCTOBER 1885:
    ... THE MINE WILL NOT REOPEN. THE COMPANY THANKS THE TOWN FOR
    ITS PATIENCE AND ITS SONS ...

────────────────────────────────────────
STATION ORDER BOOK — MARGIN ENTRY (1885):
OCT 14, 1885 — 11:42 PM
Night watch closed unsigned by Sr. Operator J. Cole.
Register strip missing from reel. Relief entered by Asst. E. Crane.

────────────────────────────────────────
FOLDED PRESCRIPTION SLIP (inside the front cover):
Dr. Arthur Crane, County Physician — Black Creek
Margin note (A.C.): "Keep the hand steady, Elias. Never lie to the record."
"""

const SHELF_TEXT_RU: String = """ОБЩИЙ ПРИКАЗ № 12 (подшивка, 1884):
    Каждый телеграфист обязан подтвердить приём приказа.
    Принятый приказ считается исполненным.

ТАРИФ ВОСТОЧНОГО УЧАСТКА:
    Телеграмма до десяти слов ............... 25 центов
    Каждое следующее слово ................... 2 цента
    Ночная служба (23:00–06:00) .............. без оплаты

ОБЪЯВЛЕНИЕ — КАРАНТИН, ИЮНЬ 1885:
    Водоснабжение и вагоны рудничной ветки ограничены
    до окончания проверки. Запрет не снят.

ГАЗЕТНАЯ ВЫРЕЗКА, ОКТЯБРЬ 1885:
    ... ШАХТА НЕ ВОЗОБНОВИТ РАБОТУ. КОМПАНИЯ БЛАГОДАРИТ ГОРОД
    ЗА ТЕРПЕНИЕ И ЗА ЕГО СЫНОВЕЙ ...

────────────────────────────────
ЖУРНАЛ ДЕЖУРСТВ — ПОМЕТКА НА ПОЛЯХ (1885):
14 ОКТ. 1885 — 23:42
Ночная смена закрыта без подписи ст. телеграфиста Дж. Коула.
Лента регистра с катушки пропала. Смену принял пом. Э. Крейн.

────────────────────────────────
СЛОЖЕННЫЙ РЕЦЕПТ (вложен под обложку):
Д-р Артур Крейн, окружной врач — Блэк-Крик
Заметка на полях (А.К.): «Держи руку твёрдо, Элиас. Никогда не ври записи.»
"""

var interactable: Interactable = null

func _ready() -> void:
	interactable = get_node_or_null("Interactable") as Interactable
	refresh_locale()
	if interactable != null and not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)

func refresh_locale() -> void:
	if interactable != null:
		interactable.prompt_text = GameLocale.pick("Осмотреть книжный шкаф", "Inspect Bookshelf")

func get_interactable() -> Interactable:
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null and not interactable.interacted.is_connected(_on_interacted):
		interactable.interacted.connect(_on_interacted)
	return interactable

func get_shelf_text() -> String:
	return GameLocale.pick(SHELF_TEXT_RU, SHELF_TEXT_EN)

func _on_interacted() -> void:
	inspected.emit(get_shelf_text())
