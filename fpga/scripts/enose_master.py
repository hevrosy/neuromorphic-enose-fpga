#!/usr/bin/env python3
import pynq
from pynq import Overlay
import smbus2 as smbus
import bme680
import time
import csv
import os
import sys
import select
import numpy as np
import pandas as pd

# =====================================================================
# ГЛОБАЛНИ НАСТРОЙКИ И ПРАГОВЕ (ROBUST CHEMISTRY EDITION v5.6)
# =====================================================================
BITSTREAM_FILE = "snn_v18.bit" 

LOG_CALIBRATION = "log_01_calibration.csv"
LOG_DATASET     = "log_02_dataset.csv"
LOG_TRAINING    = "log_03_training.txt"
LOG_INFERENCE   = "log_04_inference.csv"

# Прагове: MQ135(10mV), MQ3(10mV), MQ4(10mV), VOC(4000 Ohm), TEMP(50=0.5C), HUM(200=2%)
THRESHOLDS = [10, 10, 10, 4000, 50, 200] 
TIME_STEPS = 20
TRAIN_MULTIPLIER = 10  # Намален множител за избягване на хардуерно насищане

b_m1, b_m3, b_m4, b_voc, b_tmp, b_hum = 0, 0, 0, 0, 0, 0

print("=" * 70)
print(" EDGE AI E-NOSE: TELEMETRY MASTER CONTROL (v5.6) ")
print("=" * 70)

# =====================================================================
# ИНИЦИАЛИЗАЦИЯ НА ХАРДУЕРА
# =====================================================================
print("[Система] Зареждане на FPGA хардуера...")
try:
    overlay = Overlay(BITSTREAM_FILE)
    xadc = overlay.xadc_wiz_0
    preproc = overlay.enose_preproc_0
    snn = overlay.enose_accel_0
except Exception as e:
    print(f"[ГРЕШКА] Неуспешно зареждане: {e}")
    sys.exit(1)

def read_mq_mv():
    v135 = ((xadc.read(0x244) >> 4) / 4096.0) * 3.3
    v3   = ((xadc.read(0x264) >> 4) / 4096.0) * 3.3
    v4   = ((xadc.read(0x258) >> 4) / 4096.0) * 3.3
    return int(v135 * 1000), int(v3 * 1000), int(v4 * 1000)

print("[Система] Инициализация на BME688...")
bus = smbus.SMBus(0)
try:
    bme = bme680.BME680(i2c_addr=0x76, i2c_device=bus)
except:
    bme = bme680.BME680(i2c_addr=0x77, i2c_device=bus)

bme.set_gas_status(bme680.ENABLE_GAS_MEAS)
bme.set_gas_heater_temperature(320)
bme.set_gas_heater_duration(150)
bme.select_gas_heater_profile(0)

# =====================================================================
# ПОМОЩНИ ФУНКЦИИ
# =====================================================================
def smart_input(prompt):
    print(prompt, end='', flush=True)
    while True:
        bme.get_sensor_data()
        i, o, e = select.select([sys.stdin], [], [], 0.5)
        if i:
            return sys.stdin.readline().strip()

def purge_timer(seconds=180):
    print("\n--- ПРОЦЕДУРА ЗА ДЕСОРБЦИЯ И ПРОВЕТРЯВАНЕ ---")
    smart_input("Отворете клапана и натиснете ENTER за стартиране на таймера...")
    for i in range(seconds, 0, -1):
        sys.stdout.write(f"\rПроветряване на системата: остават {i} сек... ")
        sys.stdout.flush()
        bme.get_sensor_data()
        time.sleep(1)
    print("\n[ОК] Проветряването приключи.")

