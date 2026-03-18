# Пространствено-времево оптимизирана, двуконтурна флуидна камера за масиви от газови сензори (Електронен нос): Проектиране, Кинетика и Термодинамика

**Архитектурна версия:** 1.2.4 (Напълно параметрична, Топологично оптимизирана за FDM)  
**Хардуерна спецификация:** Sunon EE60201B1 (Двоен сачмен лагер, Високоскоростен аксиален ротор)  
**Ключови думи:** Изкуствено обоняние, Механика на непрекъснатите среди, Ламинаризация, Термодинамика на хемисорбцията, Визкоеластично затихване, Дисперсия на Тейлър, Отворен хардуер (Open-Source DAQ).

## 1. Въведение и Архитектурна Парадигма
Системите за Изкуствено обоняние (Електронен нос), базирани на метало-оксидни полупроводници (Metal-Oxide Semiconductor - MOX), представляват мощен инструмент за неразрушителен анализ на летливи органични съединения (VOCs). Въпреки това, преходът от контролирана лабораторна среда към полеви условия или системи за събиране на данни (Data Acquisition - DAQ) за Машинно обучение (Machine Learning), разкрива критични хардуерни дефицити в конвенционалните дизайни. 

Достоверността на извличаните данни (Signal-to-Noise Ratio - SNR) е фундаментално ограничена от три системни физични феномена, произтичащи от неадекватния дизайн на флуидните камери:
1. **Стохастична макро-турбулентност (Аеродинамичен шум):** Хаотичното движение на въздушните маси над сензорната матрица създава локални флуктуации в парциалното налягане на аналита.
2. **Неизотермични гранични условия (Термичен дрифт):** Нестабилните конвективни потоци нарушават прецизния топлинен баланс на сензорните микронагреватели, променяйки базовата им линия.
3. **Микрофоничен и структурен резонанс:** Слабото механично декуплиране (изолиране) на активните помпени елементи индуцира електрически шум в чувствителните керамични субстрати на сензорите.

Традиционните ортогонални (кутиеобразни) камери страдат от аеродинамични "мъртви зони" (Stagnation zones), където газовете стагнират, което води до забавено време за реакция, асиметрични криви на насищане и силно изразена дисперсия. Настоящият труд предлага и валидира детерминистично конструирана, двуконтурна флуидна архитектура. Използвайки една единствена активна турбомашина (индустриален аксиален вентилатор Sunon EE60201B1), системата генерира първичен принудителен вихър за бърза пространствена хомогенизация, докато пасивно управлява високорегулиран вторичен ламинарен микро-поток за екстракция на газовата проба. Архитектурата демократизира достъпа до високопрецизна аналитична апаратура, предоставяйки отворен, параметричен и икономически ефективен модел, съвместим с широк спектър от сензори.

---

## 2. Системен импеданс и Аеродинамична Работна точка (Operating Point)
За да се избегне използването на сложни, скъпи и изключително шумни мембранни помпи за вземане на проба, предложената система използва индустриален аксиален вентилатор като генератор на диференциално налягане ($\Delta P$). За да функционира вентилаторът като вакуумна помпа за вторичния кръг, вътрешното статично налягане в главния пленум трябва да бъде изкуствено повишено. Това обаче трябва да се осъществи без да се преминава критичната граница на аеродинамичен срив (Aerodynamic Stall) на роторните лопатки, при който въздушният поток се отлепва от аеродинамичния профил, водейки до нулев ефективен дебит и екстремни вибрации.



Интегрираната турбомашина Sunon EE60201B1 разполага с максимално статично налягане $P_{max} \approx 42\text{ Pa}$ и максимален дебит в свободна среда $Q_{max} \approx 650\text{ L/min}$. За прецизно калибриране на налягането, в изпускателния тракт на първичния кръг са интегрирани четири геометрични дросела с диаметър $6.5\text{ mm}$. Общата им геометрична площ на сечението ($A_{ex}$) е $1.327 \times 10^{-4} \text{ m}^2$.

