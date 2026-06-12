# SKILL: Flutter Design + Liquid Glass в Antigravity

## Что это
Этот файл — инструкция для работы с Antigravity при создании красивого Flutter UI.
Покрывает: структуру промптов, дизайн-систему, liquid glass эффекты и типичные ошибки.

---

## ЧАСТЬ 1 — Как правильно промптить Antigravity

### Золотое правило
Antigravity — агент, не чат-бот. Он ВЫПОЛНЯЕТ команды автономно.
Плохой промпт → сломанная архитектура, которую сложно откатить.

### Формула каждого промпта
```
CONTEXT + GOAL + CONSTRAINTS + VERIFICATION
```

### Шаблон промпта (копируй и заполняй)
```
## Context
[Что уже есть в проекте, какой экран делаем, какая цветовая схема]

## Goal
[Конкретная задача одним предложением]

## Requirements
- UI: [описание дизайна, цвета, шрифты]
- Behavior: [что происходит при тапе, свайпе и т.д.]
- State: [какие состояния у компонента]
- Packages: [какие пакеты использовать]

## Constraints
- НЕ менять файлы вне папки [указать]
- НЕ использовать [запрещённые пакеты]
- Использовать [state management: Riverpod / BLoC / setState]

## Verification
Before writing any code — generate a plan with:
1. List of files to create/modify
2. Widget tree structure
3. Required dependencies
Ask for approval before proceeding.
```

### Правила работы с агентом
- **Одна задача за раз** — не давай 5 экранов одним промптом
- **Plan first** — всегда проси план перед кодом, иначе агент наломает
- **Review-driven** — включи "Review-driven development" в настройках
- **Approve команды** — особенно `flutter pub add` и `rm`
- **Итерируй** — после каждого экрана: запусти, посмотри, дай фидбек

---

## ЧАСТЬ 2 — Дизайн-система для "Второе Я"

### Цвета (вставляй в каждый промпт)
```dart
// lib/theme/app_colors.dart
class AppColors {
  // Фоны
  static const background    = Color(0xFF0E0E0E); // основной фон
  static const surface       = Color(0xFF131313); // карточки
  static const surfaceRaised = Color(0xFF161616); // приподнятые элементы

  // Границы
  static const border        = Color(0xFF1E1E1E);
  static const borderSubtle  = Color(0xFF161616);

  // Текст
  static const textPrimary   = Color(0xFFF0F0F0);
  static const textSecondary = Color(0xFFC8C8C8);
  static const textMuted     = Color(0xFF666666);
  static const textDisabled  = Color(0xFF3A3A3A);

  // Акцент (только один!)
  static const accent        = Color(0xFFD4FF4A); // лайм
  static const accentDim     = Color(0xFF1A2A06); // фон активных элементов
  static const accentBorder  = Color(0xFF4A6A10); // граница активных
}
```

### Типографика
```dart
// Заголовки и названия → Google Fonts: Playfair Display (serif)
// Лейблы и мета → monospace (courier, roboto mono)
// Основной текст → Inter / Roboto

dependencies:
  google_fonts: ^6.2.1

// Использование:
Text('Второе Я', style: GoogleFonts.playfairDisplay(
  fontSize: 20, color: AppColors.textPrimary,
))

Text('НАПОМИНАНИЯ', style: GoogleFonts.robotoMono(
  fontSize: 9, letterSpacing: 2, color: AppColors.textMuted,
))
```

### Базовые размеры
```
border-radius карточек:   10px
border-radius кнопок:     14px
border-radius bottom sheet: 20px
padding экрана:           16px горизонтальный
gap между карточками:     6px
высота toggle:            13px × 24px
```

---

## ЧАСТЬ 3 — Liquid Glass в Flutter

### Выбор пакета

| Пакет | Когда использовать | Платформы |
|-------|-------------------|-----------|
| `liquid_glass_widgets` | Готовые виджеты (карточки, кнопки, nav) | iOS, Android, macOS, Web, Desktop |
| `liquid_glass_renderer` | Кастомные формы, экспериментально | Только Impeller (iOS/Android) |
| `BackdropFilter` (встроенный) | Простое матовое стекло, без шейдеров | Все платформы |

**Для большинства случаев используй `liquid_glass_widgets`** — стабильнее и не требует Impeller.

### Установка
```yaml
# pubspec.yaml
dependencies:
  liquid_glass_widgets: ^0.10.2
```

### Обязательная инициализация
```dart
// main.dart — ОБЯЗАТЕЛЬНО, иначе шейдеры не загрузятся
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(const MyApp()));
  // wrap() добавляет GlassBackdropScope в корень — нужен для всех glass виджетов
}
```

