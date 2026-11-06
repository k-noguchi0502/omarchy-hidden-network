const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("fs")
const os = require("os")
const path = require("path")
const { execFileSync } = require("child_process")

const root = path.join(__dirname, "..")
const Connect = require("../Connect.js")
const scriptPath = path.join(root, "scripts", "connect-hidden")
const panel = fs.readFileSync(path.join(root, "Panel.qml"), "utf8")
const markup = '<img src="https://example.invalid/tracker">'

test("ssid and passphrase bounds", () => {
  assert.equal(Connect.validate("", "password1", "wpa-psk").reason, "hidden.needSsid")
  assert.equal(Connect.validate("cafe\n", "password1", "wpa-psk").reason, "hidden.needSsid")
  assert.equal(Connect.validate("a".repeat(33), "password1", "wpa-psk").reason, "hidden.ssidTooLong")
  assert.equal(Connect.validate("カフェ", "short", "wpa-psk").reason, "hidden.passwordLength")
  assert.equal(Connect.validate("カフェ", "", "open").ok, true)
  assert.equal(Connect.utf8Length("カフェ"), 9)

  const named = Connect.validate("  cafe  ", "password1", "wpa-psk")
  assert.equal(named.ok, true)
  assert.equal(named.ssid, "cafe")
  assert.equal(named.security, "wpa-psk")
  assert.equal(Connect.validate("cafe", "ab".repeat(32), "sae").ok, true)
})

test("markup-shaped names stay literal data", () => {
  const tag = "<img src=\"x\">"
  const named = Connect.validate(tag, "password1", "wpa-psk")
  assert.equal(named.ok, true)
  assert.equal(named.ssid, tag)
  assert.equal(Connect.validate(markup, "password1", "wpa-psk").reason, "hidden.ssidTooLong")

  const noise = markup + " " + "x".repeat(400)
  const shown = Connect.plain(noise, 180)
  assert.equal(shown.startsWith(markup), true)
  assert.ok(shown.length <= 180)
  assert.equal(shown.includes("\n"), false)
})

test("command output is bounded and not treated as success", () => {
  const result = Connect.outcome(1, markup + "\nbad password\n", "")
  assert.equal(result.ok, false)
  assert.equal(result.detail, markup + " bad password")
  assert.equal(Connect.outcome(0, markup, "").key, "hidden.connected")
  assert.equal(Connect.outcome(3, "", "").key, "hidden.noDevice")
  assert.equal(Connect.outcome(1, "", "").key, "hidden.failed")
})

test("status text is plain and the passphrase is not a command argument", () => {
  assert.match(panel, /id: statusText[\s\S]*textFormat: Text\.PlainText/)
  assert.match(panel, /command = \["bash", scriptPath, check\.ssid, check\.security\]/)
  assert.doesNotMatch(panel, /command = \[[^\]]*passwordField/)
  assert.match(panel, /write\(secret/)
})

test("script syntax", () => {
  execFileSync("bash", ["-n", scriptPath])
})

function fakeNmcli(log) {
  return `#!/bin/bash
printf 'CMD' >> ${JSON.stringify(log)}
printf ' %q' "$@" >> ${JSON.stringify(log)}
printf '\\n' >> ${JSON.stringify(log)}
if [[ $1 == -t && $3 == DEVICE,TYPE,STATE ]]; then
  echo "wlan0:wifi:connected"
  exit 0
fi
if [[ $1 == -t && $3 == DEVICE,TYPE ]]; then
  echo "wlan0:wifi"
  exit 0
fi
if [[ $1 == -t && $3 == UUID,TYPE ]]; then
  exit 0
fi
if [[ $1 == connection && $2 == edit ]]; then
  printf 'STDIN ' >> ${JSON.stringify(log)}
  cat >> ${JSON.stringify(log)}
  exit 0
fi
exit 0
`
}

function runScript(ssid, security, password) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "hidden-wifi-"))
  const log = path.join(dir, "log")
  fs.writeFileSync(path.join(dir, "nmcli"), fakeNmcli(log), { mode: 0o755 })
  fs.writeFileSync(log, "")
  let status = 0
  let stderr = ""
  try {
    execFileSync("bash", [scriptPath, ssid, security], {
      input: password + "\n",
      encoding: "utf8",
      env: { ...process.env, PATH: dir + ":" + process.env.PATH }
    })
  } catch (error) {
    status = error.status
    stderr = error.stderr || ""
  }
  return { status, stderr, logged: fs.readFileSync(log, "utf8") }
}

test("hidden profile is saved without putting the passphrase on argv", () => {
  const password = 'p@ss"w\\ord'
  const result = runScript("cafe", "wpa-psk", password)
  assert.equal(result.status, 0, result.stderr + result.logged)
  const commands = result.logged.split("\n").filter((line) => line.startsWith("CMD"))
  assert.equal(commands.some((line) => line.includes(password)), false)
  assert.match(result.logged, /wifi\.hidden/)
  assert.match(result.logged, /yes/)
  assert.match(result.logged, /STDIN set wifi-sec\.psk "p@ss\\"w\\\\ord"/)
  assert.match(result.logged, /connection up/)
})

test("markup in the passphrase is passed as editor data", () => {
  const password = markup + "xxxx"
  const result = runScript("cafe", "wpa-psk", password)
  assert.equal(result.status, 0, result.logged)
  const commands = result.logged.split("\n").filter((line) => line.startsWith("CMD"))
  assert.equal(commands.some((line) => line.includes("<img")), false)
  assert.match(result.logged, /STDIN set wifi-sec\.psk "<img src=\\"https:\/\/example\.invalid\/tracker\\">xxxx"/)
})

test("open network stores no passphrase", () => {
  const result = runScript("cafe", "open", "")
  assert.equal(result.status, 0, result.logged)
  assert.equal(result.logged.includes("STDIN"), false)
  assert.match(result.logged, /wifi\.hidden/)
})

test("missing wifi device is reported and does not activate a profile", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "hidden-wifi-"))
  const log = path.join(dir, "log")
  fs.writeFileSync(path.join(dir, "nmcli"), "#!/bin/bash\nprintf 'CMD %s\\n' \"$*\" >> " + JSON.stringify(log) + "\nexit 0\n", { mode: 0o755 })
  fs.writeFileSync(log, "")
  let status = 0
  try {
    execFileSync("bash", [scriptPath, "cafe", "wpa-psk"], {
      input: "password1\n",
      encoding: "utf8",
      env: { ...process.env, PATH: dir + ":" + process.env.PATH }
    })
  } catch (error) {
    status = error.status
  }
  assert.equal(status, 3)
  assert.equal(fs.readFileSync(log, "utf8").includes("connection up"), false)
})
