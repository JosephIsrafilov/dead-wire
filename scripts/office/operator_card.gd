extends Node3D

const CARD := preload("res://data/operator_card.tres")

const BODY_RU := (
	"Осматривайтесь: A / W / D / S или стрелками у краёв экрана.\n\n"
	+ "Колёсико мыши или клик по лампе приглушают фитиль, чтобы убрать блик со стекла.\n\n"
	+ "Клик по телеграфному ключу открывает линию и принимает вызов. Пробел — передача.\n\n"
	+ "Сигнал поездам — слева [A]. Подшивка и штамп — справа [D]."
)

@onready var interactable: Interactable = $Interactable
@onready var heading: Label3D = get_node_or_null("Heading") as Label3D

func _ready() -> void:
	refresh_locale()
	interactable.interacted.connect(_on_interacted)

func refresh_locale() -> void:
	if interactable != null:
		interactable.prompt_text = GameLocale.pick("Памятка оператора", "Read Operator's Reminder")
	if heading != null:
		var ru_text := "ПАМЯТКА ПОСТА\n\n1. КЛЮЧ — ВЫЗОВ\n2. ПРОЧЕСТЬ ЛИСТ\n" \
			+ "3. ЖУРНАЛ И ЛЕНТА\n4. СИГНАЛ СЛЕВА [A]\n5. ПЕЧАТЬ СПРАВА [D]"
		var en_text := "STANDING ORDERS\n\n1. ANSWER ON KEY\n2. READ THE COPY\n" \
			+ "3. CHECK LEDGER / TAPE\n4. SIGNAL LEFT [A]\n5. FILE RIGHT [D]"
		heading.text = GameLocale.pick(ru_text, en_text)

func _on_interacted() -> void:
	var viewer := get_parent().get_node_or_null("DocumentViewer") as DocumentViewer
	if viewer != null:
		viewer.open_document(
			"operator_card",
			GameLocale.pick("ПАМЯТКА ОПЕРАТОРА", "OPERATOR'S REMINDER"),
			GameLocale.pick(BODY_RU, str(CARD.get_meta("body"))),
			GameLocale.pick("[E / Esc / ПКМ] Отложить", "[E / Esc] Put Down")
		)
