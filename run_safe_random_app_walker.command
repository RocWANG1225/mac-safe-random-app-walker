#!/bin/zsh
script_dir="$(cd "$(dirname "$0")" && pwd)"
script_file="$script_dir/safe_random_app_walker.swift"
log_file="$HOME/Desktop/运行Mac安全随机浏览.log"

mkdir -p "$(/usr/bin/dirname "$log_file")"
exec > >(/usr/bin/tee -a "$log_file") 2>&1

echo "============================================================"
echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] 启动：run_safe_random_app_walker.command"
echo "脚本目录：$script_dir"

finish() {
  status=$?
  echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] 结束：退出码 $status"
  echo "============================================================"
}
trap finish EXIT

if [[ ! -f "$script_file" ]]; then
  echo "没有找到：$script_file"
  echo "请确认脚本文件还在：$script_dir"
  read -k 1 "?按任意键关闭..."
  exit 1
fi

cd "$script_dir"
export CLANG_MODULE_CACHE_PATH="/private/tmp/codex-clang-module-cache"
echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] 状态：使用 caffeinate 防止睡眠；锁屏时 macOS 可能阻止图形界面点击"
echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] 操作：按空格键暂停/继续；按 q 退出"

/usr/bin/caffeinate -dimsu /usr/bin/swift safe_random_app_walker.swift &
runner_pid=$!
paused=0

child_pids() {
  /usr/bin/pgrep -P "$runner_pid" 2>/dev/null || true
}

pause_runner() {
  for pid in $(child_pids); do
    /bin/kill -STOP "$pid" 2>/dev/null || true
  done
  /bin/kill -STOP "$runner_pid" 2>/dev/null || true
}

resume_runner() {
  /bin/kill -CONT "$runner_pid" 2>/dev/null || true
  for pid in $(child_pids); do
    /bin/kill -CONT "$pid" 2>/dev/null || true
  done
}

stop_runner() {
  resume_runner
  for pid in $(child_pids); do
    /bin/kill "$pid" 2>/dev/null || true
  done
  /bin/kill "$runner_pid" 2>/dev/null || true
}

trap 'stop_runner; exit 130' INT TERM

while /bin/kill -0 "$runner_pid" 2>/dev/null; do
  if read -rs -t 1 -k 1 key; then
    if [[ "$key" == " " ]]; then
      if [[ "$paused" -eq 0 ]]; then
        pause_runner
        paused=1
        echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] 手动暂停：已暂停，按空格继续"
      else
        resume_runner
        paused=0
        echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] 手动继续：已恢复，按空格可再次暂停"
      fi
    elif [[ "$key" == "q" || "$key" == "Q" ]]; then
      echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] 手动退出"
      stop_runner
      wait "$runner_pid" 2>/dev/null
      exit 0
    fi
  fi
done

wait "$runner_pid"
