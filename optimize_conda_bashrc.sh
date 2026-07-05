#!/usr/bin/env bash
#
# optimize_conda_bashrc.sh
#
# conda install 直後の ~/.bashrc に対して、bash起動を高速化する2つの最適化を適用する:
#   1. auto_activate_base を false に設定 (base自動アクティベートの3秒前後を削減)
#   2. `conda shell.bash hook` の動的呼び出しをキャッシュファイル読み込みに置換
#      (Python起動を伴うhook生成の3秒前後を削減)
#
# 使い方:
#   bash optimize_conda_bashrc.sh
#
# 冪等性: 既に最適化済みの場合は何もしない(再実行しても安全)。
# 安全策: 実行前に ~/.bashrc を ~/.bashrc.bak.<timestamp> にバックアップする。

set -euo pipefail

BASHRC="$HOME/.bashrc"
MARKER="# --- conda hook cache optimization (applied by optimize_conda_bashrc.sh) ---"

# --- 0. 前提チェック ---
if [ ! -f "$BASHRC" ]; then
    echo "エラー: $BASHRC が見つかりません。" >&2
    exit 1
fi

if ! command -v conda >/dev/null 2>&1; then
    echo "エラー: conda コマンドが見つかりません。先にconda(miniforge3等)をインストールしてください。" >&2
    exit 1
fi

CONDA_BIN="$(command -v conda)"
echo "検出したconda: $CONDA_BIN"

# 既に適用済みなら終了
if grep -qF "$MARKER" "$BASHRC"; then
    echo "既に最適化済みです。何もしません。"
    exit 0
fi

# --- 1. バックアップ ---
BACKUP="$HOME/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
cp "$BASHRC" "$BACKUP"
echo "バックアップ作成: $BACKUP"

# --- 2. auto_activate_base を無効化 ---
conda config --set auto_activate_base false
echo "auto_activate_base を false に設定しました。"

# --- 3. .bashrc内の既存 conda initialize ブロックを検出して置換 ---
#    conda init が生成する典型的なブロックは以下のマーカーで囲まれている:
#      # >>> conda initialize >>>
#      ...
#      # <<< conda initialize <<<
START_MARK="# >>> conda initialize >>>"
END_MARK="# <<< conda initialize <<<"

if grep -qF "$START_MARK" "$BASHRC"; then
    # 既存ブロックを削除(sedで範囲削除)してから、新ブロックを末尾に追記
    sed -i "/${START_MARK}/,/${END_MARK}/d" "$BASHRC"
    echo "既存の conda initialize ブロックを検出し、削除しました。"
else
    echo "既存の conda initialize ブロックは見つかりませんでした。新規追加します。"
fi

# --- 4. hookキャッシュ化ブロックを追記 ---
cat >> "$BASHRC" <<EOF

${MARKER}
# Cache the output of \`conda shell.bash hook\` instead of invoking it
# on every login shell (avoids a multi-second Python startup cost).
# Cache is regenerated automatically whenever the conda binary is
# newer than the cache file (e.g. after a conda self-update).
__conda_hook_cache="\$HOME/.conda_hook_cache.sh"
__conda_bin="${CONDA_BIN}"

if [ ! -f "\$__conda_hook_cache" ] || [ "\$__conda_bin" -nt "\$__conda_hook_cache" ]; then
    "\$__conda_bin" shell.bash hook > "\$__conda_hook_cache" 2>/dev/null
fi
. "\$__conda_hook_cache"

unset __conda_hook_cache __conda_bin
# --- end conda hook cache optimization ---
EOF

echo ""
echo "完了しました。"
echo "  - バックアップ: $BACKUP"
echo "  - 変更内容確認: tail -n 20 $BASHRC"
echo "  - 反映確認: exec bash  (もしくは新しいターミナルを開く)"
echo ""
echo "補足: 今後 conda を自己アップデートした場合、"
echo "      キャッシュは conda バイナリより古ければ自動で再生成されます。"
echo "      手動で強制再生成したい場合は次を実行してください:"
echo "        rm -f \$HOME/.conda_hook_cache.sh && exec bash"
