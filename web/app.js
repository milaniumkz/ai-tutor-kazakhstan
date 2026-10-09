const $ = (q) => document.querySelector(q);
const escape = (s) =>
  String(s ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const screenNames = {
  C01: "Знакомство",
  C02: "Выбор профиля",
  C03: "Главная ребёнка",
  C04: "Предметы",
  C05: "Путь темы",
  C06: "Урок",
  C07: "Голос готов",
  C08: "Слушаю",
  C09: "Думаю",
  C10: "Говорю",
  C11: "Фото задания",
  C12: "Обрезка фото",
  C13: "Подтверждение условия",
  C14: "Разбор задания",
  C15: "Самостоятельная попытка",
  C16: "Подсказка",
  C17: "Итог занятия",
  C18: "Нет сети",
  C19: "Перерыв",
  P01: "Регистрация родителя",
  P02: "Согласия",
  P03: "Профиль ребёнка",
  P04: "Семья",
  P05: "Прогресс",
  P06: "Лимиты",
  P07: "Подписка",
  P08: "Данные и приватность",
  P09: "Настройки",
  A01: "Учебная программа",
  A02: "Редактор урока",
  A03: "Методическая проверка",
  A04: "Инциденты",
  C03T: "Главная на планшете",
  C14T: "Решение на планшете",
  G01: "Взрослый вход",
  G02: "Безопасный взрослый",
  G03: "Сбой голоса",
};
const state = {
  page: "C01",
  privacyJobs: [],
  deletionReceipt: null,
  lessons: [],
  isAdmin: false,
  trial: null,
  contentRoles: [],
  cmsLessons: [],
  cmsObjectives: [],
  cmsSelected: null,
  cmsReview: null,
  tariff: null,
  audit: [],
  adultToken: null,
  pin: null,
  childToken: null,
  children: [],
  child: null,
  consents: {},
  session: null,
  feedback: "",
  busy: false,
  error: "",
  quote: null,
  selected: new Set(),
  preview: null,
  progress: [],
};
const icons = { owl: "🦉", fox: "🦊", cat: "🐱" };
const errorMessages = {
  ACCESS_REQUIRED:
    "Доступ к новым занятиям сейчас закрыт. Позови взрослого — он поможет.",
  TRIAL_ALREADY_USED:
    "Пробный доступ уже был выдан этой семье и не может быть запущен снова.",
  ADMIN_AUTH_REQUIRED:
    "Эта операция доступна только отдельному администратору.",
  AUTH_REQUIRED: "Не удалось войти. Проверьте логин и пароль.",
  PARENT_AUTH_REQUIRED: "Нужен правильный родительский PIN.",
  CONSENT_REQUIRED:
    "Для занятия взрослому нужно включить согласие на обучение.",
  REVISION_CONFLICT: "Состояние занятия изменилось. Откройте его снова.",
  RATE_LIMITED: "Слишком много попыток. Попробуйте через 15 минут.",
  ACCOUNT_UNAVAILABLE: "Этот логин недоступен. Выберите другой.",
  CURRICULUM_UNAVAILABLE:
    "Для этого класса и языка ещё нет проверенного материала.",
  IDEMPOTENCY_CONFLICT: "Этот запрос уже обработан с другими данными.",
  PROFILE_LIMIT: "Достигнут настроенный лимит профилей.",
  REAUTH_REQUIRED: "Для этого действия повторно введите пароль взрослого.",
  DELETION_CONFIRMATION_REQUIRED: "Для удаления введите DELETE.",
  EXPORT_UNAVAILABLE: "Экспорт ещё не готов или срок скачивания истёк.",
  INDEPENDENT_PUBLISHER_REQUIRED: "Автор не может публиковать свой урок.",
  VALIDATION_FAILED: "Проверьте заполненные поля.",
};
async function api(path, { data, parent = false, key, revision } = {}) {
  const headers = { "Content-Type": "application/json" };
  const token = parent ? state.adultToken : state.childToken;
  if (token) headers.Authorization = `Bearer ${token}`;
  if (parent && state.pin) headers["X-Parent-Pin"] = state.pin;
  if (key) headers["Idempotency-Key"] = key;
  if (revision !== undefined) headers["If-Match"] = `"${revision}"`;
  const response = await fetch("/v1" + path, {
    method: data === undefined ? "GET" : "POST",
    headers,
    body: data === undefined ? undefined : JSON.stringify(data),
  });
  const result = await response.json();
  if (!response.ok)
    throw new Error(
      errorMessages[result.error?.code] ||
        "Не удалось выполнить действие. Попробуйте ещё раз.",
    );
  return result;
}
async function work(fn) {
  if (state.busy) return;
  state.busy = true;
  state.error = "";
  render();
  try {
    await fn();
  } catch (e) {
    state.error = e.message;
  } finally {
    state.busy = false;
    render();
  }
}
function navigate(page) {
  state.page = page;
  state.error = "";
  state.feedback = "";
  render();
  window.scrollTo(0, 0);
}
const button = (label, action, css = "primary", extra = "") =>
  `<button class="${css}" data-action="${action}" ${state.busy ? "disabled" : ""} ${extra}>${label}</button>`;
const heading = (code, title, sub = "") =>
  `<div class="eyebrow">${code} · ${code.startsWith("P") ? "Родительская зона" : "Учиться понятно"}</div><h1>${title}</h1>${sub ? `<p class="muted">${sub}</p>` : ""}`;
const card = (icon, title, desc, action) =>
  `<button class="card" data-action="${action}"><span class="card-icon">${icon}</span><h3>${title}</h3><p>${desc}</p></button>`;
let parentIdleTimer;
function touchParent() {
  clearTimeout(parentIdleTimer);
  if (state.pin) parentIdleTimer = setTimeout(lockParent, 120000);
}
function lockParent() {
  state.pin = null;
  state.privacyJobs = [];
  state.progress = [];
  if (
    (state.page.startsWith("P") && state.page !== "P01") ||
    state.page.startsWith("A")
  ) {
    if (!state.deletionReceipt) {
      state.afterUnlock = state.page;
      navigate("G01");
    }
  }
}
for (const type of ["pointerdown", "keydown", "input"])
  document.addEventListener(type, touchParent);
document.addEventListener("visibilitychange", () => {
  if (document.hidden) lockParent();
});
function render() {
  if (
    ((state.page.startsWith("P") && state.page !== "P01") ||
      state.page.startsWith("A")) &&
    !state.pin &&
    !state.deletionReceipt
  ) {
    state.afterUnlock = state.page;
    state.page = "G01";
  }

  const parent =
    state.page.startsWith("P") ||
    state.page.startsWith("A") ||
    state.page === "ADMIN_TARIFF";
  const nav = parent
    ? [
        ["P04", "⌂", "Моя семья"],
        ["P05", "↗", "Прогресс"],
        ["P07", "◇", "Подписка"],
        ["P02", "✓", "Согласия"],
        ["P08", "▤", "Данные"],
        ["C02", "↩", "К детям"],
      ]
    : [
        ["C03", "⌂", "Главная"],
        ["C04", "▤", "Учиться"],
        ["C07", "♩", "Спросить сову"],
        ["C11", "▣", "Фото задания"],
      ];
  $("#app").innerHTML =
    `<header><div class="brand"><span>✦</span> AI Репетитор</div><div class="header-actions"><span class="muted desktop-only">Казахстан · 1–4 классы</span>${button("Все макеты", "catalog", "small secondary")}${button("Для родителей", "parent", "small secondary")}</div></header><div class="shell"><aside class="sidebar">${nav.map(([id, icon, name]) => button(`${icon} &nbsp; ${name}`, "go:" + id, state.page === id ? "active" : "")).join("")}${state.isAdmin ? button("Управление тарифом", "admin-tariff", "small secondary") : ""}${state.isAdmin || state.contentRoles.length ? button("Учебный контент", "cms", "small secondary") : ""}<div class="sidebar-note">Понятные шаги.<br>Спокойный темп.<br>Возможность остановиться.</div>${button("Каталог экранов", "catalog", "small secondary")}</aside><main id="main" aria-live="polite">${state.error ? `<div class="notice error" role="alert">${escape(state.error)}</div>` : ""}${state.busy ? '<div class="notice" role="status">Сохраняем…</div>' : ""}${content()}<footer>Рабочая версия · Подключённые функции и ограничения указаны на экранах.</footer></main></div>${
      true
        ? `<nav class="bottom-nav" aria-label="Основная навигация">${nav
            .slice(0, parent ? 6 : 3)
            .map(
              ([id, icon, name]) =>
                `<button data-action="go:${id}" class="${state.page === id ? "active" : ""}"><span>${icon}</span>${name}</button>`,
            )
            .join("")}</nav>`
        : ""
    }`;
  document
    .querySelectorAll("[data-action]")
    .forEach((el) =>
      el.addEventListener("click", () => action(el.dataset.action)),
    );
  document.querySelectorAll("form").forEach((el) =>
    el.addEventListener("submit", (e) => {
      e.preventDefault();
      submit(el);
    }),
  );
  document.querySelectorAll("[data-child-check]").forEach((el) =>
    el.addEventListener("change", () => {
      el.checked
        ? state.selected.add(el.dataset.childCheck)
        : state.selected.delete(el.dataset.childCheck);
      state.quote = null;
    }),
  );
}
function content() {
  if (
    ["C03", "C03T"].includes(state.page) &&
    state.child &&
    !state.lessons.length
  )
    return (
      heading(
        "C03",
        `Привет, ${escape(state.child.nickname)}`,
        `${state.child.grade} класс · ${state.child.instruction_language === "kk-KZ" ? "Қазақша" : "Русский"}`,
      ) +
      `<div class="hero"><h2>Подбираем учебные материалы</h2><p>Для твоего класса и языка ещё нет опубликованных проверенных уроков. Мы покажем доступные темы, когда они появятся.</p>${button("Посмотреть предметы", "go:C04")}</div><div class="notice">Мы не подменяем выбранную программу материалом другого класса.</div>`
    );
  switch (state.page) {
    case "C01":
      return `<div class="greeting">${heading("C01", "Учиться понятно.", "Маленькие шаги к большим открытиям")}<div class="owl" aria-hidden="true">🦉</div></div><div class="hero"><span class="tag">Твой помощник в учёбе</span><h2>Сначала попробуем,<br>потом разберёмся</h2><p>Я — программа-помощник. Вместе будем считать и находить следующий шаг.</p>${button("Настроить вместе со взрослым →", "parent")}</div><div class="notice">Голос, распознавание фото и оплата ещё не подключены. Тестовое задание не является официальной учебной программой.</div>${button("Посмотреть все экраны", "catalog", "secondary")}`;
    case "P01":
      return (
        heading(
          "P01",
          "Начнём с семьи",
          "Создайте локальную учётную запись для проверки рабочего сценария.",
        ) +
        `<div class="notice warn">Подтверждение контакта и юридические документы ещё не подключены. Используйте взрослую тестовую учётную запись и вымышленные детские профили.</div><div class="tabs">${button("Создать аккаунт", "auth-register", "secondary")}${button("Уже есть аккаунт", "auth-login", "secondary")}</div><form class="form" data-form="${state.authMode === "login" ? "login" : "register"}"><label>Логин<input name="login" autocomplete="username" minlength="3" maxlength="80" required></label><label>Пароль · от 10 символов<input name="password" type="password" autocomplete="${state.authMode === "login" ? "current-password" : "new-password"}" minlength="10" maxlength="128" required></label>${state.authMode === "login" ? "" : `<label>Родительский PIN · 6 цифр<input name="pin" type="password" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" autocomplete="off" required></label>`}<button class="primary" ${state.busy ? "disabled" : ""}>${state.authMode === "login" ? "Войти" : "Создать семью"}</button></form>`
      );
    case "G01":
      return (
        heading(
          "G01",
          "Только для взрослого",
          "Введите родительский PIN. Проверку выполняет сервер.",
        ) +
        `<form class="form" data-form="unlock"><label>PIN<input name="pin" type="password" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" autocomplete="off" required></label><button class="primary" ${state.busy ? "disabled" : ""}>Открыть родительскую зону</button></form>${button("Вернуться", "go:C03", "secondary")} ${button("Войти заново", "logout", "secondary")}`
      );
    case "P02":
      return (
        heading(
          "P02",
          "Вы решаете, что разрешить",
          "Каждая цель выбирается отдельно. Согласия не отмечены заранее.",
        ) +
        `<div class="notice warn">Версия engineering-v1 — техническая проверка, не утверждённое юридическое согласие. Внешних передач данных нет.</div><form data-form="consents" class="form">${[
          [
            "learning",
            "Локальное обучение",
            "Сохранение учебных попыток и прогресса в этой среде.",
          ],
          [
            "voice",
            "Голос",
            "Пока недоступен. Разрешение не включает микрофон.",
          ],
          [
            "photo",
            "Фото задания",
            "Пока недоступно. Изображения не загружаются.",
          ],
          [
            "research",
            "Исследования",
            "Отдельное необязательное разрешение. Исследования не запущены.",
          ],
        ]
          .map(
            ([key, title, desc]) =>
              `<label class="check"><input type="checkbox" name="${key}" ${state.consents[key] ? "checked" : ""}><span>${title}<br><small class="muted">${desc}</small></span></label>`,
          )
          .join(
            "",
          )}<button class="primary" ${state.busy ? "disabled" : ""}>Сохранить выбор</button></form>`
      );
    case "P03":
      return (
        heading(
          "P03",
          "Новый профиль",
          "Для обучения достаточно псевдонима, класса и языка.",
        ) +
        `<form data-form="child" class="form"><label>Псевдоним<input name="nickname" maxlength="30" required placeholder="Например, Сова"></label><label>Класс<select name="grade">${[1, 2, 3, 4].map((n) => `<option value="${n}">${n} класс</option>`).join("")}</select></label><label>Возрастная группа<select name="age_band"><option>6-7</option><option>8-9</option><option>10-11</option></select></label><label>Язык обучения<select name="instruction_language"><option value="ru-KZ">Русский</option><option value="kk-KZ">Қазақша</option></select></label><label>Аватар<select name="avatar"><option value="owl">🦉 Сова</option><option value="fox">🦊 Лиса</option><option value="cat">🐱 Кот</option></select></label><button class="primary" ${state.busy ? "disabled" : ""}>Сохранить профиль</button></form>`
      );
    case "P04":
      return (
        heading(
          "P04",
          "Ваша семья",
          "Отдельные профили, занятия и доступ для каждого ребёнка.",
        ) +
        `${trialView()}<div class="cards">${state.children.map((c) => `<article class="card"><div class="profile-avatar">${icons[c.avatar]}</div><h2>${escape(c.nickname)}</h2><p>${c.grade} класс · ${c.instruction_language === "kk-KZ" ? "Қазақша" : "Русский"}</p>${button("Открыть занятия", "child:" + c.id, "secondary full")}</article>`).join("")}${card("＋", "Добавить ребёнка", "До пяти профилей в семье", "go:P03")}</div><div class="notice">Сохранённый профиль не означает оплаченный доступ. Состав подписки выбирается отдельно.</div>${button("Рассчитать подписку", "go:P07")}`
      );
    case "C02":
      return (
        heading("C02", "Кто будет учиться?") +
        `<div class="cards">${state.children.map((c) => card(icons[c.avatar], escape(c.nickname), `${c.grade} класс`, "child:" + c.id)).join("")}</div>${!state.children.length ? `<div class="empty"><p>Взрослый сначала создаёт профиль.</p>${button("Позвать взрослого", "parent")}</div>` : ""}`
      );
    case "C03T":
    case "C03":
      return `<div class="greeting"><div class="greeting-copy"><div class="eyebrow">Привет, ${escape(state.child?.nickname || "друг")}</div><h1>Что узнаем<br>сегодня?</h1></div><div class="owl" aria-hidden="true">🦉</div></div><div class="hero"><span class="tag">Математика · ${state.child?.grade || 1} класс</span><span class="hero-art" aria-hidden="true">🍏</span><h2>Выбираем<br>занятие</h2><p class="muted">Темы для вашего класса и языка обучения</p>${button("Выбрать тему →", "curriculum", "full primary")}</div><div class="cards">${card("▤", "Выбрать предмет", "Читать, считать, открывать", "go:C04")}${card("♩", "Спросить сову", "Объяснение простыми словами", "go:C07")}${card("▣", "Показать задание", "Фото или условие задачи", "go:C11")}</div><div class="notice">Арифметическое задание для проверки приложения. Официальное покрытие программы пока не опубликовано.</div>`;
    case "C04":
      return (
        heading(
          "C04",
          "Что будем изучать?",
          "Каталог зависит от класса и языка обучения.",
        ) +
        `<div class="cards">${card("＋", "Математика", "Проверить доступные темы", "curriculum")}${card("А", "Грамотность", "Проверенные материалы ещё не опубликованы", "unavailable")}${card("🌿", "Познание мира", "Проверенные материалы ещё не опубликованы", "unavailable")}</div>`
      );
    case "C05":
      return (
        heading("C05", "Шаг за шагом", "Темы для вашего класса и языка") +
        `<div class="cards">${state.lessons.map((l) => card("＋", escape(l.title || "Складываем две группы"), l.official_curriculum ? "Проверенный урок" : "Учебное занятие", "lesson:" + l.id)).join("")}</div>`
      );
    case "C06":
    case "C15":
    case "C16":
    case "C14T":
      return lessonView();
    case "C17":
      return (
        heading("C17", "Получилось!") +
        `<div class="summary"><div class="symbol">🌱</div><h2>Теперь ты умеешь складывать две группы</h2><p>Ты решил похожий пример самостоятельно.</p><p class="muted">Результат сохранён на сервере.</p>${button("На главную →", "go:C03")}</div>`
      );
    case "C19":
      return (
        heading("C19", "Можно отдохнуть") +
        `<div class="summary"><div class="symbol">☁️</div><h2>Мы сохранили твой шаг</h2><p>Микрофон выключен. Продолжи, когда будешь готов.</p>${button("Продолжить", "resume")} ${button("Закончить", "cancel", "secondary")}</div>`
      );
    case "C07":
    case "C08":
    case "C09":
    case "C10":
    case "G03":
      return (
        heading("C07", "Спросить сову", "Можно учиться без микрофона.") +
        `<div class="board"><div class="owl">🦉</div><h2>Голос пока недоступен</h2><p class="muted">Микрофон выключен. Задание можно решить касанием.</p>${button("Перейти к заданию", "lesson")}</div>`
      );
    case "C11":
    case "C12":
    case "C13":
    case "C14":
      return (
        heading(
          "C11",
          "Покажи задание",
          "Твоё фото не отправляется автоматически.",
        ) +
        `<div class="board"><span class="profile-avatar">▣</span><h2>Распознавание ещё не подключено</h2><p class="muted">Для этого нужен проверенный OCR-поставщик и маршрут обработки.</p>${button("Выбрать доступное занятие", "curriculum")}</div>`
      );
    case "C18":
      return (
        heading("C18", "Не удалось соединиться") +
        `<div class="empty"><h2>Твой шаг не потерян</h2><p>Проверь сеть и попробуй ещё раз. Новые ответы офлайн пока не сохраняются.</p>${button("Повторить", "reload-session")}${button("На главную", "go:C03", "secondary")}</div>`
      );
    case "P05":
      return (
        heading("P05", "Прогресс без сравнения") +
        `<div class="stack">${state.progress
          .map((p) => {
            const c = state.children.find((c) => c.id === p.child_id);
            return `<article class="card"><h2>${escape(c?.nickname)}</h2><div class="price">${p.completed_sessions}</div><p>Завершённых занятий · самостоятельный перенос навыка</p><p class="muted">${escape(p.description)}</p>${(p.topics || []).map((t) => `<div class="notice"><h3>${escape(t.title)}</h3><p>Самостоятельный перенос: ${t.independent_transfer}<br>Перенос с помощью: ${t.assisted_transfer}<br>Подсказки: ${t.hints}</p><p>Версия: ${escape(t.curriculum_version)} · нужны дополнительные наблюдения</p></div>`).join("")}</article>`;
          })
          .join(
            "",
          )}</div>${button("Обновить прогресс", "progress", "secondary")}`
      );
    case "P07":
      return (
        heading(
          "P07",
          "Доступ для каждого ребёнка",
          "Выберите профили, которым нужна подписка. Класс не меняет число оплаченных мест.",
        ) +
        `${trialView()}<div class="form">${state.children.map((c) => `<label class="check"><input type="checkbox" data-child-check="${c.id}" ${state.selected.has(c.id) ? "checked" : ""}><span>${icons[c.avatar]} ${escape(c.nickname)}<br><small class="muted">${c.grade} класс · 1 место</small></span></label>`).join("")}${button("Рассчитать стоимость", "quote")} ${state.quote ? quoteView() : ""}</div><div class="notice">Цены задаёт владелец продукта; покупка включится после серверной проверки магазина. Оплата сейчас недоступна.</div>`
      );
    case "P08":
      return privacyView();
    case "P09":
      return (
        heading("P09", "Настройки родителя") +
        button("Выйти из семьи", "logout", "secondary") +
        `<div class="notice">Локальные токены очищаются; сервер отзывает семейные сеансы.</div>`
      );
    case "P06":
      return (
        heading(state.page, screenNames[state.page]) +
        `<div class="notice">Этот экран есть в дизайн-каталоге. Серверные лимиты занятий и настройки уведомлений ещё не подключены.</div>${button("Открыть исходный макет", "preview:" + state.page, "secondary")}`
      );
    case "G02":
      return (
        heading("G02", "Ты можешь попросить помощи") +
        `<div class="card"><h2>Обратись к взрослому, которому доверяешь</h2><p>Если тебе сейчас небезопасно, можно попросить помощи учителя или другого безопасного взрослого.</p>${button("Закончить занятие", "cancel")}</div>`
      );
    case "ADMIN_TARIFF":
      return adminView();
    case "A01":
    case "A02":
    case "A03":
      return cmsView();
    case "CATALOG":
      return catalogue();
    default:
      return (
        heading(state.page, screenNames[state.page] || "Экран") +
        `<div class="notice">Редакторский экран представлен исходным макетом. Административные операции ещё не реализованы.</div>${button("Посмотреть макет", "preview:" + state.page, "secondary")}`
      );
  }
}
function lessonView() {
  const s = state.session;
  if (!s)
    return (
      heading("C06", "Сначала выберем занятие") +
      button("Выбрать", "curriculum")
    );
  return (
    heading(
      s.step === 0 ? "C06" : "C15",
      s.step === 0 ? "Сложим вместе" : "Теперь попробуй сам",
      s.step === 0
        ? "Посчитай первую группу и добавь вторую."
        : "Похожий пример. Ты можешь решить его самостоятельно.",
    ) +
    `<div class="progress-line" aria-label="Шаг ${s.step + 1} из 2"><span style="width:${s.step === 0 ? 50 : 100}%"></span></div><div class="lesson-layout"><div class="board" role="img" aria-label="${escape(s.board.alt_text)}"><div class="row">${(s.board.groups || []).map((n, i) => `<div class="counter-group">${Array.from({ length: n }, () => `<span class="counter ${i ? "alt" : ""}" aria-hidden="true"></span>`).join("")}</div>${i ? "" : '<span aria-hidden="true">＋</span>'}`).join("")}</div><div class="equation">${escape(s.question)}</div></div><div class="lesson-side"><h2>Сколько всего?</h2><div class="answers">${(s.choices || [6, 7, 8]).map((n) => button(n, "answer:" + n, "secondary")).join("")}</div>${state.feedback ? `<div class="notice" role="status">${escape(state.feedback)}</div>` : ""}<div class="row">${button("Подсказка", "hint", "secondary")}${button("Пауза", "pause", "purple")}</div></div></div>`
  );
}
function quoteView() {
  const q = state.quote;
  return `<article class="card"><h2>Ваш расчёт</h2><p class="muted">${escape(q.tariff_name)} · версия ${q.tariff_revision}</p>${q.items.map((i) => `<p>${escape(i.nickname)} · ${i.grade} класс <strong>${i.unit_amount === null ? "Цена не задана" : i.unit_amount + " ₸ / мес."}</strong></p>`).join("")}<hr><div class="price">${q.total_amount === null ? q.quantity + " " + (q.quantity === 1 ? "место" : "места") : q.total_amount + " ₸ / мес."}</div><p>${q.price_configured ? "Итог по выбранным профилям." : "Стоимость появится после настройки тарифа."}</p><button class="secondary full" disabled>Оплата ещё не подключена</button></article>`;
}
function catalogue() {
  const ids = Object.keys(screenNames);
  return (
    heading(
      "DESIGN",
      "Все экраны приложения",
      "32 основных экрана, 2 планшетных варианта и 3 сквозных состояния из предоставленного каталога.",
    ) +
    `<div class="notice">Исходные макеты показаны без изменений. Рабочие переходы доступны в реализованном срезе; просмотр остальных не означает готовность функций.</div>${state.preview ? `<div class="card"><div class="row between"><h2>${state.preview} · ${screenNames[state.preview]}</h2>${button("Открыть экран", "go:" + state.preview, "secondary small")}</div><img src="/assets/screen-${String(Math.min(ids.indexOf(state.preview) + 3, 37)).padStart(2, "0")}.jpg" alt="Исходный макет ${state.preview}: ${screenNames[state.preview]}" style="width:100%;height:auto"></div>` : ""}<div class="screen-grid">${ids.map((id) => button(`<span class="screen-code">${id}</span><br>${screenNames[id]}`, "preview:" + id, "secondary")).join("")}</div>`
  );
}
async function loadFamily() {
  touchParent();
  state.trial = await api("/billing/trial", { parent: true });
  state.children = await api("/children", { parent: true });
  state.consents = await api("/consents", { parent: true });
}
async function action(a) {
  if (a === "cms")
    return work(async () => {
      if (!state.pin) {
        state.afterUnlock = "A01";
        return action("parent");
      }
      await loadCms();
      navigate("A01");
    });
  if (a.startsWith("cms-edit:")) {
    state.cmsSelected = state.cmsLessons.find((l) => l.id === a.slice(9));
    return navigate("A02");
  }
  if (a.startsWith("cms-review:")) {
    state.cmsReview = state.cmsLessons.find((l) => l.id === a.slice(11));
    return navigate("A03");
  }
  if (
    a.startsWith("cms-submit:") ||
    a.startsWith("cms-publish:") ||
    a.startsWith("cms-retire:") ||
    a.startsWith("cms-rollback:")
  )
    return work(async () => {
      const [op, id] = a.split(":");
      await api("/admin/content/" + id + "/" + op.slice(4), {
        parent: true,
        data: {},
      });
      await loadCms();
      navigate("A03");
    });
  if (a.startsWith("go:A") && a !== "go:ADMIN_TARIFF")
    return work(async () => {
      const page = a.slice(3);
      if (!state.pin) {
        state.afterUnlock = page;
        return action("parent");
      }
      await loadCms();
      navigate(page);
    });
  if (a === "activate-trial")
    return work(async () => {
      state.trial = await api("/billing/trial", {
        parent: true,
        data: {},
        key: crypto.randomUUID(),
      });
    });
  if (a === "privacy-refresh")
    return work(async () => {
      if (state.deletionReceipt) {
        const r = await fetch(
          "/v1/privacy/receipts/" + state.deletionReceipt.id,
          {
            headers: {
              Authorization: "Bearer " + state.deletionReceipt.receipt_token,
            },
          },
        );
        if (!r.ok) throw new Error("Не удалось проверить статус удаления");
        state.deletionReceipt = {
          ...state.deletionReceipt,
          ...(await r.json()),
        };
      } else {
        state.privacyJobs = await api("/privacy/jobs", { parent: true });
        await loadFamily();
      }
    });
  if (a.startsWith("privacy-download:"))
    return work(async () => {
      const result = await api("/privacy/jobs/" + a.slice(17) + "/download", {
        parent: true,
      });
      const blob = new Blob([JSON.stringify(result, null, 2)], {
        type: "application/json",
      });
      const url = URL.createObjectURL(blob),
        link = document.createElement("a");
      link.href = url;
      link.download = "family-export.json";
      link.click();
      URL.revokeObjectURL(url);
    });
  if (a.startsWith("go:")) {
    const page = a.slice(3);
    if (page.startsWith("P") && !state.pin) {
      state.afterUnlock = page;
      return action("parent");
    }
    if (page === "P08")
      return work(async () => {
        state.privacyJobs = await api("/privacy/jobs", { parent: true });
        navigate(page);
      });
    if (page === "P05") return action("progress");
    if (["C03", "C04", "C05"].includes(page) && !state.child)
      return navigate(state.children.length ? "C02" : "C01");
    if (page.startsWith("C")) {
      state.pin = null;
      state.privacyJobs = [];
    }
    return navigate(page);
  }
  if (a.startsWith("preview:")) {
    state.preview = a.slice(8);
    return navigate("CATALOG");
  }
  if (a === "admin-tariff")
    return work(async () => {
      if (!state.pin) {
        state.afterUnlock = "ADMIN_TARIFF";
        return action("parent");
      }
      state.tariff = await api("/admin/tariff", { parent: true });
      state.audit = await api("/admin/tariff/audit", { parent: true });
      navigate("ADMIN_TARIFF");
    });
  if (a === "catalog") return navigate("CATALOG");
  if (a === "logout")
    return work(async () => {
      let warning = "";
      try {
        if (state.adultToken)
          await api("/auth/logout", { parent: true, data: {} });
      } catch (e) {
        warning =
          "Локальный выход выполнен, но серверный отзыв не подтверждён. Сеансы истекают через 15 минут.";
      }
      state.adultToken = null;
      state.pin = null;
      state.privacyJobs = [];
      state.deletionReceipt = null;
      state.childToken = null;
      state.child = null;
      state.children = [];
      state.session = null;
      state.isAdmin = false;
      state.consents = {};
      state.quote = null;
      state.selected.clear();
      state.progress = [];
      state.tariff = null;
      state.audit = [];
      navigate("P01");
      state.error = warning;
    });
  if (a === "parent") {
    state.pin = null;
    return navigate(state.adultToken ? "G01" : "P01");
  }
  if (a.startsWith("auth-")) {
    state.authMode = a.slice(5);
    return navigate("P01");
  }
  if (a.startsWith("child:") && !state.pin) {
    state.afterUnlock = "C02";
    return action("parent");
  }
  if (a.startsWith("child:"))
    return work(async () => {
      state.child = state.children.find((c) => c.id === a.slice(6));
      const r = await api("/children/" + state.child.id + "/access", {
        parent: true,
        data: {},
      });
      state.childToken = r.token;
      state.lessons = (await api("/curriculum")).lessons;
      state.privacyJobs = [];
      state.session = null;
      state.pin = null;
      navigate("C03");
    });
  if (a === "curriculum")
    return work(async () => {
      if (!state.childToken) return navigate("C01");
      const catalog = await api("/curriculum");
      state.lessons = catalog.lessons;
      if (!catalog.lessons.length)
        throw new Error(errorMessages.CURRICULUM_UNAVAILABLE);
      navigate("C05");
    });
  if (a === "lesson" || a.startsWith("lesson:"))
    return work(async () => {
      if (!state.childToken)
        return navigate(state.children.length ? "C02" : "C01");
      if (
        !state.session ||
        ["completed", "cancelled"].includes(state.session.state)
      )
        state.session = await api("/sessions", {
          data: {
            lesson_id: a.startsWith("lesson:")
              ? a.slice(7)
              : "engineering-addition-v1",
          },
          key: crypto.randomUUID(),
        });
      navigate(state.session.state === "paused" ? "C19" : "C06");
    });
  if (a.startsWith("answer:"))
    return work(async () => {
      const s = state.session,
        event = crypto.randomUUID();
      const r = await api("/sessions/" + s.id + "/attempts", {
        data: {
          client_event_id: event,
          task_revision: s.task_revision,
          step_id: s.step_id,
          input: { type: "choice", value: Number(a.slice(7)) },
        },
        key: event,
        revision: s.revision,
      });
      state.session = r.session;
      state.feedback = r.feedback;
      state.page =
        r.session.state === "completed"
          ? "C17"
          : r.evaluation === "incorrect"
            ? "C16"
            : "C15";
    });
  if (a === "hint")
    return work(async () => {
      const r = await api("/sessions/" + state.session.id + "/hints", {
        data: {},
        key: crypto.randomUUID(),
        revision: state.session.revision,
      });
      state.feedback = r.hint;
      state.session = r.session;
      state.page = "C16";
    });
  if (["pause", "resume", "cancel"].includes(a))
    return work(async () => {
      if (!state.session) return navigate("C03");
      state.session = await api("/sessions/" + state.session.id + "/" + a, {
        data: {},
        revision: state.session.revision,
      });
      navigate(a === "pause" ? "C19" : a === "resume" ? "C06" : "C03");
    });
  if (a === "quote")
    return work(async () => {
      state.quote = await api("/billing/quote", {
        parent: true,
        data: { child_ids: [...state.selected] },
      });
    });
  if (a === "progress")
    return work(async () => {
      if (!state.pin) {
        state.afterUnlock = "P05";
        return action("parent");
      }
      state.progress = await Promise.all(
        state.children.map((c) =>
          api("/progress?child_id=" + c.id, { parent: true }),
        ),
      );
      navigate("P05");
    });
  if (a === "reload-session")
    return work(async () => {
      if (state.session)
        state.session = await api("/sessions/" + state.session.id);
      navigate(state.session?.state === "completed" ? "C17" : "C06");
    });
  if (a === "unavailable") {
    state.error =
      "Проверенные материалы для этого предмета ещё не опубликованы.";
    return render();
  }
}
function submit(form) {
  const data = Object.fromEntries(new FormData(form));
  const kind = form.dataset.form;
  return work(async () => {
    if (["register", "login"].includes(kind)) {
      const r = await api("/auth/" + kind, { data });
      state.privacyJobs = [];
      state.deletionReceipt = null;
      state.childToken = null;
      state.child = null;
      state.session = null;
      state.children = [];
      state.consents = {};
      state.quote = null;
      state.selected.clear();
      state.adultToken = r.token;
      state.isAdmin = r.is_admin === true;
      state.contentRoles = r.content_roles || [];
      if (kind === "register") {
        state.pin = data.pin;
        await loadFamily();
        navigate("P02");
      } else navigate("G01");
    }
    if (kind === "privacy") {
      const purpose = data.operation;
      const proof = await api("/privacy/reauth", {
        parent: true,
        data: { password: data.password, purpose },
      });
      const result = await api(
        "/privacy/" + (purpose === "export" ? "exports" : "deletions"),
        {
          parent: true,
          key: crypto.randomUUID(),
          data: {
            reauth_token: proof.reauth_token,
            child_id: data.scope || null,
            confirmation: data.confirmation,
          },
        },
      );
      if (purpose === "deletion" && !data.scope) {
        state.deletionReceipt = result;
        state.adultToken = null;
        state.childToken = null;
        state.pin = null;
        state.children = [];
        state.child = null;
        state.session = null;
        state.quote = null;
        state.selected.clear();
        state.consents = {};
        state.isAdmin = false;
        state.contentRoles = [];
        state.cmsLessons = [];
        state.privacyJobs = [];
      } else {
        await loadFamily();
        state.privacyJobs = await api("/privacy/jobs", { parent: true });
      }
      navigate("P08");
    }
    if (kind === "unlock") {
      state.pin = data.pin;
      await loadFamily();
      const target = state.afterUnlock || "P04";
      state.afterUnlock = null;
      if (target === "ADMIN_TARIFF") {
        state.tariff = await api("/admin/tariff", { parent: true });
        state.audit = await api("/admin/tariff/audit", { parent: true });
      }
      if (target.startsWith("A") && target !== "ADMIN_TARIFF") await loadCms();
      navigate(target);
    }
    if (kind === "consents") {
      for (const purpose of ["learning", "voice", "photo", "research"]) {
        const granted = data[purpose] === "on";
        if (Boolean(state.consents[purpose]) !== granted)
          state.consents = await api("/consents", {
            parent: true,
            data: { purpose, granted, version: "engineering-v1" },
          });
      }
      navigate("P04");
    }
    if (kind === "cms-search") {
      const result = await api("/admin/curriculum?grade=" + data.grade, {
        parent: true,
      });
      state.cmsObjectives = result.objectives;
    }
    if (kind === "cms-review") {
      const l = state.cmsReview;
      await api("/admin/content/" + l.id + "/review", {
        parent: true,
        data: {
          decision: data.decision,
          notes: data.notes,
          normative_applicability_checked: data.normative === "on",
        },
      });
      state.cmsReview = null;
      await loadCms();
    }
    if (kind === "cms-editor") {
      const previous = state.cmsSelected.payload;
      const steps = previous.steps.map((step, i) => ({
        ...step,
        question: data["question_" + i],
        answer: Number(data["answer_" + i]),
        choices: data["choices_" + i].split(",").map(Number),
      }));
      await api("/admin/content", {
        parent: true,
        data: {
          ...previous,
          previous_version_id: state.cmsSelected.id,
          title: data.title,
          explanation: data.explanation,
          hint: data.hint,
          steps,
        },
      });
      await loadCms();
      navigate("A01");
    }
    if (kind === "tariff") {
      state.tariff = await api("/admin/tariff", {
        parent: true,
        data: {
          name: data.name,
          price_per_child_kzt: Number(data.price_per_child_kzt),
          max_saved_profiles: Number(data.max_saved_profiles),
          trial_days: Number(data.trial_days),
        },
        revision: state.tariff.revision,
      });
      state.audit = await api("/admin/tariff/audit", { parent: true });
      state.quote = null;
      state.feedback =
        "Настройки сохранены. Новые расчёты используют обновлённый тариф.";
    }
    if (kind === "child") {
      await api("/children", {
        parent: true,
        data: { ...data, grade: Number(data.grade) },
      });
      await loadFamily();
      navigate("P04");
    }
  });
}
render();

function adminView() {
  const t = state.tariff;
  if (!t)
    return (
      heading("ADMIN", "Управление тарифом") +
      button("Загрузить", "admin-tariff")
    );
  return (
    heading(
      "ADMIN",
      "Управление тарифом",
      "Изменения применяются к новым расчётам на сервере без выпуска клиента.",
    ) +
    `<form class="form" data-form="tariff"><label>Название тарифа<input name="name" value="${escape(t.name)}" maxlength="80" required></label><label>Цена за ребёнка в месяц, ₸<input name="price_per_child_kzt" type="number" min="1" max="1000000" step="1" value="${t.price_per_child_kzt}" required></label><label>Лимит сохранённых профилей семьи<input name="max_saved_profiles" type="number" min="1" max="5" step="1" value="${t.max_saved_profiles}" required></label><label>Длительность пробного доступа, дней<input name="trial_days" type="number" min="1" max="30" step="1" value="${t.trial_days}" required></label><div class="notice">${t.price_per_child_kzt.toLocaleString("ru-RU")} ₸ × число выбранных детей. Валюта — тенге, период — месяц.<br>Одна проба на семью, без карты и автосписаний. Изменение длительности действует только для новых проб.<br>Изменение лимита не удаляет существующие профили. Реальные покупки и изменения действующих подписок пока не подключены.</div><button class="primary" ${state.busy ? "disabled" : ""}>Сохранить тариф</button>${state.feedback ? `<div class="notice" role="status">${escape(state.feedback)}</div>` : ""}</form><h2 style="margin-top:32px">История изменений</h2><div class="stack">${
      state.audit
        .map((a) => {
          const old = JSON.parse(a.old_configuration),
            n = JSON.parse(a.new_configuration);
          return `<div class="card"><strong>${old.price_per_child_kzt.toLocaleString("ru-RU")} → ${n.price_per_child_kzt.toLocaleString("ru-RU")} ₸ / ребёнок</strong><p class="muted">${escape(a.occurred_at)} · версия ${n.revision}<br>Проба: ${old.trial_days ?? 3} → ${n.trial_days ?? 3} дн. · профили: ${old.max_saved_profiles} → ${n.max_saved_profiles}</p></div>`;
        })
        .join("") || '<p class="muted">Изменений пока нет.</p>'
    }</div>`
  );
}

function trialView() {
  const t = state.trial;
  if (!t) return "";
  if (t.status === "eligible")
    return `<div class="hero"><span class="tag">Бесплатно · без карты</span><h2>${daysText(t.duration_days)}, чтобы попробовать</h2><p>Один пробный доступ для всей семьи. Все доступные уроки, без дополнительных учебных лимитов. Никаких автосписаний.</p>${button("Начать пробный доступ", "activate-trial")}</div>`;
  if (t.status === "active")
    return `<div class="notice">Пробный доступ активен для всей семьи. Осталось ${Math.ceil(t.remaining_seconds / 86400)} дн. Все созданные профили используют один срок, без карты и автосписаний.</div>`;
  return '<div class="notice">Пробный доступ завершён. Второй пробный период недоступен. Платёжное подключение ещё не готово; уже начатое локальное задание можно закончить.</div>';
}

function daysText(n) {
  const mod = n % 100;
  return `${n} ${mod >= 11 && mod <= 14 ? "дней" : n % 10 === 1 ? "день" : n % 10 >= 2 && n % 10 <= 4 ? "дня" : "дней"}`;
}

async function loadCms() {
  state.cmsLessons = await api("/admin/content", { parent: true });
  const curriculum = await api("/admin/curriculum?grade=1", { parent: true });
  state.cmsObjectives = curriculum.objectives;
}
function cmsView() {
  const tabs = `<div class="tabs">${button("Карта программы", "go:A01", "secondary")}${button("Редактор урока", "go:A02", "secondary")}${button("Очередь проверки", "go:A03", "secondary")}</div>`;
  if (state.page === "A02") {
    const l = state.cmsSelected;
    if (!l)
      return (
        heading("A02", "Редактор урока") +
        tabs +
        '<div class="notice">Выберите урок из карты программы. Черновик можно изменить созданием новой версии.</div>'
      );
    const p = l.payload;
    return (
      heading("A02", escape(p.title), `Версия ${l.version} · ${l.status}`) +
      tabs +
      `<form data-form="cms-editor" class="form"><label>Название<input name="title" value="${escape(p.title)}" required></label><div class="notice">Цель ${escape(p.objective_id)} · ${escape(p.academic_year)} · ${escape(p.locale)}<br>Версия источника и применимость проверяются методистом.</div><label>Объяснение<textarea name="explanation" rows="4" required>${escape(p.explanation)}</textarea></label><label>Подсказка<textarea name="hint" rows="3" required>${escape(p.hint)}</textarea></label>${p.steps.map((s, i) => `<article class="card"><h2>${i ? "Самостоятельный перенос" : "Первое задание"}</h2><label>Условие<input name="question_${i}" value="${escape(s.question)}" required></label><label>Эталонный ответ<input name="answer_${i}" type="number" value="${s.answer}" required></label><label>Три варианта ответа через запятую<input name="choices_${i}" value="${s.choices.join(",")}" required></label></article>`).join("")}<div class="notice">Эталон проверяется арифметическим движком. Сохранение создаёт новую версию и не публикует урок.</div><button class="primary" ${state.busy ? "disabled" : ""}>Сохранить новую версию</button></form>${l.status === "draft" ? button("Отправить на проверку", "cms-submit:" + l.id, "secondary") : ""}`
    );
  }
  if (state.page === "A03") {
    const review = state.cmsReview;
    return (
      heading(
        "A03",
        "Проверка контента",
        "Автор не одобряет собственную версию. Каждое решение сохраняется.",
      ) +
      tabs +
      (review
        ? `<article class="card"><h2>${escape(review.payload.title)}</h2><p>${escape(review.payload.explanation)}</p><p>Цель ${escape(review.objective_id)} · ${escape(review.locale)}</p>${review.payload.steps.map((s) => `<p>${escape(s.question)} · эталон ${s.answer}</p>`).join("")}<form class="form" data-form="cms-review"><label>Решение<select name="decision"><option value="approve">Одобрить</option><option value="reject">Вернуть с замечаниями</option></select></label><label>Заключение<textarea name="notes" minlength="10" maxlength="1000" required rows="4"></textarea></label>${review.status === "in_method_review" ? '<label class="check"><input type="checkbox" name="normative"><span>Проверены нормативный источник, применимость редакции для класса, учебного года и языка.</span></label>' : ""}<button class="primary">Сохранить решение</button></form></article>`
        : "") +
      `<div class="stack">${
        state.cmsLessons
          .filter((l) =>
            [
              "in_method_review",
              "in_language_review",
              "approved",
              "published",
              "retired",
            ].includes(l.status),
          )
          .map(
            (l) =>
              `<article class="card"><div class="row between"><h2>${escape(l.payload.title)}</h2><span class="tag">${l.status}</span></div><p>${l.grade} класс · ${escape(l.locale)} · версия ${l.version}</p><div class="row">${["in_method_review", "in_language_review"].includes(l.status) ? button("Проверить", "cms-review:" + l.id, "secondary") : ""}${l.status === "approved" ? button("Опубликовать", "cms-publish:" + l.id) : ""}${l.status === "published" ? button("Снять с публикации", "cms-retire:" + l.id, "danger") : ""}${l.status === "retired" ? button("Откатить на эту версию", "cms-rollback:" + l.id, "secondary") : ""}${button("Открыть", "cms-edit:" + l.id, "secondary")}</div></article>`,
          )
          .join("") ||
        '<div class="empty">Очередь пока пуста. Отправьте подготовленный черновик на проверку.</div>'
      }</div>`
    );
  }
  return (
    heading(
      "A01",
      "Карта учебной программы",
      "Официальные цели и оригинальные материалы с отдельным статусом проверки.",
    ) +
    tabs +
    `<div class="notice">Источник: приказ №399, загруженная редакция с SHA-256. Извлечение текста не заменяет проверку переходных положений 2026–2029.</div><h2>Подготовленные уроки · ${state.cmsLessons.length}</h2><div class="cards">${state.cmsLessons.map((l) => card("▤", escape(l.payload.title), `${l.grade} класс · ${escape(l.locale)} · ${l.status}`, "cms-edit:" + l.id)).join("")}</div><h2 style="margin-top:32px">Учебные цели</h2><form data-form="cms-search" class="row"><label>Класс<select name="grade">${[1, 2, 3, 4].map((g) => `<option>${g}</option>`).join("")}</select></label><button class="secondary">Показать цели</button></form><div class="stack">${state.cmsObjectives.map((o) => `<article class="card"><strong>${escape(o.code)}</strong><p>${escape(o.occurrences[0].text)}</p><small class="muted">${escape(o.subject_title)}</small><p><a href="${escape(o.source.url)}#${escape(o.occurrences[0].source_anchor || o.subject_id)}" target="_blank" rel="noopener">Официальный источник</a></p></article>`).join("")}</div>`
  );
}

let privacyPoll;
function privacyView() {
  clearTimeout(privacyPoll);
  if (
    state.deletionReceipt?.state === "queued" ||
    state.privacyJobs.some((j) => j.state === "queued")
  )
    privacyPoll = setTimeout(() => {
      if (state.page === "P08" && !state.busy) action("privacy-refresh");
    }, 1000);

  const statuses = {
    queued: "В очереди",
    completed: "Завершено",
    failed: "Ошибка",
    cancelled: "Отменено",
  };
  if (state.deletionReceipt)
    return (
      heading("P08", "Удаление семьи") +
      `<div class="card"><p>${statuses[state.deletionReceipt.state] || escape(state.deletionReceipt.state)}</p><p>Все семейные сеансы отозваны. Учебные профили и история удаляются из активной базы. Минимальные журналы согласий и удаления остаются изолированными.</p><p>Сроки резервных копий внешней инфраструктуры ещё не подтверждены.</p>${button("Проверить статус", "privacy-refresh", "secondary")}</div>`
    );
  return (
    heading("P08", "Ваши данные — ваш выбор") +
    `<div class="card"><p>Экспорт содержит профили, согласия и учебные результаты в JSON. Пароли, токены, чужие данные и safety-фрагменты в него не входят. Скачивание доступно 24 часа только взрослому.</p>${button("Управлять согласиями", "go:P02", "secondary")}</div><form data-form="privacy" class="form"><label>Действие<select name="operation"><option value="export">Экспорт данных</option><option value="deletion">Удаление данных</option></select></label><label>Область<select name="scope"><option value="">Вся семья</option>${state.children.map((c) => `<option value="${c.id}">${escape(c.nickname)}</option>`).join("")}</select></label><label>Повторно введите пароль<input type="password" name="password" autocomplete="current-password" required minlength="10" maxlength="128"></label><label>Для удаления введите DELETE<input name="confirmation" autocomplete="off"></label><p class="muted">Удаление отзовёт доступ выбранного профиля или всей семьи. Действие нельзя отменить. Удалите скачанные копии с общего устройства самостоятельно.</p><button class="primary" ${state.busy ? "disabled" : ""}>Отправить запрос</button></form><h2>Запросы</h2>${button("Обновить статусы", "privacy-refresh", "secondary")}<div class="stack">${state.privacyJobs.map((j) => `<article class="card"><h3>${j.kind === "export" ? "Экспорт" : "Удаление"} · ${statuses[j.state] || escape(j.state)}</h3><p>${escape(j.created_at)}</p>${j.kind === "export" && j.state === "completed" ? button("Скачать JSON", "privacy-download:" + j.id, "secondary") : ""}</article>`).join("")}</div>`
  );
}