Според принципите на механиката на непрекъснатите среди, когато газ преминава през отвор с остър ръб (какъвто е топологичният профил на 3D-принтирания полимер), газовите струи се свиват непосредствено след отвора. Този феномен, известен като *Vena Contracta*, намалява ефективното сечение на потока. Затова се прилага емпиричен коефициент на изтичане $C_d = 0.62$. Кривата на системния импеданс ($P_{sys}$), описваща спада на налягането като функция от квадрата на дебита, се дефинира като:
$$\Delta P = \frac{\rho}{2} \cdot \left(\frac{Q}{C_d \cdot A_{ex}}\right)^2$$

Където $\rho$ е плътността на въздуха ($1.2\text{ kg/m}^3$), а $Q$ е обемният дебит. При наслагването (пресичането) на тази параболична крива на импеданса с P-Q (Pressure-Flow) характеристиката на вентилатора се установява реалната емпирична работна точка (Operating Point) на флуидната камера:
**$\Delta P_{op} \approx 39 \text{ Pa}$**
Тази стойност доказва, че системата използва над 90% от капацитета за статично налягане на турбомашината, поддържайки я в стабилен работен режим без риск от срив.

---

## 3. Кинематика на първичния циклонен кръг (Пространствена Хомогенизация)
Основната функция на първичния кръг е бързото, равномерно и повтаряемо смесване на газовия аналит с носещия газ (атмосферен въздух) в рамките на $1.2\text{ L}$ обем на основната камера.

### 3.1 Детерминистичен вихър и трансфер на маса
При установено постоянно работно налягане от $39\text{ Pa}$, скоростта на флуида ($v$), преминаващ през аеродинамичните дросели, се изчислява чрез уравнението на Бернули за несвиваем флуид по продължение на токова линия:
$$v = \sqrt{\frac{2 \cdot \Delta P_{op}}{\rho}} = \sqrt{\frac{2 \cdot 39}{1.2}} \approx \mathbf{8.06 \text{ m/s}}$$

Този вектор на скоростта генерира строго контролиран първичен обемен дебит ($Q_{int}$):
$$Q_{int} = (C_d \cdot A_{ex}) \cdot v = (0.62 \cdot 1.327 \times 10^{-4}) \cdot 8.06 \approx 6.63 \times 10^{-4} \text{ m}^3/\text{s} \approx \mathbf{40 \text{ L/min}}$$
Въздушните маси се инжектират в камерата тангенциално, индуцирайки принудителен вихър (Forced Vortex). За да се гарантира безпрепятствената работа на ротора и да се предотврати "задушаване" в горната част на камерата, вътрешната геометрия на купола е конструирана с широк аеродинамичен байпас (Wide-Body Aerodynamics), осигуряващ масивен 7-милиметров въздушен коридор около рамката на вентилатора. Непрекъснатият вътрешен циклон от $40\text{ L/min}$ гарантира, че целият физически обем на камерата се хомогенизира напълно **33 пъти в минута** ($\approx 0.55\text{ Hz}$), елиминирайки напълно локалните концентрационни градиенти.

### 3.2 Ламинаризация чрез геометричен колиматор (Намаляване на $Re$)
Въпреки че високоскоростният циклон осигурява превъзходен масообмен, неговата турбулентна кинетична енергия е пагубна за аналоговите сензори. Турбулентните вихри създават микро-флуктуации в локалното налягане върху сензорната повърхност. За преодоляване на този проблем, въздухът се пренасочва нагоре през $40\text{ mm}$ дълбок хексагонален дифузор (Honeycomb straightener), действащ като геометричен колиматор.



Разделяйки макро-потока в множество микро-канали с малък хидравличен диаметър ($D_h \approx 3.5\text{ mm}$), вискозните сили (триенето в стените на каналите) започват да доминират над инерционните сили. Това се описва чрез числото на Рейнолдс ($Re$):
$$Re = \frac{\rho \cdot v_{local} \cdot D_h}{\mu}$$
Дизайнът математически потиска Рейнолдсовото число далеч под критичния преходен праг ($Re \le 2300$). Резултатът е трансформация на хаотичния циклон в строго ламинарен, успореден на сензорите профил на потока (Cross-flow sweep), осигуряващ безшумна среда за хемисорбция.

---

## 4. Вторична транспортна кинетика и Управление на дисперсията
Вторичният кръг осъществява транспорта на аналита от статичния съд за проби ($115\text{ ml}$ Headspace vial) до сензорния масив. Този процес протича напълно пасивно, задвижван от градиента на налягането ($\Delta P_{op} = 39\text{ Pa}$), генериран в херметичния купол.

