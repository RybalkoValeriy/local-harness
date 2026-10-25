// Optional UI smoke check: npm install --prefix tmp/browser-probe --no-save playwright
const { chromium } = require("../tmp/browser-probe/node_modules/playwright")
const assert = require("node:assert/strict")
const path = require("node:path")

;(async () => {
  const browser = await chromium.launch({ channel: "chrome", headless: true })
  const page = await browser.newPage({ viewport: { width: 1365, height: 900 } })
  const errors = []
  page.on("pageerror", error => errors.push(error.message))
  try {
    await page.goto("http://localhost:3000", { waitUntil: "networkidle" })
    assert.equal(await page.getByRole("heading", { name: "Your projects" }).count(), 1)
    await page.screenshot({ path: path.resolve("tmp/projects-desktop.png"), fullPage: true })
    await page.getByRole("link").filter({ has: page.getByRole("heading", { name: "Legacy workspace" }) }).click()
    await page.locator("#project-switcher").waitFor()
    assert.match(await page.locator(".workspace-strip").innerText(), /Legacy workspace/)
    await page.screenshot({ path: path.resolve("tmp/project-chat-desktop.png"), fullPage: true })
    await page.setViewportSize({ width: 390, height: 844 })
    await page.getByRole("link", { name: "ALL PROJECTS", exact: true }).click()
    const form = page.locator(".project-form").filter({ has: page.getByRole("heading", { name: "Open existing folder" }) })
    await form.getByLabel("Project name").fill("Invalid smoke test")
    await form.getByLabel("Absolute folder path").fill("relative")
    await form.getByRole("button", { name: "Open folder" }).click()
    await page.getByRole("alert").waitFor()
    assert.match(await page.getByRole("alert").innerText(), /absolute/)
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth))
    await page.screenshot({ path: path.resolve("tmp/projects-mobile.png"), fullPage: true })
    assert.deepEqual(errors, [])
    console.log("Browser smoke passed: project list, chat, mobile navigation, invalid path, no JS errors")
  } finally {
    await browser.close()
  }
})().catch(error => { console.error(error); process.exitCode = 1 })
