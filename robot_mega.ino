#include <Arduino.h>
#include <Servo.h> // Подключаем стандартную библиотеку сервоприводов

#define SERIAL_BAUD 115200

// --- КОНФИГУРАЦИЯ ПИНОВ МОТОРОВ КОЛЕС (Уже настроено) ---
const int pinPWMA = 8;  const int pinAIN2 = 7;  const int pinAIN1 = 6;
const int pinBIN1 = 9;  const int pinBIN2 = 10; const int pinPWMB = 11;

// --- КОНФИГУРАЦИЯ ПИНОВ ЭНКОДЕРОВ (ПО СХЕМЕ) ---
const int pinEncLeftA = 3;   // J8 пин 3
const int pinEncLeftB = 15;  // J8 пин 4
const int pinEncRightA = 2;  // J1 пин 3
const int pinEncRightB = 14; // J1 пин 4


// --- КОНФИГУРАЦИЯ СЕРВОПРИВОДОВ КАМЕРЫ ---
const int pinServoLeft = 5;   // Левая серва дифференциала
const int pinServoRight = 13; // Правая серва дифференциала

Servo servoL;
Servo servoR;

// Текущие углы сервоприводов (изначально выставляем в центр — 90 градусов)
int currentPitch = 90; // Наклон головы
int currentYaw = 90;   // Поворот головы

// Настройки телеметрии (как было)
long encoderLeft = 1000; long encoderRight = 1050;
int distanceLeft = 45;   int distanceRight = 60; int buttonStatus = 0;
unsigned long previousMillis = 0; const long interval = 100;
String inputBuffer = "";

long lastSentLeft = 0;
long lastSentRight = 0;
int lastSentButton = -1;

unsigned long lastCommandTime = 0;
const unsigned long connectionTimeout = 1000;


void isrLeft() {
  // Если фазы одинаковые — крутимся в одну сторону, если разные — в другую
  if (digitalRead(pinEncLeftA) == digitalRead(pinEncLeftB)) {
    encoderLeft--; // Меняй знак ++ или -- если одометрия поедет назад
  } else {
    encoderLeft++;
  }
}

void isrRight() {
  if (digitalRead(pinEncRightA) == digitalRead(pinEncRightB)) {
    encoderRight++; // Меняй знак если одометрия поедет назад
  } else {
    encoderRight--;
  }
}

void setMotor(int motorNum, int speed);
void stopMotors();
void parseCommand(String cmd);

void setup() {
  Serial.begin(SERIAL_BAUD);
  inputBuffer.reserve(64);

  // Инициализация колес
  pinMode(pinPWMA, OUTPUT); pinMode(pinAIN2, OUTPUT); pinMode(pinAIN1, OUTPUT);
  pinMode(pinBIN1, OUTPUT); pinMode(pinBIN2, OUTPUT); pinMode(pinPWMB, OUTPUT);
  stopMotors();

  // Инициализация и привязка сервоприводов камеры
  servoL.attach(pinServoLeft);
  servoR.attach(pinServoRight);

  // Устанавливаем камеру ровно по центру при старте
  servoL.write(currentPitch);
  servoR.write(currentYaw);

  // ИНСТРУКЦИЯ НА СХЕМУ: Настройка пинов энкодеров на вход с подтяжкой
  pinMode(pinEncLeftA, INPUT_PULLUP);
  pinMode(pinEncLeftB, INPUT_PULLUP);
  pinMode(pinEncRightA, INPUT_PULLUP);
  pinMode(pinEncRightB, INPUT_PULLUP);

  // Привязка аппаратных прерываний по изменению фронта (RISING)
  attachInterrupt(digitalPinToInterrupt(pinEncLeftA), isrLeft, RISING);
  attachInterrupt(digitalPinToInterrupt(pinEncRightA), isrRight, RISING);
}

