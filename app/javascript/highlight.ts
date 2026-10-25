import hljs from "highlight.js/lib/core"
import ruby from "highlight.js/lib/languages/ruby"
import javascript from "highlight.js/lib/languages/javascript"
import typescript from "highlight.js/lib/languages/typescript"
import xml from "highlight.js/lib/languages/xml"
import erb from "highlight.js/lib/languages/erb"
import css from "highlight.js/lib/languages/css"
import json from "highlight.js/lib/languages/json"
import yaml from "highlight.js/lib/languages/yaml"
import markdown from "highlight.js/lib/languages/markdown"
import bash from "highlight.js/lib/languages/bash"
import sql from "highlight.js/lib/languages/sql"

for (const [name, grammar] of Object.entries({ ruby, javascript, typescript, xml, erb, css, json, yaml, markdown, bash, sql })) hljs.registerLanguage(name, grammar)

export function highlightFile(element: HTMLElement, path: string, content: string) {
  const name = path.split("/").pop() || ""
  const extension = name.split(".").pop()?.toLowerCase() || ""
  const languages: Record<string, string> = { rb: "ruby", rake: "ruby", ru: "ruby", erb: "erb", js: "javascript", jsx: "javascript", ts: "typescript", tsx: "typescript", html: "xml", css: "css", scss: "css", json: "json", yml: "yaml", yaml: "yaml", md: "markdown", sh: "bash", sql: "sql" }
  const language = ["Gemfile", "Rakefile"].includes(name) ? "ruby" : languages[extension]
  element.textContent = content
  delete element.dataset.highlighted
  element.className = language ? `hljs language-${language}` : "hljs"
  if (language) hljs.highlightElement(element)
}