Транспортът се осъществява през химически инертна PTFE (политетрафлуороетилен) капилярна тръба с вътрешен радиус $r = 0.001\text{ m}$ и дължина $L = 0.4\text{ m}$. Кинетиката следва уравнението на Хаген-Поазьой за стационарен ламинарен поток в цилиндрични тръби:
$$Q_{ext} = \frac{\Delta P_{op} \cdot \pi \cdot r^4}{8 \cdot \mu \cdot L}$$
Приемайки динамичния вискозитет на въздуха за $\mu = 1.81 \times 10^{-5}\text{ Pa}\cdot\text{s}$:
$$Q_{ext} = \frac{39 \cdot \pi \cdot (0.001)^4}{8 \cdot (1.81 \times 10^{-5}) \cdot 0.4} = 2.11 \times 10^{-6} \text{ m}^3/\text{s} \approx \mathbf{127 \text{ mL/min}}$$

### 4.1 Дисперсия на Тейлър и Число на Пекле ($Pe$)
Този прецизно дозиран дебит от $127\text{ mL/min}$ не е просто следствие, а математически търсен оптимум за целите на Машинното обучение. При движение на газ през тръба се наблюдава феноменът Дисперсия на Тейлър (Taylor-Aris dispersion) – надлъжно размиване на концентрационния фронт поради параболичния профил на скоростите. 

За да се запази времевият профил на газовия фронт (остри криви на реакция), аксиалната конвекция трябва да доминира над надлъжната дифузия. Това съотношение се изразява чрез безразмерното число на Пекле ($Pe$). Дебитът от $127\text{ mL/min}$ гарантира достатъчно високо $Pe$, като същевременно екстрахира $115\text{ ml}$ обем на пробата за точно **54 секунди**. Това осигурява идеално разпределение на времето на престой (Residence Time Distribution - RTD), предоставяйки на алгоритмите за класификация ясни и диференцируеми времеви серии.

---

## 5. Полупроводникова термодинамика и Квантови ефекти на хемисорбцията
Метало-оксидните сензори (като широко разпространената MQ серия) детектират редуциращи газове чрез промяна в електрическата проводимост. В чист въздух, кислородните молекули се адсорбират върху кристалната решетка на калаения диоксид ($SnO_2$) и улавят електрони от проводимата зона, образувайки йони ($O^-$, $O^{2-}$). Това създава слой на електронно обедняване (Depletion layer), чиято дебелина се дефинира от Дебаевата дължина ($L_D$):
$$L_D = \sqrt{\frac{\epsilon \cdot k_B \cdot T}{e^2 \cdot n_d}}$$
Където $T$ е абсолютната температура, $k_B$ е константата на Болцман, а $n_d$ е концентрацията на донори. Както се вижда от уравнението, чувствителността е експоненциално и фундаментално зависима от поддържането на абсолютен изотермичен баланс на повърхността на микронагревателя (типично $T_s \approx 300^\circ\text{C}$).

Топлинните загуби към преминаващия носещ газ се описват от Закона на Нютон за конвективното охлаждане:
$$q = h \cdot A \cdot (T_s - T_\infty)$$
Ако системата допускаше хаотични скорости на засмукване или прекалено високи дебити (както се случва при използване на неограничени компютърни вентилатори), коефициентът на конвективен топлообмен ($h$) би флуктуирал неконтролируемо. Това би отнело топлинна енергия ($q$) по-бързо, отколкото PID регулаторът на микронагревателя може да компенсира. 

Резултатът от това охлаждане е изместване на нивото на Ферми и промяна в енергията на активация за десорбция на кислородните йони, което външно се проявява като масивен **Термичен дрифт** на базовата линия. Строго калибрираният микро-дебит от $127\text{ mL/min}$ ефективно декуплира сензорната термодинамика от високоскоростния макро-циклон на първичния кръг, осигурявайки постоянна стойност на $h$ и кристално чиста, лишена от дрифт аналогова крива.

---