# =====================================================================
# ЛАБОРАТОРНИ МОДУЛИ
# =====================================================================
def calibrate_sensors(smart_wait=True, duration=10):
    global b_m1, b_m3, b_m4, b_voc, b_tmp, b_hum
    print("\n--- КАЛИБРАЦИЯ НА БАЗОВАТА ЛИНИЯ ---")
    
    file_exists = os.path.isfile(LOG_CALIBRATION)
    with open(LOG_CALIBRATION, mode='a', newline='') as log_cal:
        writer = csv.writer(log_cal)
        if not file_exists:
            writer.writerow(["Timestamp", "Phase", "M1_mV", "M3_mV", "M4_mV", "VOC_Ohm", "Delta_M1", "Delta_M3", "Delta_M4", "Delta_VOC", "Stable_Count"])

        if smart_wait:
            print("[АВТО-СТАБИЛИЗАЦИЯ] Изчакване на термично плато...")
            hist_voc, hist_m1, hist_m3, hist_m4 = [], [], [], []
            stable_window = 10
            max_delta_voc = 1500  
            max_delta_mq = 8     
            required_stable_seconds = 15
            stable_seconds_count = 0
            
            for i in range(300): 
                m1, m3, m4 = read_mq_mv()
                bme.get_sensor_data()
                voc = int(bme.data.gas_resistance) if bme.data.heat_stable else 0
                
                if voc > 0:
                    hist_voc.append(voc)
                    hist_m1.append(m1)
                    hist_m3.append(m3)
                    hist_m4.append(m4)
                    
                    d_voc, d_m1, d_m3, d_m4 = 0, 0, 0, 0
                    
                    if len(hist_voc) > stable_window:
                        hist_voc.pop(0); hist_m1.pop(0); hist_m3.pop(0); hist_m4.pop(0)
                        
                    if len(hist_voc) == stable_window:
                        d_voc = max(hist_voc) - min(hist_voc)
                        d_m1 = max(hist_m1) - min(hist_m1)
                        d_m3 = max(hist_m3) - min(hist_m3)
                        d_m4 = max(hist_m4) - min(hist_m4)
                        
                        is_voc_stable = (d_voc < max_delta_voc) and (voc > 50000)
                        are_mqs_stable = (d_m1 < max_delta_mq) and (d_m3 < max_delta_mq) and (d_m4 < max_delta_mq)
                        
                        if is_voc_stable and are_mqs_stable:
                            stable_seconds_count += 1
                        else:
                            stable_seconds_count = 0 
                        
                        sys.stdout.write(f"\r[{i}s] dVOC:{d_voc:4d} | dM1:{d_m1:2d} | dM3:{d_m3:2d} | dM4:{d_m4:2d} | Стабилни: {stable_seconds_count}/{required_stable_seconds}s   ")
                        sys.stdout.flush()
                        
                        ts = time.strftime("%Y-%m-%d %H:%M:%S")
                        writer.writerow([ts, "Stabilization_Search", m1, m3, m4, voc, d_m1, d_m3, d_m4, d_voc, stable_seconds_count])
                        log_cal.flush()
                        
                        if stable_seconds_count >= required_stable_seconds:
                            print("\n[ОК] Всички сензори са напълно стабилизирани!")
                            break
                    else:
                        sys.stdout.write(f"\rНабиране на буфер ({i} сек)...   ")
                        sys.stdout.flush()
                time.sleep(1)
                
        smart_input("\nНатиснете ENTER за окончателен запис на базовата линия...")
        t_m1, t_m3, t_m4, t_voc, t_tmp, t_hum = 0, 0, 0, 0, 0, 0
        for i in range(duration):
            m1, m3, m4 = read_mq_mv()
            bme.get_sensor_data()
            voc = int(bme.data.gas_resistance) if bme.data.heat_stable else b_voc
            tmp = int(bme.data.temperature * 100)
            hum = int(bme.data.humidity * 100)
            
            t_m1 += m1; t_m3 += m3; t_m4 += m4; t_voc += voc; t_tmp += tmp; t_hum += hum
            print(f"  -> Стъпка {i+1}/{duration}: VOC={voc:6d} | M1={m1:4d} | M3={m3:4d} | M4={m4:4d}")
            time.sleep(1)

        b_m1 = t_m1 // duration; b_m3 = t_m3 // duration; b_m4 = t_m4 // duration
        b_voc = t_voc // duration; b_tmp = t_tmp // duration; b_hum = t_hum // duration
        print(f"\n[БАЗА ЗАКЛЮЧЕНА] M1:{b_m1}, M3:{b_m3}, M4:{b_m4}, VOC:{b_voc}")

