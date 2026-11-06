#!/bin/bash
# Install the other Omarchy plugins used with knoguchi.hidden-network,
# then apply the local patches shipped in extras/patches/.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PATCHES="$ROOT/extras/patches"
PLUGINS="$HOME/.config/omarchy/plugins"
SHELL_JSON="$HOME/.config/omarchy/shell.json"

fail() {
  echo "install-added-plugins: $*" >&2
  exit 1
}

[[ -f $SHELL_JSON ]] || fail "missing $SHELL_JSON"

add_plugin() {
  local url=$1 id=$2
  if [[ -d $PLUGINS/$id ]]; then
    echo "already installed: $id"
    return 0
  fi
  omarchy plugin add "$url" --yes
}

apply_patch() {
  local id=$1 rev=$2 patch=$3
  local dir=$PLUGINS/$id
  [[ -d $dir/.git ]] || fail "$id has no git checkout"
  if git -C "$dir" apply --reverse --check "$patch" >/dev/null 2>&1; then
    echo "already patched: $id"
    return 0
  fi
  if [[ -n $(git -C "$dir" status --porcelain) ]]; then
    echo "skipped $id: the checkout already has other local changes" >&2
    return 0
  fi
  if ! git -C "$dir" cat-file -e "${rev}^{commit}" >/dev/null 2>&1; then
    if ! git -C "$dir" fetch --quiet origin "$rev"; then
      echo "skipped $id: commit $rev is not in the clone" >&2
      return 0
    fi
  fi
  git -C "$dir" checkout --detach --quiet "$rev"
  if ! git -C "$dir" apply --check "$patch"; then
    echo "skipped $id: patch does not apply on $rev" >&2
    return 0
  fi
  git -C "$dir" apply "$patch"
  echo "patched $id"
}

in_shell() {
  local id=$1
  jq -e --arg id "$id" '
    (
      [.plugins[]?.id] +
      [.bar.layout[]?[]?.id]
    ) | index($id) != null
  ' "$SHELL_JSON" >/dev/null
}

enable_plugin() {
  local id=$1
  shift
  if in_shell "$id"; then
    echo "already enabled: $id"
    return 0
  fi
  omarchy plugin enable "$id" "$@"
}

add_plugin https://github.com/glorics/omarchy-grok-bot.git glorics.grok-bot
add_plugin https://github.com/Badr-Emil/omarchy-display-layout.git io.github.badr-emil.display-layout
add_plugin https://github.com/jeremydixon22/omarchy-screensafe.git io.github.jeremydixon22.screensafe
add_plugin https://github.com/vinicgobbi/omarchy-plugin-power.git vinicgobbi.power
add_plugin https://github.com/denonmaryland/hello-lock.git hello-lock
add_plugin https://github.com/matheustimbo/omarchy-overview.git matheustimbo.overview
add_plugin https://github.com/typecraft-dev/oma-cast.git typecraft.omacast

apply_patch vinicgobbi.power bb29c1d1e8976f7e6a79a43cad72b3dff6ecec20 "$PATCHES/power.patch"
apply_patch hello-lock 1959e1ff99785df6fabf47a9853ea43950ce711d "$PATCHES/hello-lock.patch"
apply_patch matheustimbo.overview 7a05ba8564ce31f62d8b4f6195f6777d39bf82ab "$PATCHES/overview.patch"
apply_patch typecraft.omacast 98bd0bb1cd1adf787afc704ff31f951d3c938708 "$PATCHES/omacast.patch"

omarchy-shell shell rescanPlugins >/dev/null

enable_plugin glorics.grok-bot --section right
enable_plugin io.github.badr-emil.display-layout --section right
enable_plugin vinicgobbi.power --section right
enable_plugin io.github.jeremydixon22.screensafe --section tray
enable_plugin hello-lock
enable_plugin matheustimbo.overview
enable_plugin typecraft.omacast
if jq -e '(.disabledPlugins // []) | index("omarchy.lock") != null' "$SHELL_JSON" >/dev/null; then
  echo "already disabled: omarchy.lock"
else
  omarchy plugin disable omarchy.lock
fi

pack="$PLUGINS/io.github.jeremydixon22.screensafe/packs/orbits"
tmp=$(mktemp)
jq --arg pack "$pack" '
  .bar.layout.tray |= map(
    if .id == "io.github.jeremydixon22.screensafe" then . + {onIdle: true, pack: $pack} else . end
  )
  | .bar.layout.right |= map(
    if .id == "vinicgobbi.power" then . + {confirm: true} else . end
  )
' "$SHELL_JSON" > "$tmp"
mv "$tmp" "$SHELL_JSON"

echo "Added plugins are installed. Hidden Network stays knoguchi.hidden-network."