## 6. Визкоеластична изолация и Трибология на полимерите
Механичните роторни вибрации от високоскоростната турбомашина (оперираща при $\sim 4500\text{ RPM}$) неизбежно се предават през твърдите полимерни структури (PETG/ABS). Тези вибрации индуцират структурен резонанс, който се прехвърля върху чувствителните керамични субстрати на MOX сензорите, генерирайки пиезоелектричен и микрофоничен електрически шум, който компрометира резолюцията на аналогово-цифровия преобразувател (ADC).

За елиминиране на този вибрационен трансфер е конструирана модулна визкоеластична система на окачване, отпечатана от термопластичен полиуретан (TPU 95A). Системата функционира на базата на модела на Келвин-Фойгт за визкоеластичност, използвайки концепцията за **механичен импедансен конфликт (Mechanical Impedance Mismatch)**. 
Материалът TPU 95A притежава висок модул на загубите (Loss modulus, $E''$), което му позволява да дисипира механичната енергия като минимално количество топлина. 

* **Активно декуплиране:** Аксиалният вентилатор е поставен между две силно компресируеми TPU гарнитури. Това драстично намалява коравината ($k$) на системата, измествайки собствената резонансна честота ($f_n$) на сглобката в инфразвуковия спектър, далеч под възбуждащата работна честота на мотора.
* **Аксиално затихване:** Специализирани TPU шайби са проектирани да абсорбират аксиалното напрежение, предавано чрез крепежните елементи (M3 болтове), прекъсвайки твърдите механични мостове.
Изборът на вентилатор с двоен сачмен лагер (Sunon EE60201B1) елиминира гравитационното дебалансиране на ротора при хоризонтален монтаж, допълнително стабилизирайки системата.

---

## 7. Химия на повърхностите, Адсорбционен хистерезис и Пасивация
Адитивното производство чрез екструзия на материал (FDM 3D принтиране) неизбежно създава микропореста топология на повърхността (поради слоестата структура) и оставя полимери с висока повърхностна свободна енергия. 

Когато се анализират комплексни газове (като феноли, катрани от цигарен дим или тежки алкохоли), вътрешните стени на суровата пластмасова камера действат като хроматографска стационарна фаза. Молекулите на аналита се задържат в микропорите чрез силите на Ван дер Ваалс и водородни връзки. Този феномен води до тежък **Адсорбционен хистерезис (Memory Effect)**. Според изотермите на сорбция на Лангмюир, повърхността се насища бавно и освобождава молекулите още по-бавно, което означава, че базовата линия на сензорите никога не се възстановява до истинската нула между отделните експерименти.

**Задължителна научна пасивация:** За да се гарантира метрологична точност, вътрешната макро-геометрия на модулите `flow_chamber` и `lid_pro` задължително се пасивира. Нанасянето на тънък слой химически инертна епоксидна смола с ниска повърхностна енергия запълва всички микропори, минимизира повърхностната площ за адсорбция и изравнява сорбционните свойства на камерата с тези на лабораторното боросиликатно стъкло.

---

## 8. Дизайн за производство (DFM) и Протокол за динамично възстановяване

### 8.1 Топологична оптимизация
Всеки детайл от архитектурата (Версия 1.2.4) е строго съобразен с кинематичните ограничения на FDM принтерите. 
* **Изотропна 4.0 mm черупка:** Куполът (`fan_dome_ultimate`) е конструиран чрез сложни математически 3D отмествания, гарантиращи абсолютно равномерна дебелина на стените от 4.0 mm във всяка една точка. Това не само пести материал, но и осигурява термична стабилност по време на печат (особено при използване на Gyroid пълнеж), предотвратявайки вътрешни напрежения и изкривявания (Warping).
* **Support-free конструкция:** Вътрешният аеродинамичен свод на купола е сключен под ъгъл от 45°, позволявайки безупречно принтиране без поддържащи структури, запазвайки вътрешния обем изцяло гладък за флуидния поток.
* **Ергономична херметизация:** Изпускателният клапан (Purge Plug) е редизайниран с капковиден хоризонтален фланец (Teardrop tab), което позволява печат върху най-широката му страна, гарантирайки максимална адхезия към работната маса на принтера.

### 8.2 Експоненциален разпад и Прочистване (Purge Protocol)
За осигуряване на висока пропускателна способност (High Throughput) на лабораторната установка между дискретните експерименти, системата е оборудвана с $16\text{ mm}$ ръчен изпускателен клапан. 

