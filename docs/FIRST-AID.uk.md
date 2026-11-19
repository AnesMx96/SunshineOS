# Щось зламалося. Що робити?

Усі наведені нижче команди існують у Sunshine OS і були перевірені у віртуальній машині. Починайте з першого рядка й зупиніться, коли проблему усунено.

| Ситуація | Що робити |
| --- | --- |
| **Комп’ютер не вмикається** (чорний екран, помилка GRUB, «no initramfs») | Завантажтеся з флешки Sunshine OS, оберіть «живий сеанс». Відкрийте вікно Welcome й натисніть **Відремонтувати встановлену систему** (або виконайте `sudo sunshine-rescue repair`). Він знайде вашу систему, перевірить диск, відбудує файли ядра та меню завантаження й збереже журнал у `/var/log/sunshine/` на вашій системі. Перезавантажтеся без флешки. |
| **Чорний екран одразу після логотипу** | У меню завантаження оберіть **безпечну графіку (nomodeset)**. Потім виконайте `sudo sunshine-drivers detect`; власники NVIDIA: `sudo sunshine-drivers install`. |
| **Забув пароль** | У живому сеансі: `sudo sunshine-rescue passwd YOURNAME`. |
| **Оновлення щось зламало** | У меню завантаження оберіть точку відновлення (системи з btrfs) або виконайте `sunshine-snapshot list` і відновіться. Потім `sudo sunshine-doctor --fix`. |
| **Оновлення зупиняється з помилками ключів чи бази даних** | `sudo sunshine-fix-pacman`, потім знову `sunshine-update`. |
| **Вигляд середовища змінився** (немає значків, панелі, кольори не ті) | `sunshine-reset-plasma` (спочатку ваші налаштування зберігаються; `--undo` повертає їх). |
| **Немає звуку / немає мережі / немає зображення на другому моніторі / повільна графіка / диск заповнений** | `sunshine-fix audio`, `sunshine-fix network`, `sunshine-fix display`, `sunshine-fix gpu`, `sunshine-fix storage` (або `sunshine-fix all`). |
| **Я не знаю, що зламалося** | `sudo sunshine-doctor` (перевірка без змін) і `sunshine-support` (створить звіт без ваших особистих даних, щоб надіслати тому, хто допомагає). |
| **Завантажується не те ядро / я хочу інше ядро** | `sudo sunshine-kernel list`, `sudo sunshine-kernel install linux-lts`, `sudo sunshine-kernel default linux-lts`. |
| **Ігри працюють погано** | `sudo sunshine-gaming install`, `sudo sunshine-performance on`; у параметрах запуску Steam: `sunshine-game-run %command%`. |
| **Я хочу інше середовище** | `sudo sunshine-desktops list`, `sudo sunshine-desktops install gnome`; оберіть його на екрані входу. |
| **Я хочу захистити свої файли** | `sunshine-backup init /path/to/backup-folder`, потім `sunshine-backup run`; `sunshine-backup schedule on` — для щоденної копії. |

## Добре знати

- `sudo sunshine-doctor --fix` спочатку створює точку відновлення (btrfs), виправляє лише те, що безпечно, і ніколи не видаляє ваші файли.
- Інструменти оновлюються самі: `sunshine-update` спочатку завантажує найновіші підписані інструменти. `sudo sunshine-toolsync status` показує версію, а `rollback` скасовує останнє оновлення інструментів.
- Файрвол увімкнено (вхідні з’єднання заборонені, KDE Connect і виявлення дозволені). Відкрийте порт через `sudo ufw allow PORT`; вимкніть його остаточно за допомогою `sudo touch /etc/sunshine/no-firewall`.
- Якщо ремонт неможливо виконати безпечно, він зупиняється й повідомляє про це; він не вгадує розділ і не перезаписує `fstab` навмання.
