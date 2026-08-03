# Blase & Darm Manager

Eine barrierefreie App zur Protokollierung von Blasen- und Darmentleerung –
gedacht für Menschen mit neurogener Blase/Darm (z. B. nach Querschnittlähmung),
für Angehörige und Pflegende.

Website: <https://blaseunddarm.de> · Hintergrund: <https://ploetzlich-querschnitt.de>

> **Lizenz: PolyForm Noncommercial 1.0.0** – der Quelltext ist offen einsehbar
> und darf privat/nicht-kommerziell genutzt und verändert werden, aber **nicht
> kommerziell verwertet oder verkauft** werden. Details unten und in [`LICENSE`](LICENSE).

---

## Was ist das?

Der Blase & Darm Manager hilft dabei, Miktion und Stuhlgang festzuhalten,
Erinnerungen zu setzen und Verläufe auszuwerten – mit Fokus auf Bedienbarkeit
(VoiceOver, Dynamic Type, große Tap-Ziele, Dunkelmodus).

Gemeinsame Funktionen beider Plattformen: Erinnerungstimer, Ruhezeiten,
Statistiken, PDF-Bericht, CSV-Import/-Export, Datensicherung, Deutsch/Englisch.

Die Daten bleiben auf dem Gerät bzw. in der persönlichen iCloud – es gibt keine
Server-Konten und kein Tracking. Wer das nachprüfen möchte, kann genau dafür
in diesen Quelltext schauen.

## Repo-Struktur

```
.
├── ios/       SwiftUI-App (iPhone, Apple Watch, Widget, CarPlay, Siri, iCloud)
├── android/   Kotlin/Jetpack-Compose-App
├── LICENSE
└── README.md
```

## Bauen

**iOS** (`ios/`) – das Xcode-Projekt wird per [XcodeGen](https://github.com/yonaskolb/XcodeGen)
aus `project.yml` erzeugt (die `.xcodeproj` ist bewusst nicht eingecheckt):

```bash
cd ios
xcodegen generate
open BlaseUndDarm.xcodeproj
```

**Android** (`android/`):

```bash
cd android
./gradlew assembleRelease
```

Signierschlüssel (`keystore.properties`, `*.jks`) sind **nicht** Teil des
Repos und müssen lokal ergänzt werden.

## Lizenz – was erlaubt ist und was nicht

Dieses Projekt steht unter der **PolyForm Noncommercial License 1.0.0**. Das ist
eine *source-available*-Lizenz, kein klassisches OSI-Open-Source. Kurz gefasst:

- ✅ Ansehen, ausprobieren, lernen, für private Zwecke nutzen und anpassen
- ✅ Nutzung durch gemeinnützige, Bildungs-, Gesundheits- und öffentliche Einrichtungen
- ❌ **Kommerzielle Verwertung**, insbesondere die App (ganz oder in Teilen) zu
  verkaufen oder als kostenpflichtiges bzw. werbefinanziertes Produkt anzubieten

Der vollständige Text steht in [`LICENSE`](LICENSE).

Die offiziellen Fassungen im App Store und in Google Play werden ausschließlich
vom Rechteinhaber herausgegeben.

## Name, Logo und Screenshots

Der Name „Blase & Darm Manager", das App-Icon, das Erscheinungsbild und die
Screenshots sind **nicht** Teil dieser Lizenz. Sie dürfen nicht verwendet
werden, um den Eindruck einer offiziellen oder verbundenen App zu erwecken.

*Apple, App Store, Apple Watch und CarPlay sind Marken von Apple Inc.
Google Play ist eine Marke von Google LLC. Android ist eine Marke von Google LLC.*

## Kein Medizinprodukt

Diese App ist **kein Medizinprodukt** und ersetzt keine ärztliche oder
pflegerische Beratung, Diagnose oder Behandlung. Sie dient ausschließlich der
persönlichen Dokumentation. Bei gesundheitlichen Fragen oder Warnzeichen bitte
ärztlichen Rat einholen. Die Nutzung erfolgt auf eigene Verantwortung; es wird
keine Gewähr für Richtigkeit oder Eignung übernommen.

## Mitwirken

Rückmeldungen und Pull Requests sind willkommen, aber es gibt **kein
Support-Versprechen** und keine Zusage, Beiträge zu übernehmen.

Wenn du einen Beitrag einreichst (Pull Request, Patch o. Ä.), räumst du André
Bajorat das dauerhafte, unwiderrufliche Recht ein, deinen Beitrag zu nutzen, zu
verändern und zu verbreiten – auch in den offiziellen App-Store- und
Google-Play-Fassungen, unabhängig von der Noncommercial-Beschränkung dieser
Lizenz. So bleibt sichergestellt, dass eingereichte Verbesserungen auch in den
Store-Versionen ausgeliefert werden können.

## Kontakt

Über das Feedback-Formular bzw. den Kontakt auf <https://blaseunddarm.de>.