### Виджеты библиотеки (37 штук, 5 категорий)

**Containers (контейнеры)**
```dart
GlassCard(child: ...)          // карточка
GlassPanel(child: ...)         // панель
GlassContainer(child: ...)     // базовый контейнер
GlassDivider()                 // разделитель
GlassListTile(...)             // элемент списка
GlassStepper(...)              // степпер
GlassWizard(...)               // визард
```

**Interactive Controls (интерактив)**
```dart
GlassButton(onPressed: ..., child: ...)
GlassIconButton(icon: ..., onPressed: ...)
GlassSwitch(value: ..., onChanged: ...)
GlassSlider(value: ..., onChanged: ...)
GlassCheckbox(value: ..., onChanged: ...)
GlassRadio(...)
GlassSegmentedControl(...)
GlassChip(label: ...)
```

**Inputs (поля ввода)**
```dart
GlassTextField(controller: ...)
GlassSearchField(...)
GlassDropdown(...)
```

**Overlays (оверлеи)**
```dart
GlassDialog(...)
GlassBottomSheet(...)
GlassToast(...)
GlassSnackBar(...)
GlassPopover(...)
GlassModal(...)
```

**Surfaces (навигация)**
```dart
GlassAppBar(...)
GlassBottomBar(...)
GlassNavigationBar(...)
GlassTabBar(...)
GlassDrawer(...)
GlassSearchableBottomBar(...)  // iOS 26 стиль с морфингом
```

### Примеры кода

**Карточка напоминания с glass эффектом**
```dart
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

GlassCard(
  borderRadius: BorderRadius.circular(12),
  blur: 20,
  opacity: 0.15,
  child: Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Text('🦴', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Выровняй спину',
              style: GoogleFonts.playfairDisplay(
                color: AppColors.textSecondary, fontSize: 12)),
            Text('каждые 30 мин',
              style: GoogleFonts.robotoMono(
                color: AppColors.textMuted, fontSize: 8)),
          ],
        ),
        const Spacer(),
        GlassSwitch(value: true, onChanged: (v) {}),
      ],
    ),
  ),
)
```

**Glass кнопка запуска (большая)**
```dart
GlassButton(
  onPressed: () => toggleActive(),
  borderRadius: BorderRadius.circular(14),
  glassColor: isActive
    ? const Color(0xFFD4FF4A)
    : Colors.transparent,
  blur: isActive ? 0 : 20,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isActive ? 'Режим активен' : 'Запустить себя',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  color: isActive ? Colors.black : AppColors.accent,
                ),
              ),
              Text(
                isActive ? '2ч 14м · всё работает' : 'нажми чтобы начать',
                style: GoogleFonts.robotoMono(
                  fontSize: 8,
                  color: isActive
                    ? Colors.black54
                    : AppColors.textDisabled,
                ),
              ),
            ],
          ),
        ),
        GlassIconButton(
          icon: Icon(
            isActive ? Icons.pause : Icons.play_arrow,
            color: isActive ? Colors.black : AppColors.accent,
          ),
          onPressed: toggleActive,
        ),
      ],
    ),
  ),
)
```

**Glass bottom sheet (настройки напоминания)**
```dart
showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  builder: (ctx) => GlassBottomSheet(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    blur: 40,
    opacity: 0.85,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // drag handle
          Container(
            width: 28, height: 2,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // контент настроек...
        ],
      ),
    ),
  ),
);
```

**Glass navigation bar**
```dart
GlassNavigationBar(
  blur: 30,
  opacity: 0.7,
  selectedIndex: _currentIndex,
  onDestinationSelected: (i) => setState(() => _currentIndex = i),
  destinations: const [
    GlassNavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'главная',
    ),
    GlassNavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label: 'AI',
    ),
    GlassNavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'профиль',
    ),
  ],
)
```

---

## ЧАСТЬ 4 — Без пакета: BackdropFilter (простое стекло)

Если не хочешь пакет — встроенный Flutter способ:

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: /* твой контент */,
    ),
  ),
)
```

---

## ЧАСТЬ 5 — Производительность (важно!)

### Правила
- **Не более 5-7 glass виджетов на одном экране** — GPU не справится
- **FakeGlass для невидимых элементов** — оффскрин карточки заменяй
- **GlassAdaptiveScope** — автоматически снижает качество на слабых устройствах
- **Тестируй на реальном девайсе** — эмулятор не показывает реальную нагрузку
- **Impeller обязателен** для liquid_glass_renderer (включён по умолчанию iOS/Android)

```dart
// Для сложных скроллящихся списков — используй FakeGlass
GlassCard(
  useFakeGlass: !isVisible, // переключай по видимости
  child: ...,
)