def live_monitor():
    print("\n--- ЖИВ МОНИТОР (Натиснете Ctrl+C за изход) ---")
    try:
        while True:
            m1, m3, m4 = read_mq_mv()
            bme.get_sensor_data()
            voc = int(bme.data.gas_resistance) if bme.data.heat_stable else b_voc
            print(f"[LIVE] M1:{m1:4d} | M3:{m3:4d} | M4:{m4:4d} | VOC:{voc:6d}")
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[Монитор] Спрян.")

def collect_data():
    print("\n--- СЪБИРАНЕ НА ДАННИ ---")
    class_lbl = smart_input("Въведете Клас (0=Въздух, 1=Миризма 1, 2=Миризма 2): ")
    samples_str = smart_input("Колко проби да запиша? (По подразбиране 60): ")
    samples = int(samples_str) if samples_str.isdigit() else 60
    
    if class_lbl != '0':
        smart_input("\nСвържете пробата и натиснете ENTER за 60s таймер за насищане...")
        for i in range(60, 0, -1):
            sys.stdout.write(f"\rНасищане: остават {i} сек... ")
            sys.stdout.flush()
            bme.get_sensor_data()
            time.sleep(1)
        print("\nЗапочва запис...")
    else:
        smart_input("Натиснете ENTER за стартиране на записа...")
    
    file_exists = os.path.isfile(LOG_DATASET)
    with open(LOG_DATASET, mode='a', newline='') as file:
        writer = csv.writer(file)
        if not file_exists:
            writer.writerow(["Timestamp", "Class", "MQ135", "MQ3", "MQ4", "VOC", "TEMP", "HUM", 
                             "Base_MQ135", "Base_MQ3", "Base_MQ4", "Base_VOC", "Base_TEMP", "Base_HUM"])
        try:
            for i in range(samples):
                m1, m3, m4 = read_mq_mv()
                bme.get_sensor_data()
                voc = int(bme.data.gas_resistance) if bme.data.heat_stable else b_voc
                tmp = int(bme.data.temperature * 100)
                hum = int(bme.data.humidity * 100)
                
                ts = time.strftime("%Y-%m-%d %H:%M:%S")
                writer.writerow([ts, class_lbl, m1, m3, m4, voc, tmp, hum, b_m1, b_m3, b_m4, b_voc, b_tmp, b_hum])
                print(f"[Запис {i+1}/{samples}] Клас {class_lbl} -> VOC:{voc:6d} | M3:{m3:4d}")
                time.sleep(1)
            print(f"\n[УСПЕХ] Данните са запазени.")
        except KeyboardInterrupt:
            print("\n[ВНИМАНИЕ] Записът беше прекъснат.")

