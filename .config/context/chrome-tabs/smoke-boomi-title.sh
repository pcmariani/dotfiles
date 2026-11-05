#!/bin/bash
# Checks for boomi-title.user.js: the pure rewrite rule, then the producer reading what it writes.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
node - "$HERE" <<'JS'
const { rewrite } = require(process.argv[2] + "/boomi-title.user.js");
let fails = 0;
function check(name, got, want) {
  if (got !== want) { fails++; console.error(`FAIL: ${name}: got ${JSON.stringify(got)}, want ${JSON.stringify(want)}`); }
  else console.log(`   ok: ${name}`);
}
check("page first, account after", rewrite("CSC Sugar, LLC - Process Reporting - Boomi Enterprise Platform"), "Process Reporting — CSC Sugar, LLC");
check("a page with its own dash keeps it", rewrite("CSC Sugar, LLC - Settings - User Management - Boomi Enterprise Platform"), "Settings - User Management — CSC Sugar, LLC");
check("two parts are left alone", rewrite("Build - Boomi Enterprise Platform"), null);
check("a title not ending in the product is left alone", rewrite("A - B - Something Else"), null);
check("an empty part is left alone", rewrite("A -  - Boomi Enterprise Platform"), null);
check("an already rewritten title is left alone", rewrite("Process Reporting — CSC Sugar, LLC"), null);
check("a plain title is left alone", rewrite("Process Reporting"), null);
check("an empty title is left alone", rewrite(""), null);
if (fails) process.exit(1);
console.log("all boomi-title checks passed");
JS
