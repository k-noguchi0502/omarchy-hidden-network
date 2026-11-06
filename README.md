# 非公開ネットワーク

SSID を放送しない Wi-Fi を追加して接続する Omarchy のバープラグインです。パスワードはコマンドラインに載せず、`nmcli` の標準入力へ渡します。

プラグイン ID は `knoguchi.hidden-network` です。

## このプラグインだけ入れる

```bash
omarchy plugin add https://github.com/k-noguchi0502/omarchy-hidden-network.git --enable --yes
```

`--enable --yes` はマニフェストの既定どおりトレイに置きます。置き場所を変えるときは次です。

```bash
omarchy plugin enable knoguchi.hidden-network --section tray
```

## いま使っている他のプラグインも入れる

このリポジトリの `extras/` に、別の PC へ同じプラグイン一式を入れるスクリプトがあります。上流の公開リポジトリを `omarchy plugin add` し、この PC で当たっている差分だけをパッチとして適用します。

```bash
omarchy plugin add https://github.com/k-noguchi0502/omarchy-hidden-network.git --enable --yes
bash ~/.config/omarchy/plugins/knoguchi.hidden-network/extras/install-added-plugins.sh
```

| プラグイン | 入手元 | この PC での変更 |
| --- | --- | --- |
| `glorics.grok-bot` | [glorics/omarchy-grok-bot](https://github.com/glorics/omarchy-grok-bot) | なし。右セクション |
| `io.github.badr-emil.display-layout` | [Badr-Emil/omarchy-display-layout](https://github.com/Badr-Emil/omarchy-display-layout) | なし。右セクション |
| `io.github.jeremydixon22.screensafe` | [jeremydixon22/omarchy-screensafe](https://github.com/jeremydixon22/omarchy-screensafe) | なし。トレイ、待機中に orbits パック |
| `vinicgobbi.power` | [vinicgobbi/omarchy-plugin-power](https://github.com/vinicgobbi/omarchy-plugin-power) | 電源操作のコマンド名を現在の `omarchy system` に合わせ、確認あり |
| `hello-lock` | [denonmaryland/hello-lock](https://github.com/denonmaryland/hello-lock) | 復帰直後に画面を消さない。標準の `omarchy.lock` は無効 |
| `matheustimbo.overview` | [matheustimbo/omarchy-overview](https://github.com/matheustimbo/omarchy-overview) | 開いた直後、ポインタが動くまで選択を現在のワークスペースに保つ |
| `typecraft.omacast` | [typecraft-dev/oma-cast](https://github.com/typecraft-dev/oma-cast) | 起動ランチャーの手元の調整と英日の文言 |

パッチは各リポジトリの記録したコミットに対するものです。上流が進んでパッチが当たらないときは、スクリプトがそのプラグインを飛ばして理由を出します。コード自体は各作者のライセンス（いずれも MIT）のままです。

Superwhisper のパネルはアプリ本体 (`/opt/superwhisper`) が置くものなので、このリポジトリには入っていません。