def train_network():
    print("\n--- ТРЕНИРАНЕ НА НЕВРОННАТА МРЕЖА ---")
    if not os.path.isfile(LOG_DATASET):
        print(f"[ГРЕШКА] Няма данни в {LOG_DATASET}!")
        return

    df = pd.read_csv(LOG_DATASET)
    
    def get_spikes(row):
        deltas = [
            row['MQ135'] - row['Base_MQ135'], row['MQ3']   - row['Base_MQ3'],
            row['MQ4']   - row['Base_MQ4'],   row['VOC']   - row['Base_VOC'],
            row['TEMP']  - row['Base_TEMP'],  row['HUM']   - row['Base_HUM']
        ]
        spikes = []
        for i in range(6):
            spikes.extend([1 if deltas[i] > THRESHOLDS[i] else 0, 
                           1 if deltas[i] < -THRESHOLDS[i] else 0])
        return np.array(spikes)

    spike_profiles = {0: np.zeros(12), 1: np.zeros(12), 2: np.zeros(12)}
    class_counts = {0: 0, 1: 0, 2: 0}

    for index, row in df.iterrows():
        c = int(row['Class'])
        if c in [0, 1, 2]:
            spike_profiles[c] += get_spikes(row)
            class_counts[c] += 1

    print("\n[ВЕРОЯТНОСТНИ ХИМИЧНИ ПРОФИЛИ]")
    for c in range(3):
        if class_counts[c] > 0:
            spike_profiles[c] = spike_profiles[c] / class_counts[c]
            
    # ЗАЩИТА 1: Твърдо нулиране на Клас 0
    spike_profiles[0] = np.zeros(12)
    
    # ЗАЩИТА 2: Игнориране на Температура и Влажност (Индекси от 8 до 11)
    # Това предотвратява объркването при отваряне на капака и дишане!
    for c in range(3):
        spike_profiles[c][8:] = 0.0
    
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_TRAINING, 'a') as f_log:
        f_log.write(f"\n{'='*50}\nTRAINING: {ts}\nPROFILES:\n")
        for c in range(3):
            prof_str = str(np.round(spike_profiles[c], 2))
            print(f"Клас {c}: {prof_str}")
            f_log.write(f"Class {c}: {prof_str}\n")

        print(f"\nГенериране на синаптични тегла (Множител: {TRAIN_MULTIPLIER}x)...")
        N_IN, N_HIDDEN, N_OUT = 12, 32, 3
        w1_matrix = np.zeros((N_IN, N_HIDDEN), dtype=int)
        w2_matrix = np.zeros((N_HIDDEN, N_OUT), dtype=int)

        for inp_idx in range(N_IN):
            for out_class in range(3):
                w1_matrix[inp_idx][out_class] = int(spike_profiles[out_class][inp_idx] * TRAIN_MULTIPLIER)

        w2_matrix[0][0] = 64; w2_matrix[1][1] = 64; w2_matrix[2][2] = 64 

    with open('w1.mem', 'w') as f:
        for inp in range(N_IN):
            for hid in range(N_HIDDEN): f.write(f"{(w1_matrix[inp][hid] & 0xFF):02X}\n")

    with open('w2.mem', 'w') as f:
        for hid in range(N_HIDDEN):
            for out in range(N_OUT): f.write(f"{(w2_matrix[hid][out] & 0xFF):02X}\n")

    print("[УСПЕХ] Изпълнете Tcl скрипта във Vivado.")

def get_active_channels(m1, m3, m4, voc, tmp, hum):
    d_m1, d_m3, d_m4 = m1 - b_m1, m3 - b_m3, m4 - b_m4
    d_voc, d_tmp, d_hum = voc - b_voc, tmp - b_tmp, hum - b_hum
    
    active = []
    if d_m1 > THRESHOLDS[0]: active.append("M1_Up")
    if d_m1 < -THRESHOLDS[0]: active.append("M1_Dn")
    if d_m3 > THRESHOLDS[1]: active.append("M3_Up")
    if d_m3 < -THRESHOLDS[1]: active.append("M3_Dn")
    if d_m4 > THRESHOLDS[2]: active.append("M4_Up")
    if d_m4 < -THRESHOLDS[2]: active.append("M4_Dn")
    if d_voc > THRESHOLDS[3]: active.append("VOC_Up")
    if d_voc < -THRESHOLDS[3]: active.append("VOC_Dn")
    return active, d_m1, d_m3, d_m4, d_voc

