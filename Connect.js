// Validation and display shaping for the hidden-network panel.
// The connect script is fixed; the SSID and security travel as argv, and the
// passphrase travels on stdin. Nothing here interpolates them into a command.

function utf8Length(value) {
  var text = String(value == null ? "" : value)
  var bytes = 0
  for (var i = 0; i < text.length; i++) {
    var code = text.charCodeAt(i)
    if (code >= 0xD800 && code <= 0xDBFF) {
      bytes += 4
      i++
    } else if (code < 0x80) {
      bytes += 1
    } else if (code < 0x800) {
      bytes += 2
    } else {
      bytes += 3
    }
  }
  return bytes
}

function hasControl(value) {
  return /[\u0000-\u001F\u007F]/.test(String(value == null ? "" : value))
}

function securityMode(security) {
  if (security === "open" || security === "wpa-psk" || security === "sae") return security
  return ""
}

function validate(ssid, password, security) {
  var raw = String(ssid == null ? "" : ssid)
  var secret = String(password == null ? "" : password)
  var mode = securityMode(security)
  if (mode === "") return { ok: false, reason: "hidden.failed" }
  if (hasControl(raw)) return { ok: false, reason: "hidden.needSsid" }
  var name = raw.trim()
  if (name === "") return { ok: false, reason: "hidden.needSsid" }
  if (utf8Length(name) > 32) return { ok: false, reason: "hidden.ssidTooLong" }
  if (mode !== "open") {
    if (secret === "" || hasControl(secret)) return { ok: false, reason: "hidden.needPassword" }
    var hexPsk = /^[0-9a-fA-F]{64}$/.test(secret)
    if (!hexPsk && (secret.length < 8 || secret.length > 63)) return { ok: false, reason: "hidden.passwordLength" }
  }
  return { ok: true, ssid: name, security: mode }
}

// Bound text before it is shown. Markup stays literal data; callers that
// display it set Text.PlainText. Shared tooltips never receive this.
function plain(value, limit) {
  var cap = Math.max(0, parseInt(limit, 10) || 0)
  var text = String(value == null ? "" : value).replace(/[\u0000-\u001F\u007F]/g, " ").replace(/\s+/g, " ").trim()
  if (cap > 0 && text.length > cap) text = text.slice(0, cap).trim()
  return text
}

function outcome(exitCode, stderr, stdout) {
  var code = Number(exitCode)
  if (code === 0) return { ok: true, key: "hidden.connected", detail: "" }
  if (code === 3) return { ok: false, key: "hidden.noDevice", detail: "" }
  var detail = plain(stderr || stdout || "", 180)
  if (detail !== "") return { ok: false, key: "", detail: detail }
  return { ok: false, key: "hidden.failed", detail: "" }
}

if (typeof module !== "undefined") {
  module.exports = {
    utf8Length: utf8Length,
    validate: validate,
    plain: plain,
    outcome: outcome
  }
}
