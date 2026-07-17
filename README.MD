# ROS 2 Jazzy Robotics Stack (RPi 3B + LD19 Lidar + Camera)

Полное руководство по развертыванию автономного робо-стека для построения 2D-карт (SLAM) и трансляции видеопотока под OpenCV. Оптимизировано под ограничения Raspberry Pi 3B (1 GB RAM).

---

## 🛠 Шаг 0: Подготовка чистой Raspberry Pi (OS Setup)

Предполагается, что на Малинку установлена официальная **Raspberry Pi OS (64-bit) Bookworm Lite** [0.2].

### 1. Включение интерфейса камеры и ядра
По умолчанию шлейфовый разъем камеры может быть выключен в системе [0.2].
1. Откройте конфигурационный файл:
   ```bash
   sudo nano /boot/firmware/config.txt
   ```
2. Убедитесь, что строка автоопределения камеры активна: `camera_auto_detect=1` [0.2].
3. Если используется камера v2 (IMX219) или v1.3 (OV5647), добавьте/проверьте наличие строки поддержки графического ядра:
   ```text
   dtoverlay=vc4-kms-v3d
   ```
4. Сохраните файл (`Ctrl+O`, `Enter`, `Ctrl+X`) и перезагрузите плату: `sudo reboot`.

### 2. Проверка оборудования на хосте
После перезагрузки убедитесь, что Малинка физически видит и лидар, и камеру:
```bash
# Проверка лидара (должен появиться ttyUSB0)
ls /dev/ttyUSB*

# Проверка камеры (должна успешно сделать снимок)
rpicam-jpeg -o test.jpg -t 2000
```

---

## 💾 Шаг 1: Установка Docker, Compose и Git

Выполните эти команды на чистой Малинке для установки всего необходимого софта:

```bash
# Обновляем системные репозитории
sudo apt update && sudo apt upgrade -y

# Устанавливаем Git
sudo apt install -y git

# Устанавливаем Docker через официальный скрипт
curl -fsSL https://docker.com -o get-docker.sh
sudo sh get-docker.sh

# Добавляем текущего пользователя в группу docker (чтобы не писать sudo перед каждым docker)
sudo usermod -aG docker \$USER

# Устанавливаем Docker Compose
sudo apt install -y docker-compose-v2
```
*Важно:* После добавления пользователя в группу docker, обязательно **перезапустите SSH-сессию** (выключите терминал и зайдите заново), чтобы права применились.

---

## 🔧 Шаг 2: Настройка автозапусков на хосте

### 1. Постоянные права на Лидар
Чтобы Docker-контейнер всегда имел доступ к USB-порту, создаем правило `udev`:
```bash
echo 'KERNEL=="ttyUSB*", MODE="0666"' | sudo tee /etc/udev/rules.d/99-lidar.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

### 2. Автозапуск аппаратного стримера камеры
Создаем фоновую службу `systemd`, которая будет транслировать видео в локальную сеть по UDP на порт `8554` в формате MJPEG. Флаги `--hflip --vflip` переворачивают картинку на 180 градусов, исправляя монтаж шлейфа [0.2].

```bash
sudo nano /etc/systemd/system/rpi-camera-stream.service
```
Вставьте конфигурацию:
```ini
[Unit]
Description=Raspberry Pi Hardware Camera Stream for ROS2
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/rpicam-vid -t 0 --inline --width 320 --height 240 --framerate 10 --codec mjpeg -o udp://127.0.0.1:8554 --listen --hflip --vflip
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
```
Активируйте службу:
```bash
sudo systemctl daemon-reload
sudo systemctl enable rpi-camera-stream.service
sudo systemctl start rpi-camera-stream.service
```

---

## 📦 Шаг 3: Развертывание ROS 2 проекта

### 1. Создание структуры директорий
```bash
cd ~
mkdir -p ros2_ws/src
```
*Поместите файлы `docker-compose.yml`, `Dockerfile` и `ros2_ws/start_all.sh`, `ros2_ws/my_slam_params.yaml`, `ros2_ws/camera_driver.py`, `ros2_ws/openCV.py` в соответствующие папки вашего репозитория.*

### 2. Запуск и первая сборка
Запустите контейнер. На Raspberry Pi 3B первая компиляция драйвера лидара займет около 10–15 минут (сборка принудительно ограничена 1 процессором в Dockerfile, чтобы плата не зависла по памяти):
```bash
docker compose up -d --build
```
Все последующие запуски будут происходить мгновенно за 2 секунды: `docker compose up -d`.

---

## 💻 Шаг 4: Визуализация в Foxglove Studio

1. Откройте **Foxglove Studio** на вашем ПК, подключенном к той же Wi-Fi сети.
2. Выберите тип подключения: **Foxglove WebSocket**.
3. Укажите адрес вашей Малинки: `ws://<IP_АДРЕС_МАЛИНКИ>:8765` и нажмите **Open**.

### Настройка панелей для урока:
* **Панель 3D (Карта):** В настройках панели (шестерёнка) измените параметр **Fixed Frame** на значение **`map`**. В списке топиков слева включите `/scan` и `/map`.
* **Панель Image (Видео):** Выберите топик **`/camera/image_raw`**. Вы увидите плавный видеопоток с задержкой не более 0.2 сек, полностью синхронизированный по времени с лидаром.
