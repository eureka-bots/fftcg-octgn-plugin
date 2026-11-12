# OCTGN版 FF TCG（日本語版）の導入手順

このガイドでは、OCTGNにFFTCGのゲームプラグインと日本語カード画像をインストールする方法を説明します。OCTGN本体がまだインストールされていない場合は、[OCTGN公式サイト](https://www.octgn.net/)から先にインストールしてください。

ゲームプラグインとカード画像パックは別々のファイルです。両方をインストールしてください。

## 1. ゲームプラグイン（`.nupkg`）をダウンロードする

最新の `.nupkg` ファイルを、次のいずれかからダウンロードしてください。

- [配布用Google Driveフォルダー](https://drive.google.com/drive/u/0/folders/1-iuTjSH1AWa7XC_9IeIV9d697vBoAuYd)
- [GitHub Releases](https://github.com/eureka-bots/fftcg-octgn-plugin/releases)

`.nupkg` ファイルは展開したり、拡張子を変更したりしないでください。

## 2. `.nupkg` をOCTGNにインストールする

1. OCTGNを終了します。
2. エクスプローラーのアドレス欄に `%USERPROFILE%\Documents\OCTGN\LocalFeed` と入力して開きます。フォルダーが存在しない場合は作成してください。
3. ダウンロードした `.nupkg` ファイルを `LocalFeed` フォルダーにコピーします。
4. OCTGNを起動し、**Games Manager** タブを開きます。一時的にフリーズすることがありますが、読み込みに時間がかかっているだけです。終わるまで待ちましょう。
5. 左上のフィード選択欄から **Local (Developers)** を選びます。
6. 一覧から **Final Fantasy TCG** を選び、**Install** をクリックします。

## 3. 日本語カード画像パックをインストールする

1. [配布用Google Driveフォルダー](https://drive.google.com/drive/u/0/folders/1-iuTjSH1AWa7XC_9IeIV9d697vBoAuYd)を開き、日本語（`ja`）用の `.o8c` ファイルをダウンロードします。英語（`en`）用ではなく、日本語用を選んでください。
2. OCTGNの **Games Manager** タブで **Add Image Packs** をクリックします。
3. ダウンロードした日本語の `.o8c` ファイルを選択し、インストールが完了するまで待ちます。

画像パックは展開せず、そのまま **Add Image Packs** から読み込んでください。

## インストールできない場合

- **Local (Developers) にゲームが表示されない場合:** `.nupkg` が `Documents\OCTGN\LocalFeed` にあることを確認し、OCTGNを再起動してください。Windowsの設定で「ドキュメント」フォルダーが別の場所に移動されている場合は、その場所の `OCTGN\LocalFeed` にコピーしてください。
- **カード画像が表示されない場合:** 日本語（`ja`）の `.o8c` を選び、**Add Image Packs** から読み込んだことを確認してください。