void loop() {
  unsigned long currentMillis = millis();
  if (millis() - lastCommandTime > connectionTimeout) {
      stopMotors();
  }
  // Отправка данных в ROS 2 (Каждые 100 мс)
  if (currentMillis - previousMillis >= interval) {
      previousMillis = currentMillis;

      if (
        encoderLeft != lastSentLeft ||
        encoderRight != lastSentRight ||
        buttonStatus != lastSentButton
      ) {

        lastSentLeft = encoderLeft;
        lastSentRight = encoderRight;
        lastSentButton = buttonStatus;

        Serial.print("DAT:");
        Serial.print(encoderLeft);
        Serial.print(",");
        Serial.print(encoderRight);
        Serial.print(",");
        Serial.print(distanceLeft);
        Serial.print(",");
        Serial.print(distanceRight);
        Serial.print(",");
        Serial.println(buttonStatus);
      }
  }

  // Прием команд от Малинки
  while (Serial.available() > 0) {
    char inChar = (char)Serial.read();
    if (inChar == '\n') {
      parseCommand(inputBuffer);
      inputBuffer = "";
    } else if (inChar != '\r') {
      inputBuffer += inChar;
    }
  }
}

void parseCommand(String cmd) {
    lastCommandTime = millis();
  // НОВЫЙ БЛОК: Дифференциальное управление камерой (#HEAD:наклон,поворот)
  if (cmd.startsWith("#HEAD:")) {
    String valStr = cmd.substring(6);
    int commaIndex = valStr.indexOf(',');
    if (commaIndex != -1) {
      String pitchStr = valStr.substring(0, commaIndex);
      String yawStr = valStr.substring(commaIndex + 1);

      int deltaPitch = pitchStr.toInt(); // Смещение наклона от пульта
      int deltaYaw = yawStr.toInt();     // Смещение поворота от пульта

      // Изменяем текущую виртуальную позицию головы робота
      // (добавляем смещение, чтобы камера двигалась плавно, пока зажата кнопка)
      currentPitch += deltaPitch / 5; // Деление на 5 уменьшает резкость движения
      currentYaw += deltaYaw / 5;

      // Ограничиваем виртуальные углы в безопасные физические лимиты (от 20 до 160 градусов)
      currentPitch = constrain(currentPitch, 20, 160);
      currentYaw = constrain(currentYaw, 20, 160);

      // --- ФОРМУЛА ДИФФЕРЕНЦИАЛА ДЛЯ СЕРВОПРИВОДОВ ---
      // Смешиваем наклон и поворот для левой и правой сервы
      int servoLAngle = currentPitch + (currentYaw - 90);
      int servoRAngle = currentPitch - (currentYaw - 90);

      // Зажимаем итоговые углы в строгие лимиты сервоприводов (0-180)
      servoLAngle = constrain(servoLAngle, 0, 180);
      servoRAngle = constrain(servoRAngle, 0, 180);

      // Отправляем физические углы на исполнительные механизмы d5 и d13
      servoL.write(servoLAngle);
      servoR.write(servoRAngle);

      // Эхо-ответ для проверки
      Serial.print("ACK:HEAD_SERVO_ANGLES:");
      Serial.print(servoLAngle); Serial.print(",");
      Serial.println(servoRAngle);
    }
  }

  // Управление колесами (Оставляем как было)
  else if (cmd.startsWith("#MOVE:")) {
    String valStr = cmd.substring(6);
    int commaIndex = valStr.indexOf(',');
    if (commaIndex != -1) {
      float linearX = valStr.substring(0, commaIndex).toFloat();
      float angularZ = valStr.substring(commaIndex + 1).toFloat();
      int targetSpeed = (int)(linearX * 255.0);
      int targetTurn = (int)(angularZ * 150.0);
      int leftMotorSpeed = targetSpeed + targetTurn;
      int rightMotorSpeed = targetSpeed - targetTurn;
      setMotor(1, leftMotorSpeed);
      setMotor(2, rightMotorSpeed);
      Serial.print("ACK:MOTORS_PWM:");
      Serial.print(leftMotorSpeed); Serial.print(",");
      Serial.println(rightMotorSpeed);
    }
  }
}

// Функции моторов (как были)
void setMotor(int motorNum, int speed) {
  boolean in1State = LOW; boolean in2State = LOW;
  if (speed > 0) { in1State = HIGH; in2State = LOW; }
  else if (speed < 0) { in1State = LOW; in2State = HIGH; speed = -speed; }
  if (speed > 255) speed = 255;
  if (motorNum == 1) { digitalWrite(pinAIN1, in1State); digitalWrite(pinAIN2, in2State); analogWrite(pinPWMA, speed); }
  else if (motorNum == 2) { digitalWrite(pinBIN1, in1State); digitalWrite(pinBIN2, in2State); analogWrite(pinPWMB, speed); }
}
void stopMotors() { setMotor(1, 0); setMotor(2, 0); }