// Глобальное управление качеством
GlassAdaptiveScope(
  adaptiveQuality: true, // экспериментально, но работает
  child: MyApp(),
)
```

---

## ЧАСТЬ 6 — Готовые промпты для Antigravity

### Промпт: главный экран
```
## Context
Flutter app "Второе Я" — health discipline tracker.
Dark theme. Colors: background #0E0E0E, accent #D4FF4A.
Using: google_fonts (Playfair Display + Roboto Mono), liquid_glass_widgets.

## Goal
Build the main HomeScreen widget.

## Requirements
UI:
- Newspaper-style masthead: "Второе Я" in Playfair Display,
  lime top border, monospace subtitle
- Date row: italic date left + lime streak pill right
- Large GlassButton: "Запустить себя" / "Режим активен" toggle
- Section header "НАПОМИНАНИЯ" + small "+" GlassIconButton
- ListView of ReminderCard widgets (GlassCard + toggle)

State:
- isActive: bool (button state)
- reminders: List<Reminder> (title, icon, frequency, isOn)

Behavior:
- Button tap → toggles isActive
- Reminder tap → opens ReminderSettingsSheet (bottom sheet)
- "+" tap → opens AddReminderSheet

## Constraints
- Use setState for local state (no Riverpod yet)
- Do NOT create files outside lib/screens/ and lib/widgets/
- Use GlassCard for reminder items
- DO NOT add bottom navigation (added later)

## Verification
Before any code — show me:
1. File structure
2. Widget tree
3. pubspec.yaml changes needed
Await approval.
```

### Промпт: экран настройки напоминания
```
## Context
Same app. HomeScreen exists. Need reminder settings bottom sheet.

## Goal
Create ReminderSettingsSheet — a GlassBottomSheet with:
1. Reminder title (Playfair Display, large)
2. Notification type selector: 3 GlassCards (звук/вибрация/оба)
3. Tape ruler picker for frequency (custom widget, horizontal scroll)
4. Unit toggle: МИН / ЧАС (GlassSegmentedControl)
5. Large lime GlasButton "Сохранить"

## Requirements
Tape ruler:
- Custom StatefulWidget using GestureDetector + CustomPainter
- Tick marks: major every 5 units, minor every 1
- Selected value highlighted in #D4FF4A
- Fade masks on edges (gradient overlay)
- Snaps to nearest value on release

## Constraints
- Returns selected Reminder via Navigator.pop(result)
- GlassBottomSheet blur: 40, opacity: 0.9
- No external packages for the ruler (CustomPainter only)

## Verification
Plan first, then code.
```

### Промпт: добавить liquid glass
```
## Context
App has working HomeScreen with plain dark cards.
I want to upgrade cards to use liquid_glass_widgets.

## Goal
Replace all plain Container cards with GlassCard.
Add GlassNavigationBar at bottom.

## Requirements
- flutter pub add liquid_glass_widgets
- Initialize in main.dart (LiquidGlassWidgets.initialize + wrap)
- ReminderCard → GlassCard (blur:20, opacity:0.12)
- Launch button → GlassButton
- Bottom nav → GlassNavigationBar (3 items: главная, AI, профиль)
- Limit: max 6 glass widgets visible at once

## Constraints
- Keep same colors (no white glass — keep dark tint)
- Test on physical device before committing
- Add GlassAdaptiveScope to main widget tree

## Verification
Show diff of changed files before executing.
```

---

## ЧАСТЬ 7 — Типичные ошибки

| Ошибка | Причина | Решение |
|--------|---------|---------|
| Белые/серые артефакты на glass | Skia вместо Impeller | Проверь `flutter build` с `--enable-impeller` |
| `LiquidGlassWidgets not initialized` | Забыл `await initialize()` | Добавь в `main()` до `runApp` |
| Низкий FPS на android | Слишком много glass виджетов | Уменьши количество, используй FakeGlass |
| Glass не видно | Фон слишком тёмный | Добавь gradient background или image за стеклом |
| Агент сломал архитектуру | Промпт без constraints | Всегда указывай какие файлы НЕ трогать |
| Агент не спросил план | Нет явного запроса | Добавь "Await approval before any code" |

---

## Быстрая шпаргалка

```
Antigravity промпт:    Context → Goal → Requirements → Constraints → Verification
Всегда проси:          "generate a plan and await approval"
Liquid glass пакет:    liquid_glass_widgets (стабильный, все платформы)
Инициализация:         await LiquidGlassWidgets.initialize() + .wrap()
Макс. виджетов:        5-7 на экран
Шрифты:                Playfair Display (serif) + Roboto Mono (labels)
Акцент:                #D4FF4A только на важных элементах
```
