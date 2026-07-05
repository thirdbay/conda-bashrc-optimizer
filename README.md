# conda-bashrc-optimizer

miniforge3 / Anaconda / Miniconda インストール後の `.bashrc` に対して、bash起動を高速化する2つの最適化を自動適用するスクリプトです。

## これは何をするか

`conda init` で生成される標準の `.bashrc` は、ログインシェルを開くたびに以下の重い処理を実行します。

1. `conda shell.bash hook` の動的呼び出し（Pythonインタプリタ起動を伴う。数秒かかることがある）
2. `conda activate base` によるbase環境の自動アクティベート（さらに数秒）

このスクリプトは以下の2つの最適化を適用し、シェル起動時間を大幅に短縮します（手元の環境では **約8秒 → 約0.9秒** まで改善）。

1. `conda config --set auto_activate_base false` を実行し、base自動アクティベートを無効化
2. `conda shell.bash hook` の出力を `~/.conda_hook_cache.sh` にキャッシュし、以降は動的呼び出しの代わりにこのファイルを読み込むよう `.bashrc` を書き換え

キャッシュは、condaバイナリの更新日時がキャッシュファイルより新しい場合（＝condaを自己アップデートした場合など）は自動的に再生成されます。

## 使い方

新しいLinuxマシンでconda（miniforge3など）をインストールした直後に実行してください。

```bash
bash optimize_conda_bashrc.sh
```

## 安全設計

- **冪等性**: 既に最適化済みの場合は何もしません（再実行しても安全）
- **自動バックアップ**: 実行前に `~/.bashrc` を `~/.bashrc.bak.<タイムスタンプ>` として保存します
- **conda検出**: `command -v conda` を使うため、miniforge3以外のインストールパスでも動作します

## 反映確認

```bash
exec bash
```

または新しいターミナルを開いてください。

## 元に戻したい場合

```bash
cp ~/.bashrc.bak.<タイムスタンプ> ~/.bashrc
rm -f ~/.conda_hook_cache.sh
exec bash
```

## なぜこの最適化が必要か（背景）

`conda shell.bash hook` は、`conda activate` のようにシェル自身の環境変数やPS1を書き換えるために必要な、bash関数一式を動的に生成するコマンドです。しかしcondaは内部的にPythonで実装されているため、このコマンド自体の実行に毎回Python起動のコストがかかります。フックの中身はcondaのバージョンとインストールパスが変わらない限りほぼ固定なので、キャッシュ化による高速化が有効です。

なお、これは公式のcondaが提供する仕組みではなく、コミュニティで長年report・workaroundされてきた既知の問題への対処です（[conda/conda#7855](https://github.com/conda/conda/issues/7855) など）。

## ライセンス

MIT License