При премахване на TPU тапата, системният аеродинамичен импеданс колабира мигновено. Заобикаляйки тесните $6.5\text{ mm}$ дросели, турбомашината преминава в режим на свободен поток ($Q \to Q_{max}$). Приемайки консервативни 50% загуби на ефективност през новата отворена геометрия, дебитът на прочистване със стаен въздух достига $\approx 300\text{ L/min}$.

Концентрацията на остатъчния газ спада според закона за непрекъснатото разреждане (експоненциален разпад):
$$C(t) = C_0 \cdot e^{-\left(\frac{Q_{purge}}{V}\right)t}$$
За да се постигне пълна деконтаминация, стандартният протокол изисква 5-кратна подмяна на обема на камерата ($5 \times 1.2\text{ L} = 6.0\text{ L}$). Времето, необходимо за този процес, се изчислява като:
$$t_{purge} = \frac{6.0\text{ L}}{300\text{ L/min}} \times 60 \approx \mathbf{1.2 \text{ секунди}}$$

Тази иновативна функция позволява напълно изчистване на сензорния масив и абсолютно възстановяване на базовата линия за под 2 секунди. Това превръща представената отворена хардуерна платформа в безпрецедентно мощен, надежден и гъвкав аналитичен инструмент, полагащ основите за следващото поколение изследвания в сферата на Изкуствения интелект и детекцията на околната среда.

# Advanced E-Nose Fluidic Chamber (v1.0.2)

A professional-grade, 100% support-free, 3D-printable fluidic chamber designed specifically for Electronic Nose (E-Nose) applications and Volatile Organic Compound (VOC) analysis. 

This project solves the most common issues found in DIY and academic electronic noses: poor gas mixing, lack of airtightness, aerodynamic stalling, and direct cold drafts disrupting the heated MQ-series gas sensors. By utilizing an aerospace-inspired "Closed-Loop Vortex System" and a 3D-printed dual-gasket sealing mechanism, this chamber ensures highly repeatable and stable sensor readings.

---

## 1. Concept & Scientific Justification: Overcoming Aerodynamic Limitations

Traditional E-Nose chambers often suffer from fatal flaws in fluid management, the most prominent being the "Closed Bottle Syndrome" (Aerodynamic Stall) and boundary layer stagnation.

### 1.1 The Aerodynamic Stall Problem
Axial fans are engineered to move large volumes of air under low static pressure. Every fan operates on a specific Pressure-Volume (P-Q) performance curve. If an axial fan blows directly into a sealed chamber, the internal static pressure almost instantly equals the fan's maximum shut-off pressure ($P_{max}$). 
When this equilibrium is reached, the flow rate ($Q$) drops to zero. The fan blades experience severe flow separation (stall), meaning they merely spin in their own localized turbulence without inducing any bulk fluid motion.


### 1.2 The Closed-Loop Tangential Vortex
To prevent stall and ensure continuous gas mixing, this chamber completely isolates the high-volume internal mixing loop from the low-volume external sampling loop. 
Rather than forcing air downwards, the aerodynamic lid (`lid_pro`) routes the fan's output through four curved, constricting ducts. These ducts act as nozzles, accelerating the fluid and injecting it tangentially along the cylindrical walls of the chamber. 

This generates a high-speed peripheral cyclone. The resulting centrifugal forces and high shear rates ensure that molecules of varying molecular weights (different VOCs) are violently and homogeneously mixed with the carrier air in milliseconds.


### 1.3 Transition to Laminar Flow via Honeycomb Straightening
Metal Oxide Semiconductor (MOX) gas sensors are highly sensitive to turbulent airflow. High-frequency turbulent eddies cause localized pressure and temperature micro-fluctuations on the sensor surface, which manifest as severe baseline noise in the analog signal.

To solve this, the turbulent vortex is forced through a 40mm deep honeycomb diffuser grid. By passing the fluid through dozens of narrow, parallel channels, the characteristic length of the flow path is drastically reduced. This mathematically forces the Reynolds number ($Re$) down, dampening transverse velocity components and converting the turbulent cyclone into a calm, uniform, downward laminar breeze.


### 1.4 Pressure Equalization (The Return Vents)
After the laminar flow passes over the sensor array, the fluid is drawn back up through four 8mm vertical vents directly into the low-pressure zone (the dome) above the fan. This creates an infinite, perfectly balanced internal mixing loop, allowing the fan to operate at its peak efficiency point on the P-Q curve without breaching the chamber's hermetic seal.

