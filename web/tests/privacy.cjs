const { chromium } = require("playwright");
const assert = require("node:assert/strict");
const fs = require("node:fs");
(async () => {
  const browser = await chromium.launch({
    executablePath: "/usr/bin/chromium",
    headless: true,
    args: ["--no-sandbox"],
  });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  page.setDefaultTimeout(12000);
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto(process.env.TUTOR_BASE_URL);
  await page
    .getByRole("button", { name: "Настроить вместе со взрослым" })
    .click();
  await page.getByLabel("Логин", { exact: true }).fill("privacy-" + Date.now());
  await page
    .getByLabel("Пароль · от 10 символов")
    .fill("privacy-test-password");
  await page.getByLabel("Родительский PIN · 6 цифр").fill("123456");
  await page
    .getByRole("button", { name: "Создать семью", exact: true })
    .click();
  await page.getByLabel("Локальное обучение").check();
  await page.getByRole("button", { name: "Сохранить выбор" }).click();
  await page.getByRole("button", { name: "Добавить ребёнка" }).click();
  await page.getByLabel("Псевдоним").fill("Сова");
  await page.getByRole("button", { name: "Сохранить профиль" }).click();
  await page.getByRole("heading", { name: "Ваша семья" }).waitFor();
  await page.getByRole("button", { name: "Данные", exact: false }).click();
  await page
    .getByRole("heading", { name: "Ваши данные — ваш выбор" })
    .waitFor();
  await page
    .getByLabel("Повторно введите пароль")
    .fill("privacy-test-password");
  await page.getByRole("button", { name: "Отправить запрос" }).click();
  await page.getByRole("button", { name: "Обновить статусы" }).click();
  await page.getByRole("button", { name: "Скачать JSON" }).waitFor();
  const downloadEvent = page.waitForEvent("download");
  await page.getByRole("button", { name: "Скачать JSON" }).click();
  const download = await downloadEvent;
  const exported = JSON.parse(fs.readFileSync(await download.path(), "utf8"));
  assert.equal(exported.children[0].nickname, "Сова");
  assert.equal(exported.safety_fragments_included, false);
  assert.equal(JSON.stringify(exported).includes("password_hash"), false);
  await page.locator("select[name=operation]").selectOption("deletion");
  await page
    .getByLabel("Повторно введите пароль")
    .fill("privacy-test-password");
  await page.getByLabel("Для удаления введите DELETE").fill("DELETE");
  await page.getByRole("button", { name: "Отправить запрос" }).click();
  await page.getByRole("heading", { name: "Удаление семьи" }).waitFor();
  await page.getByRole("button", { name: "Проверить статус" }).click();
  await page.getByText("Завершено", { exact: true }).waitFor();
  assert.deepEqual(errors, []);
  console.log(
    "PASS: adult reauthentication, isolated JSON export, family deletion and receipt after token revocation",
  );
  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
