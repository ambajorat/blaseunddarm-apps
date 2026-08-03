# statt-Tipex — Digitaler Schichtplaner für Zahnarztpraxen

Web-App zur Schicht- und Personalplanung in Zahnarztpraxen. Ersetzt Papierpläne
und Excel durch einen digitalen Wochenplan mit automatischer Planung,
Abwesenheitsverwaltung und WhatsApp-Versand.

Live: <https://statt-tipex.de>

## Überblick

- **Single-File-App:** Die komplette Anwendung steckt in `server/index.html`
  (vorkompiliertes React über `React.createElement`, kein Build-Schritt).
  Zum Ändern wird direkt diese Datei bearbeitet und deployt.
- **Backend:** Firebase Realtime Database (Daten) + Firebase Authentication
  (Login). Kein eigener Server-Code — nur statisches Hosting via Nginx.
- **Mandantenfähig:** Jede Praxis hat einen Code; die Daten liegen unter
  `tenants/{CODE}/…`.

## Funktionen

- Wochenplan mit Stationen (Empfang, Büro, Behandlungszimmer, Steri, Prophylaxe,
  Springer) und automatischem Vorschlag (Arzt-Assistenz-Paarung, faire Verteilung).
- Team-Verwaltung mit Rollen (Arzt, ZFA, ZMP, ZMV, Azubi), Verfügbarkeiten pro
  Wochentag und **Ausnahmen** (z. B. Berufsschule: pro Wochentag andere Zeit oder frei).
- **Abwesenheiten** (Urlaub, Krank, Fortbildung, Überstunden-Abbau, Sonstiges);
  nur „Urlaub" zählt gegen die Urlaubstage.
- **Sonderöffnungszeiten** als Datumsbereich oder einzelner Sondertag; Knopf
  „Außerh. Öffnungszeiten räumen" entfernt Schichten außerhalb der Öffnungszeiten,
  ohne den ganzen Plan neu zu generieren.
- WhatsApp-Versand persönlicher Wochenpläne, Urlaubsanträge mit Freigabe,
  Echtzeit-Sync über alle Geräte.

## Login & Rollen

Der Zugang pro Praxis erfolgt über **Praxis-Code + Name + Passwort**
(Firebase Authentication; intern wird eine synthetische E-Mail
`name@praxiscode.stattipex.local` verwendet).

Drei Rollen:

- **Admin** — Vollzugriff, kann Nutzer verwalten (Einstellungen → „Zugang & Nutzer").
- **Nutzer** — kann den Plan bearbeiten.
- **Nur ansehen** — reiner Lesezugriff, Bearbeiten ist gesperrt.

Wer eine Praxis absichert, wird ihr erster Admin. Ein Banner in der App führt
unabgesicherte Praxen einmalig durch das Einrichten.

## Deployment

Statisches Hosting via Nginx, Web-Root `/var/www/statt-tipex/`.
Host, SSH-User und Zugangsdaten stehen bewusst **nicht** im Repo — unten die
Platzhalter `<user>` und `<server>` durch die echten Werte ersetzen.

Auf dem Mac hochladen:

```bash
scp ~/Downloads/index.html <user>@<server>:~/index.html
```

Auf dem Server an ihren Platz verschieben (braucht sudo, da `/var/www` root gehört):

```bash
ssh <user>@<server>
sudo mv ~/index.html /var/www/statt-tipex/index.html
```

Danach im Browser mit `Cmd+Shift+R` hart neu laden.

## Firebase Security Rules

Die Rules regeln die eigentliche Zugriffskontrolle. Sie liegen **nicht** im Git,
sondern werden in der Firebase Console (Realtime Database → Regeln) gepflegt.
Aktueller Stand:

```json
{
  "rules": {
    "tenants": {
      "DEMO": { ".read": true, ".write": true },
      "$tid": {
        ".read": "auth != null && root.child('tenantMembers').child($tid).child(auth.uid).exists()",
        ".write": "auth != null && root.child('tenantMembers').child($tid).child(auth.uid).exists() && root.child('tenantMembers').child($tid).child(auth.uid).child('role').val() != 'viewer'"
      }
    },
    "tenantMembers": {
      "$tid": {
        ".read": "auth != null && data.child(auth.uid).exists()",
        "$uid": {
          ".write": "auth != null && ( root.child('tenantMembers').child($tid).child(auth.uid).child('role').val() == 'admin' || ( !data.parent().exists() && $uid == auth.uid ) )"
        }
      }
    },
    "tenantSecured": {
      ".read": true,
      "$tid": {
        ".write": "auth != null && ( !data.exists() || root.child('tenantMembers').child($tid).child(auth.uid).child('role').val() == 'admin' )"
      }
    },
    "feedback": { ".read": true, ".write": true }
  }
}
```

Hinweise:

- `DEMO` und `feedback` bleiben bewusst offen (öffentliche Demo bzw. Beta-Feedback).
- `tenantSecured/{CODE}` ist ein öffentlich lesbares Boolean, damit der Client vor
  dem Login weiß, ob eine Praxis Anmeldung verlangt.
- Beim Ausrollen neuer Rules gilt: **erst** alle aktiven Praxen absichern
  (Admin-Konto anlegen), **dann** die Rules scharf schalten — sonst sperren sich
  bestehende Praxen aus, bis sie ein Konto haben.

## Datenstruktur (Realtime Database)

```
tenants/{CODE}/
  praxis-staff          Team (Array von Mitarbeiter-Objekten)
  praxis-hours          Sonderöffnungszeiten
  praxis-standard-week  Standardwoche
  praxis-station-reqs   Stationen-Bedarf
  praxis-vacations      Abwesenheiten
  praxis-wk-YYYY-MM-DD   Wochenplan je Woche
  praxis-pin / praxis-unlocked
tenantMembers/{CODE}/{uid}   { name, role, created }
tenantSecured/{CODE}         true
feedback/{ts}                Beta-Feedback
```

## Bekannte offene Punkte

- Rollen-Wechsel eines bestehenden Nutzers geht nur über Entfernen + Neu-Anlegen.
- Admin kann Passwörter anderer nicht zurücksetzen (bräuchte eine Cloud Function).
- Für Nur-Lese-Nutzer sind Bearbeiten-Knöpfe noch sichtbar, aber wirkungslos
  (nichts wird gespeichert; serverseitig ohnehin blockiert).

## Changelog

### 2026-08
- **Login & Rollen:** Anmeldung pro Praxis über Firebase Authentication
  (Praxis-Code + Name + Passwort), Nutzerverwaltung, „Praxis absichern"-Banner.
  Rollen **Admin / Nutzer / Nur ansehen**.
- **Nur-Lese-Rolle:** Viewer sieht alles, kann aber nichts ändern
  (Client-Sperre + Security Rule).
- **Abwesenheiten:** neuer Typ **Überstunden-Abbau** (eigene Farbe; zählt nicht
  gegen die Urlaubstage).
- **Sonderöffnungszeiten:** einzelner **Sondertag** (offen mit Zeit oder
  geschlossen) mit Vorrang vor Datumsbereichen; Knopf **„Außerh.
  Öffnungszeiten räumen"** zum Aufräumen ohne Neu-Generieren.
- **Wochenarbeitszeit:** Übersicht der verplanten Wochenstunden pro Person im
  Team-Tab (läuft runter, „+X“ bei Überschreitung); Warn-Banner im Plan, wenn
  manuell über die Wochenarbeitszeit geplant wird; der Auto-Vorschlag hält die
  Wochenarbeitszeit ein.
- **Mitarbeiter-Ausnahmen:** pro Wochentag abweichende Zeit oder frei
  (z. B. Berufsschule) — nur gesetzte Tage werden überschrieben.
- **Kleinkram:** Team-Ansicht alphabetisch nach Vorname; Rollenbezeichnung
  **ZMP** korrigiert (vorher ZNP); Enter/Return in Login- und Code-Feldern.

## Lizenz

[MIT](LICENSE) © 2026 André Bajorat.

Frei nutz-, änder- und weiterverteilbar unter den Bedingungen der MIT-Lizenz;
Details in der `LICENSE`-Datei. Wer den Code weiterverwendet, muss lediglich
den Copyright- und Lizenzhinweis beibehalten.
