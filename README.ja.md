<p align="center">
  <img src="docs/icon.png" alt="ThockYou" width="128" height="128">
</p>

<h1 align="center">ThockYou</h1>

<p align="center">
  キー入力に合わせてメカニカルキーボード風のタイピング音を鳴らす macOS アプリ。
</p>

<p align="center">
  <a href="README.md">English</a> ・ <strong>日本語</strong>
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-blue">
  <img alt="Swift" src="https://img.shields.io/badge/swift-6.0-orange">
</p>

---

メニューバーから常駐し、グローバルな key down イベントに合わせてサンプリング音源を `AVAudioEngine` で低遅延に再生します。Mechvibes 互換のアトラス形式サウンドパックを同梱しており、好みのスイッチ音に切り替えられます。

## 機能

- メニューバー常駐／設定画面から有効化・停止
- 全アプリ横断のキーボード監視
- `AVAudioEngine` + プレイヤノードプールによる低遅延再生
- 同梱サウンドパック
  - CherryMX Black / Blue / Brown / Red - PBT keycaps
  - Everglide Oreo
  - Everglide Crystal Purple
- 任意の音声フォルダを独自サウンドパックとして読み込み
- 音量・ピッチの揺らぎを調整

## 必要環境

- macOS 13 以降
- Swift 6 / Xcode Command Line Tools

## ビルドと起動

`.app` を作って起動するのが推奨です。`swift run` だとアクセシビリティ権限が Terminal 側に紐づくため。

```bash
make open
```

内部で `Scripts/build_app.sh` がビルドし、`Resources/` を bundle にコピーし、ローカル用の ad-hoc 署名を付けます。配布する場合は別途 Developer ID 署名と notarization が必要です。

手動でビルドだけしたい場合：

```bash
swift build
# または
./Scripts/build_app.sh
open .build/ThockYou.app
```

## アクセシビリティ権限

全アプリのキー入力イベントを受け取るため、システム設定の「プライバシーとセキュリティ > アクセシビリティ」で許可が必要です。読み取るのは key down イベントのメタデータのみで、入力文字列の保存・送信は行いません。

許可後は設定画面の「再確認」を押すか、アプリを再起動してください。旧ビルドの `Thockyou` がアクセシビリティ一覧に残っている場合は削除し、新しい `ThockYou` を許可してください。

## カスタムサウンドパック

短い `.wav`, `.aiff`, `.caf`, `.m4a`, `.mp3` ファイルを含むフォルダを読み込めます。キー入力ごとに、該当するファイルからランダムに1つ再生します。

ファイル名に以下の単語を含めると特殊キー用として扱われます。

- `space`
- `enter` または `return`
- `delete` または `backspace`
- `shift`, `cmd`, `command`, `control`, `option`, `alt`

上記を含まないファイルは通常キー用の音として使われます。

Mechvibes 形式（単一音声 + `config.json`）のアトラス形式パックも `Resources/SoundPacks/` に配置すれば追加できます。`SoundPack.swift` の `SoundPackCatalog` にエントリを足してください。

## 謝辞

同梱の音源パックと設定 JSON は [Mechvibes](https://github.com/hainguyents13/mechvibes)（MIT License, Copyright (c) 2021 Hai Nguyen）由来です。素晴らしい音源を公開してくれているプロジェクトに感謝します。

## ライセンス

ThockYou 本体は MIT License で配布しています。詳細は [`LICENSE`](LICENSE) を参照してください。

同梱の音源パック（`Resources/SoundPacks/`）も MIT License の下で再配布しています。出典と全文は [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) を参照してください。

Cherry MX は Cherry GmbH、Everglide はそれぞれの権利者の商標です。ThockYou はこれらの企業と提携・関連していません。製品名は対応するスイッチ音源を識別する目的でのみ使用しています。
