# Memory Spots 現状整理と次フェーズ計画

Last updated: 2026-06-07

## 1. 現在の到達点

当初の「写真と地図を使って記憶空間を作る」フェーズは、MVPとしてかなり進んでいます。

実装済みの主な内容:

- MapKit の Memory Map
- 位置情報付き `MemoryPhoto` のサムネイルピン表示
- ピンタップ時の写真プレビューカード
- プレビューから `PhotoEditorView` とアルバム詳細への遷移
- アルバム/テーマによる地図フィルタ
- ライブラリ写真の位置情報メタデータ取得
- カメラ撮影時の現在地保存
- 後から地図で場所を追加/変更/削除する `LocationEditorView`
- HomeView のタブ化: Memory Map と Albums
- テーマチップ UI
- 写真上の視覚メモ: 付箋、画像、アイコン、番号、矢印
- 写真編集時のズーム/パン
- 初回チュートリアル
- グローバル向けシードデータ: My Room、Desk Setup、Local Park、Grocery List

## 2. MVP の体験方針

Memory Spots は、資格勉強だけに閉じた暗記アプリではなく、自分の場所に覚えたいことを置いていく小さな記憶ノートです。

大切にすること:

- 写真が主役であること
- 地図から始めても、アルバムから始めても迷わないこと
- テーマで同じ道順を使い回せること
- 視覚メモを置く操作が軽いこと
- 復習は高度な成績管理よりも、写真の中の場所を思い出す体験を優先すること

## 3. 残っている改善候補

### 3.1 レビュー体験の磨き込み

現在のレビューは「写真を順番に表示し、メモをタップして答えを出す」形です。MVPとしては十分ですが、次の改善余地があります。

- 覚えた/微妙/忘れた の簡易結果を復活させるか判断する
- スワイプやボタンで結果を記録する
- 結果履歴を表示する場合は、学習統計アプリになりすぎない表現にする
- 置いた場所を思い出してから答えを見る流れをより明確にする

### 3.2 ローカリゼーションの仕上げ

String Catalogs と InfoPlist の 8 言語対応は導入済みです。次は品質確認です。

- 日本語、ドイツ語、フランス語、韓国語、ヒンディー語で主要画面をスポット確認する
- 長い翻訳がボタンやチップからはみ出さないか確認する
- App Store スクリーンショット用の表示言語を決める
- 「Memory Map」「Albums」「Themes」「Notes」などの用語を揃える

### 3.3 App Store 提出準備

公開に必要な文書と URL は `docs/` にあります。GitHub Pages の URL を App Store Connect に設定します。

- Support URL: `https://nfnat0.github.io/memory-spots/support.html`
- Privacy Policy URL: `https://nfnat0.github.io/memory-spots/privacy.html`
- Marketing URL: `https://nfnat0.github.io/memory-spots/`

残作業:

- GitHub Pages の公開確認
- iPhone 17 Pro などでのリリースビルド確認
- App Store 用スクリーンショット撮影
- App Privacy 回答の最終確認
- 審査メモの記入

## 4. まだやらないこと

MVP の焦点を保つため、以下は引き続き対象外です。

- Street View
- AR
- Google Maps SDK
- 高度な SRS
- 正答率ダッシュボード
- 苦手メモ抽出
- 学習統計
- 課金
- 共有機能
- iCloud 同期
- AI 自動配置

## 5. 推奨実装順

1. GitHub Pages の公開確認
2. App Store メタデータとスクリーンショットの最終化
3. 優先ロケールで UI の表示崩れ確認
4. レビュー結果記録を入れるかどうかの仕様判断
5. 入れる場合のみ、最小限の `ReviewResult` UI を実装

## 6. 受け入れ条件

- Memory Map から位置情報付き写真を確認できる
- 地図上の写真ピンから写真編集画面に移動できる
- 写真追加時に位置情報を保存できる
- 位置情報がない写真にも後から場所を設定できる
- 写真上に複数種類の視覚メモを置ける
- 同じ写真でもテーマごとに別のメモを表示できる
- 公開サポート URL とプライバシーポリシー URL が App Store Connect に使える
