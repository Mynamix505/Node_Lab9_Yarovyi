#!/usr/bin/env bash
# Студент: Яровий Михайло, група КН-42
# Одноразова підготовка Ubuntu EC2: видалення pm2, встановлення Docker Engine + Compose plugin.
# Запуск на сервері:  bash setup-ec2.sh   (потім перелогіньтеся, щоб діяла група docker)
set -euo pipefail

# 1. Повне видалення pm2, щоб старі процеси Node.js не займали порт 3000
if command -v pm2 >/dev/null 2>&1; then
  pm2 stop all || true
  pm2 delete all || true
  pm2 kill || true
  sudo env PATH="$PATH" pm2 unstartup systemd -u "$USER" --hp "$HOME" || true
  sudo npm uninstall -g pm2 || npm uninstall -g pm2 || true
fi
rm -rf "$HOME/.pm2"

# 2. Docker Engine + Docker Compose plugin з офіційного репозиторію Docker
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sudo sh
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

# 3. Директорія, куди CI/CD копіює docker-compose.yml
mkdir -p "$HOME/nodeapp"

docker --version || sudo docker --version
sudo docker compose version
echo "Готово. Вийдіть і зайдіть по SSH знову, щоб docker працював без sudo."
