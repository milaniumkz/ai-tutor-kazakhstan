const { chromium } = require("playwright");
const assert = require("node:assert/strict");
(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || "/usr/bin/chromium",
    headless: true,
    args: ["--no-sandbox"],
  });
  try {
    const page = await browser.newPage();
    page.setDefaultTimeout(10000);
    await page.goto(process.env.TUTOR_BASE_URL || "http://127.0.0.1:8081");
    await page.getByRole("button", { name: "Для родителей" }).click();
    await page.getByRole("button", { name: "Уже есть аккаунт" }).click();
    await page
      .getByLabel("Логин", { exact: true })
      .fill(process.env.TUTOR_TEST_ADMIN_LOGIN);
    await page
      .getByLabel("Пароль · от 10 символов")
      .fill(process.env.TUTOR_TEST_ADMIN_PASSWORD);
    await page.getByRole("button", { name: "Войти", exact: true }).click();
    await page
      .getByLabel("PIN", { exact: true })
      .fill(process.env.TUTOR_TEST_ADMIN_PIN);
    await page
      .getByRole("button", { name: "Открыть родительскую зону" })
      .click();
    await page.getByRole("button", { name: "Управление тарифом" }).click();
    await page.getByLabel("Цена за ребёнка в месяц, ₸").fill("12000");
    await page.getByLabel("Длительность пробного доступа, дней").fill("7");
    await page.getByRole("button", { name: "Сохранить тариф" }).click();
    await page.getByText("Настройки сохранены.").waitFor();
    await page.getByText("10 000 → 12 000 ₸ / ребёнок").waitFor();
    await page.getByText("Проба: 3 → 7 дн.", { exact: false }).waitFor();
    await page.getByLabel("Цена за ребёнка в месяц, ₸").fill("10000");
    await page.getByLabel("Длительность пробного доступа, дней").fill("3");
    await page.getByRole("button", { name: "Сохранить тариф" }).click();
    await page.getByText("12 000 → 10 000 ₸ / ребёнок").waitFor();
    assert.equal(await page.locator(".stack .card").count(), 2);
    console.log(
      "PASS: admin login, server PIN gate, tariff editor, live changes and audit history",
    );
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