---

## 2. Flow Rate, Fluid Dynamics & Sensor Thermodynamics

With the internal mixing loop running independently at high capacity ($\sim 100-150 \text{ L/min}$), the system can be utilized as a passive, high-precision vacuum pump to draw the external VOC sample.

### 2.1 The Mathematics of the Sample Loop
The fan creates a localized low-pressure zone (suction) inside the top dome and a high-pressure zone (discharge) in the main chamber. When connected to an external sample jar, this $\Delta P$ drives the fluid exchange.

The sampling rate is strictly governed by the PTFE (Teflon) tubing acting as a flow restrictor. We calculate the theoretical flow rate using the Hagen-Poiseuille equation for fully developed, steady, incompressible, and laminar flow in a circular pipe:

$$Q = \frac{\Delta P \cdot \pi \cdot r^4}{8 \cdot \mu \cdot L}$$

Where:
* $\Delta P \approx 30 \text{ Pa}$ (Estimated static pressure differential generated by the 60mm axial fan)
* $r = 0.001 \text{ m}$ (Radius of standard 2mm ID PTFE tubing)
* $\mu \approx 1.81 \times 10^{-5} \text{ Pa}\cdot\text{s}$ (Dynamic viscosity of air at $20^\circ\text{C}$)
* $L \approx 0.5 \text{ m}$ (Total equivalent length of the sample loop tubing)

$$Q = \frac{30 \cdot 3.14159 \cdot (0.001)^4}{8 \cdot 1.81 \times 10^{-5} \cdot 0.5} \approx 1.3 \times 10^{-6} \text{ m}^3/\text{s}$$

Converting to standard laboratory volumetric flow:
**$Q \approx 78 \text{ mL/min}$**



The biquadratic relationship ($r^4$) is the critical factor. By utilizing 2mm internal diameter tubing instead of 4mm, the flow rate is restricted by a factor of 16, physically hard-limiting the system to approximately 80 mL/min regardless of minor fan speed variations.

### 2.2 MOX Sensor Thermodynamics & The "Thermal Drift" Problem
Why is a highly restricted flow of ~80 mL/min the optimal target for this system? The answer lies in the semiconductor physics of the sensors.

MQ-series gas sensors detect chemicals via an internal ceramic micro-tube coated with Tin Dioxide ($\text{SnO}_2$). An internal heating element must maintain the $\text{SnO}_2$ surface at a precise thermodynamic equilibrium of $\sim 300^\circ\text{C}$. At this temperature, oxygen ions ($O^-$) adsorb onto the surface, trapping electrons and increasing electrical resistance. When reducing VOC gases interact with these ions, electrons are released back into the conduction band, causing a measurable drop in resistance.


**The Threat of Forced Convection:**
If the sample flow rate is too high (e.g., $>500 \text{ mL/min}$), the velocity of the incoming fluid drastically increases the convective heat transfer coefficient ($h$). The incoming room-temperature air acts as a coolant, stripping thermal energy away from the sensor's micro-heater faster than the internal circuitry can compensate. 

As the surface temperature drops from $300^\circ\text{C}$ to $280^\circ\text{C}$, the baseline electrical resistance shifts violently due to thermal dynamics rather than chemical concentration. This creates irreversible "Thermal Drift" in the dataset.

By mathematically restricting the flow to **~80 mL/min**, the chamber effectively acts as a commercial Gas Chromatograph intake. It provides a steady, continuous "inhalation" of the VOC sample—updating the chamber's atmosphere much faster than the inherent response time ($t_{90}$) of the sensors—while ensuring the forced convection remains negligible. The thermal equilibrium of the micro-heaters is perfectly preserved, yielding laboratory-grade signal stability.

---

## 3. Component Overview

All components are fully parametric and designed for FDM printing with zero support structures.

