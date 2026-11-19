# Sunshine OS VM test — release under test (2026-11-19)

- Release: **Sunshine OS 13.4.7.1.5 (Release, 2026-11-19)** (`v13.4.7.1.5-release-2026-11-19`, published 2026-11-19T10:10:30Z).
- Site: https://tak0dan.github.io/sunshineos-site/
- Release page: https://github.com/tak0dan/SunshineOS/releases/tag/v13.4.7.1.5-release-2026-11-19
- ISO is published in two parts (GitHub 2 GiB asset limit) and joined locally as
  `SunshineOS_13.4.7.1.5_Release_2026-11-19.iso`.

| Asset | Size | SHA-256 (from release API) |
|---|---:|---|
| `.iso.part1` | 1,992,294,400 B | `ccd81b4a3e7cb59255f62556e6e0760ea2716e228ecb7a25d28553a3cb73e044` |
| `.iso.part2` | 1,522,565,120 B | `aef64ac6478129ce660d9f931ad2179f758ba9bd244f1bf650787a8333451593` |
| `.iso.sha256` | 111 B | `e603570a56e082f8007b10c8d12dd4e4d5ff8cbb9f9a9f1107976c2c1900a4f7` |

The two-part download finished at 16:11 on 2026-11-19 and the joined ISO verified OK:

```text
9cb5bc4c9353bac04f3ed867600752e9dd21e2c83d5bb75a91ad4b87be44a7a5  SunshineOS_13.4.7.1.5_Release_2026-11-19.iso
SunshineOS_13.4.7.1.5_Release_2026-11-19.iso: OK
```

Join/check commands:

```bash
cat SunshineOS_13.4.7.1.5_Release_2026-11-19.iso.part* > SunshineOS_13.4.7.1.5_Release_2026-11-19.iso
sha256sum -c SunshineOS_13.4.7.1.5_Release_2026-11-19.iso.sha256
```

Previous test (for comparison): `logs/VM_Test_Report_2026-11-18/` on release 13.4.7.1.4 (2026-11-17).
This run repeats the same workflow on a fresh VM: live-session testing, updates, OS tools,
theme/design review, installation to disk, reboot verification, and per-step commits.
