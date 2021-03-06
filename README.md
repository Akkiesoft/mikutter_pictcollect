# mikutter_pictcollect

## なにこれ

ツイートの画像を特定の場所に保存するプラグインです。

+ twitterにアップロードされた画像をオリジナルサイズ(:orig)で保存
+ Worldonにアップロードされた画像を保存
+ 画像の拡張子が付いている別のドメインの画像も保存を試みる

## インストール

```
$ mkdir -p ~/.mikutter/plugin/pictcollect; git clone https://github.com/Akkiesoft/mikutter_pictcollect ~/mikutter/plugin/pictcollect
```

## つかいかた

1. プラグインをインストロールします
2. 設定画面の「画像これくしょん」で、画像の保存先ディレクトリを指定します
3. 「画像をコレクションする」コマンドをショートカットキーを割り当てます
4. 画像ツイートを選択してショートカットを実行
5. これであなたも爽やかておくれライフ

## まとめて画像これくしょん

Postboxに改行区切りでツイートのURL(もしくはツイートID)を入力して「まとめて画像これくしょん」コマンドを実行すると、ツイートの画像をまとめて保存できます。
この機能はTwitterでのみ有効です。

## アカウントごとにディレクトリを作成

絵師さんごとに画像を仕分けたいときに便利なオプションです。

Twitter以外のWorldでは「!SNS名」ディレクトリ以下にアカウントのディレクリが作成されます（この仕様は変更される可能性があります）。

## 参考にしたりパクったりした

このプラグインはmogunoさんの[mikutter-sub-parts-image][subparts-image]からだいたいパクりました。
その他のパクリどころはコメントで書いてます。感謝。

[subparts-image]: https://github.com/moguno/mikutter-subparts-image