1. flow_chamber.stl - The main 1.2L body with M3 heat-set standoffs, 2x PC4-M6 ports, and a wire-potting cup.
2. sensor_plate.stl - A universal breadboard platform (7mm grid) for mounting MQ, BME688, or custom PCBs.
3. diffuser_insert.stl - A tall 40mm drop-in honeycomb flow straightener with integrated pillars.
4. lid_pro.stl - The main aerodynamic lid housing the tangential ducts, return vents, and gasket grooves.
5. fan_dome_ultimate.stl - The aerodynamic top shell with suspended internal pillars, a PC4-M6 sample inlet port, and a sweeping internal cavity.
6. tpu_gaskets.stl - Two custom gaskets (151mm and 94mm) that guarantee a 100% hermetic seal between the layers.

---

## 4. Bill of Materials (BOM)

| Category | Item | Quantity | Notes |
| :--- | :--- | :--- | :--- |
| Filament | PETG / ABS / ASA | ~300g | Rigid parts (resists high sensor temps). |
| Filament | TPU (Flexible) | ~10g | Critical for the airtight custom gaskets. |
| Hardware | M3 Heat-Set Inserts | 12 pcs | OD ~4.2mm, L ~5.5mm. |
| Hardware | M3x50mm Bolts | 4 pcs | Secures the internal 40mm diffuser stack. |
| Hardware | M3x14mm Bolts | 8 pcs | Secures the main lid to the base. |
| Hardware | M4x35mm Bolts + Nuts | 4 pcs | Secures the fan and upper dome. |
| Pneumatics | PC4-M6 Fittings | 3-5 pcs | Standard 3D printer Bowden fittings. |
| Pneumatics | PTFE Tubing | 1-2 meters | 4mm OD / 2mm ID. |
| Pneumatics | PTFE Thread Tape | 1 roll | Standard plumber's Teflon tape for sealing threads. |
| Electronics| 60x60mm Axial Fan | 1 pc | 10mm to 20mm thickness. |
| Sealing | Silicone Sealant | 1 tube | Used for potting the sensor wires and sealing bolts. |

---

## 5. Crucial Print Settings (TPU Gaskets)

To ensure the printed TPU gaskets do not leak air through micro-gaps, adjust your slicer settings as follows:
* Flow/Extrusion Multiplier: 106% - 108% (Over-extrusion seals the layers).
* Wall Loops/Perimeters: 5 or 6 (The gasket must be 100% solid walls).
* Top/Bottom Pattern: Concentric (Crucial! Do not use zig-zag/lines).
* Print Speed: 20 mm/s.

---

## 6. Assembly & Sealing Instructions

Vacuum-grade sealing requires careful attention during assembly. 

1. Heat-Set Inserts: Melt the 12 M3 inserts into the base (8 on the top flange, 4 on the internal bottom standoffs).
2. Pneumatic Fittings: Wrap the threads of all PC4-M6 fittings with 2-3 layers of PTFE (Teflon) tape. Thread them firmly into the printed plastic (1 on the dome, 2 on the base). The tape fills the micro-channels between printed layers.

3. Sensors & Wiring: Mount your sensors to the sensor_plate. Route the wire loom through the square cutout, out the wall hole, and into the external potting cup. 
4. Internal Stack: Place the sensor_plate on the bottom standoffs. Place the 40mm diffuser_insert on top (legs pointing down). Secure both to the base using the four long M3x50mm bolts.
5. Wire Potting: Fill the external wire cup entirely with silicone sealant. Ensure it penetrates between the wires. Let it cure fully.
6. Gaskets: Insert the large TPU gasket into the bottom of lid_pro. Insert the smaller 94mm TPU gasket into the top groove of the lid.
7. Seal the Base: Bolt lid_pro to the base using eight M3x14mm bolts. Tighten in a cross-pattern to compress the gasket evenly.
8. Fan & Dome: Drop the 60mm fan into the lid recess (exhaust sticker pointing DOWN). Route the fan wire out the side hole of fan_dome_ultimate. 
9. Dome Sealing: Place a tiny dab of silicone (or a micro TPU washer) under the head of each M4x35mm bolt before inserting them into the dome. This prevents air from spiraling up the threads due to the internal vacuum. Tighten the dome down. Seal the tiny wire hole with a dab of silicone.
10. Final Loop: Connect your sample jar. You can use the top dome port for intake, one base port for the return line, and plug the second base port (or use it as a clean-air flush valve).

> Important Operation Note: Brand new MQ-series sensors require a continuous 48-hour burn-in period (powered at 5V in clean air) to stabilize their internal SnO2 heating elements before gathering baseline data.
