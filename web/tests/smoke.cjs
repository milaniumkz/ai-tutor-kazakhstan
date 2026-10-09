// Run with Playwright installed and the local application listening on TUTOR_BASE_URL.
const { chromium } = require("playwright");
const assert = require("node:assert/strict");
(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || "/usr/bin/chromium",
    headless: true,
    args: ["--no-sandbox"],
  });
  const page = await browser.newPage({
    viewport: { width: 1280, height: 900 },
  });
  page.setDefaultTimeout(10000);
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  const base = process.env.TUTOR_BASE_URL || "http://127.0.0.1:8081";
  await page.goto(base);
  await page
    .getByRole("button", { name: "Настроить вместе со взрослым" })
    .click();
  await page.getByLabel("Логин", { exact: true }).fill("smoke-" + Date.now());
  await page.getByLabel("Пароль · от 10 символов").fill("adult-test-password");
  await page.getByLabel("Родительский PIN · 6 цифр").fill("123456");
  await page
    .getByRole("button", { name: "Создать семью", exact: true })
    .click();
  await page
    .getByRole("heading", { name: "Вы решаете, что разрешить" })
    .waitFor();
  assert.equal(await page.locator("input[type=checkbox]:checked").count(), 0);
  await page.getByLabel("Локальное обучение").check();
  await page.getByRole("button", { name: "Сохранить выбор" }).click();
  await page.getByRole("heading", { name: "Ваша семья" }).waitFor();
  await page.getByRole("button", { name: "Начать пробный доступ" }).click();
  await page.getByText("Пробный доступ активен для всей семьи.").waitFor();
  for (const [name, grade] of [
    ["Сова", 1],
    ["Лиса", 3],
    ["Кот", 4],
  ]) {
    await page.getByRole("button", { name: "Добавить ребёнка" }).click();
    await page.getByLabel("Псевдоним").fill(name);
    await page.locator("select[name=grade]").selectOption(String(grade));
    await page.getByRole("button", { name: "Сохранить профиль" }).click();
    await page.getByRole("heading", { name: "Ваша семья" }).waitFor();
  }
  await page.getByRole("button", { name: "Рассчитать подписку" }).click();
  await page.locator("[data-child-check]").nth(0).check();
  await page.locator("[data-child-check]").nth(1).check();
  await page.getByRole("button", { name: "Рассчитать стоимость" }).click();
  await page.getByRole("heading", { name: "Ваш расчёт" }).waitFor();
  if (process.env.TUTOR_EXPECT_TOTAL)
    assert.ok(
      (await page.locator(".price").textContent()).includes(
        process.env.TUTOR_EXPECT_TOTAL,
      ),
    );
  else
    assert.ok((await page.locator(".price").textContent()).includes("20000"));
  await page.getByRole("button", { name: "Моя семья" }).click();
  await page.getByRole("button", { name: "Открыть занятия" }).nth(1).click();
  await page
    .getByRole("heading", { name: "Подбираем учебные материалы" })
    .waitFor();
  await page.getByRole("button", { name: "Для родителей" }).click();
  await page.getByLabel("PIN", { exact: true }).fill("123456");
  await page.getByRole("button", { name: "Открыть родительскую зону" }).click();
  await page.getByRole("button", { name: "Открыть занятия" }).first().click();
  await page.getByRole("button", { name: "Выбрать тему" }).click();
  await page.locator('[data-action="lesson:engineering-addition-v1"]').click();
  await page.getByRole("heading", { name: "Сложим вместе" }).waitFor();
  await page.getByRole("button", { name: "6", exact: true }).click();
  await page.getByText("Посчитай кружки по одному.").waitFor();
  await page.getByRole("button", { name: "Пауза", exact: true }).click();
  await page.getByRole("heading", { name: "Можно отдохнуть" }).waitFor();
  await page.getByRole("button", { name: "Продолжить", exact: true }).click();
  await page.getByRole("button", { name: "7", exact: true }).click();
  await page.getByRole("heading", { name: "Теперь попробуй сам" }).waitFor();
  await page.getByRole("button", { name: "7", exact: true }).click();
  await page
    .getByRole("heading", { name: "Получилось!", exact: true })
    .waitFor();
  await page.getByRole("button", { name: "Для родителей" }).click();
  await page.getByLabel("PIN", { exact: true }).fill("123456");
  await page.getByRole("button", { name: "Открыть родительскую зону" }).click();
  await page.getByRole("heading", { name: "Ваша семья" }).waitFor();
  await page
    .getByRole("button", { name: "Прогресс", exact: false })
    .first()
    .click();
  await page.getByRole("heading", { name: "Прогресс без сравнения" }).waitFor();
  assert.equal(await page.locator(".price").first().textContent(), "1");
  await page.getByRole("button", { name: "Все макеты" }).click();
  assert.equal(await page.locator(".screen-grid button").count(), 37);
  for (const id of ["C01", "C03T", "G01", "G02", "G03"]) {
    await page.locator(`[data-action="preview:${id}"]`).click();
    const image = page.locator("main img");
    await image.waitFor();
    await image.evaluate((img) => img.decode());
  }
  await page.setViewportSize({ width: 390, height: 844 });
  await page.getByRole("button", { name: "Для родителей" }).click();
  await page.getByLabel("PIN", { exact: true }).fill("123456");
  await page.getByRole("button", { name: "Открыть родительскую зону" }).click();
  await page.getByRole("button", { name: "Открыть занятия" }).first().click();
  await page.getByText("Что узнаем").waitFor();
  assert.ok(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  );
  await page.screenshot({
    path: process.env.TUTOR_SCREENSHOT || "/tmp/tutor-mobile.png",
    fullPage: true,
  });
  await page.getByRole("button", { name: "Для родителей" }).click();
  await page.getByRole("button", { name: "Войти заново" }).click();
  await page.getByRole("heading", { name: "Начнём с семьи" }).waitFor();
  assert.deepEqual(errors, []);
  await browser.close();
  console.log(
    "PASS: registration, separate consents, 3 profiles, per-child quote, lesson, pause, transfer, persisted progress, all-screen catalogue, mobile viewport",
  );
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
