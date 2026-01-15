# Dataset Protocol (e-nose)

## Objective
Събиране на възпроизводими времеви серии от e-nose за 3-класова класификация:
Fresh / Warning / Spoiled.

## Hardware setup
- Камера: 0.5–1.0 L, херметична.
- Вентилатор: 5V (вътре) за хомогенизация на въздуха.
- Сензори:
  - MQ-135, MQ-3, MQ-4 към XADC (A0..A2)
  - BME688 по I2C (T/RH + gas resistance)

## Preconditioning
- MQ сензори: стабилизация (burn-in) преди реални измервания.
- Калибрация/проверка: базов шум, реакция на проба с известен мирис.

## Sampling
- Rate: 1 Hz
- Duration per run: 10 min (600 s)
- Warmup discard: optional (0–60 s)
- Baseline segment: първите 30 s се използват за baseline correction.

## Batches and repeats
- Minimum: 3 партиди (B01, B02, B03)
- Per batch: поне 3 записа (runs) на клас (общо ≥ 9/клас ако е възможно)

## Purge / chamber clearing (без филтър)
- Purge mode: open_lid_fan (отворен капак + вентилатор).
- Пауза: минимум 2 мин или до стабилизиране (праг по variance).
- Цел: намаляване на memory effect / остатъчни VOC.

## Labeling
Етикет се определя чрез комбинация:
- време от началото на експеримента
- референтна мярка (по възможност): мирис/органолептика, pH, температура на съхранение, снимка/бележки.

## Metadata
За всеки run се записва JSON:
- label, batch_id
- продукт, условия (T, RH), камера обем, purge параметри
- дата/час, оператор, бележки