def run_inference():
    global b_m1, b_m3, b_m4, b_voc, b_tmp, b_hum
    print("\n--- РЕАЛНО ТЕСТВАНЕ (HARDWARE AI INFERENCE) ---")
    print("ИНСТРУКЦИЯ: Натисни 'R' + ENTER по всяко време, за да рестартираш базовата линия!")
    
    preproc.write(0x1C, THRESHOLDS[0]); preproc.write(0x20, THRESHOLDS[1])
    preproc.write(0x24, THRESHOLDS[2]); preproc.write(0x28, THRESHOLDS[3])
    preproc.write(0x2C, THRESHOLDS[4]); preproc.write(0x30, THRESHOLDS[5])
    snn.write(0x08, TIME_STEPS)
    
    file_exists = os.path.isfile(LOG_INFERENCE)
    log_file = open(LOG_INFERENCE, mode='a', newline='')
    log_writer = csv.writer(log_file)
    if not file_exists:
        log_writer.writerow(["Timestamp", "M1", "M3", "M4", "VOC", "D_M1", "D_M3", "D_M4", "D_VOC", "Winner", "K0", "K1", "K2", "Active"])
    
    try:
        while True:
            # ПРОВЕРКА ЗА НАТИСНАТ КЛАВИШ 'R'
            i, o, e = select.select([sys.stdin], [], [], 0.0)
            if i:
                cmd = sys.stdin.readline().strip().upper()
                if cmd == 'R':
                    b_m1, b_m3, b_m4 = m1, m3, m4
                    b_voc, b_tmp, b_hum = voc, tmp, hum
                    print("\n" + "="*50)
                    print("🔄 БАЗОВАТА ЛИНИЯ Е НУЛИРАНА КЪМ ТЕКУЩИЯ ВЪЗДУХ!")
                    print("="*50 + "\n")
                    continue

            m1, m3, m4 = read_mq_mv()
            bme.get_sensor_data()
            voc = int(bme.data.gas_resistance) if bme.data.heat_stable else b_voc
            tmp = int(bme.data.temperature * 100)
            hum = int(bme.data.humidity * 100)

            preproc.write(0x04, b_m1); preproc.write(0x08, b_m3)
            preproc.write(0x0C, b_m4); preproc.write(0x10, b_voc)
            preproc.write(0x14, b_tmp); preproc.write(0x18, b_hum)
            
            preproc.write(0x34, m1); preproc.write(0x38, m3)
            preproc.write(0x3C, m4); preproc.write(0x40, voc)
            preproc.write(0x44, tmp); preproc.write(0x48, hum)

            snn.write(0x00, 2); snn.write(0x00, 0); snn.write(0x00, 1) 
            for _ in range(TIME_STEPS):
                preproc.write(0x00, 1)
            
            c0 = snn.read(0x1C)
            c1 = snn.read(0x20)
            c2 = snn.read(0x24)
            
            winner = "Въздух"
            if c1 >= 3 or c2 >= 3:
                if c2 > c1:
                    winner = "КЛАС 2"
                elif c1 > c2:
                    winner = "КЛАС 1"
                elif c1 == c2:
                    # Решаване на проблема с Подмножествата (Subset Trap)
                    # Ако имат равен брой спайкове, печели по-простият клас (К1)
                    winner = "КЛАС 1"
                
            active_channels, d_m1, d_m3, d_m4, d_voc = get_active_channels(m1, m3, m4, voc, tmp, hum)
            active_str = " | ".join(active_channels) if active_channels else "Няма"

            print(f"M3:{m3:3d} | VOC:{voc:6d} => {winner} | Спайкове: [К1:{c1:2d}, К2:{c2:2d}] | Активни: {active_str}")
            
            ts = time.strftime("%Y-%m-%d %H:%M:%S")
            log_writer.writerow([ts, m1, m3, m4, voc, d_m1, d_m3, d_m4, d_voc, winner, c0, c1, c2, active_str])
            log_file.flush() 
                
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\n[Тест] Излизане.")
    finally:
        log_file.close()

# =====================================================================
# ГЛАВНО МЕНЮ
# =====================================================================
def main():
    print("\nПървоначално термодинамично загряване (5 сек)...")
    for _ in range(5):
        bme.get_sensor_data()
        time.sleep(1)
        
    calibrate_sensors(smart_wait=True, duration=10)
    
    while True:
        print("\n" + "=" * 60)
        print(" [1] ЖИВ МОНИТОР | [2] ДАННИ | [3] ТРЕНИРАНЕ | [4] ТЕСТВАНЕ")
        print(" [5] КАЛИБРАЦИЯ  | [6] ПРОВЕТРЯВАНЕ        | [Q] ИЗХОД")
        print("=" * 60)
        
        choice = smart_input("Избор: ").strip().upper()
        
        if choice == '1': live_monitor()
        elif choice == '2': collect_data()
        elif choice == '3': train_network()
        elif choice == '4': run_inference()
        elif choice == '5': calibrate_sensors(smart_wait=True, duration=10)
        elif choice == '6': purge_timer(seconds=180)
        elif choice == 'Q': break

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)