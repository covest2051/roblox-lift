--[[
	Questions — утверждения для «Правды или лжи»: свои формулировки, безопасные для детей.
	{ id, truth, ru, en }. Тест проверяет уникальность и что оба языка заполнены.
]]

local Questions = {}

Questions.List = {
	{ id = "q01", truth = true, ru = "У паука восемь ног", en = "A spider has eight legs" },
	{
		id = "q02",
		truth = false,
		ru = "Солнце вращается вокруг Земли",
		en = "The Sun goes around the Earth",
	},
	{
		id = "q03",
		truth = true,
		ru = "Вода кипит при 100 °C на уровне моря",
		en = "Water boils at 100 °C at sea level",
	},
	{
		id = "q04",
		truth = false,
		ru = "У пингвина есть колени снаружи, как у человека",
		en = "Penguins have knees outside, like people",
	},
	{
		id = "q05",
		truth = true,
		ru = "Киты — это млекопитающие",
		en = "Whales are mammals",
	},
	{
		id = "q06",
		truth = false,
		ru = "Помидор — это овощ по мнению ботаников",
		en = "Botanists call a tomato a vegetable",
	},
	{
		id = "q07",
		truth = true,
		ru = "Осьминог может менять цвет",
		en = "An octopus can change its colour",
	},
	{ id = "q08", truth = false, ru = "В неделе восемь дней", en = "A week has eight days" },
	{
		id = "q09",
		truth = true,
		ru = "Луна светит отражённым светом Солнца",
		en = "The Moon shines with reflected sunlight",
	},
	{
		id = "q10",
		truth = false,
		ru = "Летучие мыши — это птицы",
		en = "Bats are birds",
	},
	{
		id = "q11",
		truth = true,
		ru = "Снежинки обычно шестиугольные",
		en = "Snowflakes are usually six-sided",
	},
	{
		id = "q12",
		truth = false,
		ru = "Лёд тяжелее воды и тонет",
		en = "Ice is heavier than water and sinks",
	},
	{
		id = "q13",
		truth = true,
		ru = "Пчёлы делают мёд из нектара",
		en = "Bees make honey from nectar",
	},
	{
		id = "q14",
		truth = false,
		ru = "У улитки нет раковины",
		en = "A snail has no shell",
	},
	{
		id = "q15",
		truth = true,
		ru = "Радуга появляется, когда свет проходит через капли",
		en = "A rainbow appears when light passes through raindrops",
	},
	{
		id = "q16",
		truth = false,
		ru = "Жирафы спят по 20 часов в сутки",
		en = "Giraffes sleep 20 hours a day",
	},
	{
		id = "q17",
		truth = true,
		ru = "Сердце человека бьётся без перерыва всю жизнь",
		en = "A human heart beats non-stop all life long",
	},
	{
		id = "q18",
		truth = false,
		ru = "Морская звезда — это рыба",
		en = "A starfish is a fish",
	},
	{
		id = "q19",
		truth = true,
		ru = "Растения выделяют кислород",
		en = "Plants give off oxygen",
	},
	{
		id = "q20",
		truth = false,
		ru = "На Северном полюсе живут пингвины",
		en = "Penguins live at the North Pole",
	},
	{ id = "q21", truth = true, ru = "Кошки могут мурлыкать", en = "Cats can purr" },
	{
		id = "q22",
		truth = false,
		ru = "Треугольник — это фигура с четырьмя углами",
		en = "A triangle has four corners",
	},
	{
		id = "q23",
		truth = true,
		ru = "Гусеница превращается в бабочку",
		en = "A caterpillar turns into a butterfly",
	},
	{
		id = "q24",
		truth = false,
		ru = "Звук быстрее света",
		en = "Sound is faster than light",
	},
	{
		id = "q25",
		truth = true,
		ru = "Марс называют Красной планетой",
		en = "Mars is called the Red Planet",
	},
	{ id = "q26", truth = false, ru = "У коровы два хвоста", en = "A cow has two tails" },
	{
		id = "q27",
		truth = true,
		ru = "Магнит притягивает железо",
		en = "A magnet attracts iron",
	},
	{
		id = "q28",
		truth = false,
		ru = "Банан растёт на дереве из ствола-бревна",
		en = "Bananas grow on trees with wooden trunks",
	},
	{
		id = "q29",
		truth = true,
		ru = "Верблюд может долго не пить",
		en = "A camel can go a long time without drinking",
	},
	{
		id = "q30",
		truth = false,
		ru = "Зимой в Австралии всегда идёт снег",
		en = "It always snows in Australia in winter",
	},
	{ id = "q31", truth = true, ru = "В году 12 месяцев", en = "A year has 12 months" },
	{
		id = "q32",
		truth = false,
		ru = "Рыбы дышат лёгкими, как люди",
		en = "Fish breathe with lungs, like people",
	},
	{
		id = "q33",
		truth = true,
		ru = "Черепахи откладывают яйца",
		en = "Turtles lay eggs",
	},
	{
		id = "q34",
		truth = false,
		ru = "Самая большая планета — Меркурий",
		en = "Mercury is the biggest planet",
	},
	{
		id = "q35",
		truth = true,
		ru = "Совы хорошо видят в темноте",
		en = "Owls see well in the dark",
	},
	{
		id = "q36",
		truth = false,
		ru = "Смешать синий и жёлтый — получится красный",
		en = "Blue mixed with yellow makes red",
	},
	{
		id = "q37",
		truth = true,
		ru = "Дельфины спят, отключая половину мозга",
		en = "Dolphins sleep with half of the brain at a time",
	},
	{
		id = "q38",
		truth = false,
		ru = "Сосна сбрасывает все иголки каждую осень",
		en = "A pine tree drops all its needles every autumn",
	},
	{
		id = "q39",
		truth = true,
		ru = "Улитки умеют спать очень долго",
		en = "Snails can sleep for a very long time",
	},
	{
		id = "q40",
		truth = false,
		ru = "Пингвины умеют летать высоко в небе",
		en = "Penguins fly high in the sky",
	},
}

local byId = {}
for _, q in Questions.List do
	byId[q.id] = q
end

function Questions.get(id: string)
	return byId[id]
end

function Questions.text(id: string, lang: string): string
	local q = byId[id]
	if not q then
		return id
	end
	return if lang == "ru" then q.ru else q.en
end

return Questions
