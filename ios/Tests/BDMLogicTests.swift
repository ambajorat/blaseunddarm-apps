import XCTest
@testable import Blase_und_Darm

/// Logik-Regressionstests — festgenagelt nach den Zähl-/Takt-Bugs vom 22.08.
/// Kernregeln: Gang = urineMl > 0 (Hinweise) bzw. Urin ODER Stuhl (Statistik);
/// Trink-/Symptom-Einträge zählen nie und takten nie.
final class BDMLogicTests: XCTestCase {

    private let cal = Calendar.current

    /// Eintrag mit Zeitversatz in Tagen (negativ = Vergangenheit) und Minuten.
    private func entry(daysAgo: Int, minute: Int = 0, urine: Int = 0,
                       bowel: Bool = false, drink: Int? = nil,
                       sort: String? = nil) -> ToiletEntry {
        let day = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: .now))!
        let ts = cal.date(byAdding: .minute, value: 8 * 60 + minute, to: day)!
        return ToiletEntry(timestamp: ts, urineMl: urine, bowel: bowel,
                           drinkMl: drink, catheterSort: sort)
    }

    // MARK: - Fix12: Statistik zählt Toilettengänge (Urin ODER Stuhl)

    func testVisitCountIgnoriertTrinkEintraege() {
        let entries = [
            entry(daysAgo: 0, minute: 0, urine: 200),
            entry(daysAgo: 0, minute: 30, urine: 150),
            entry(daysAgo: 0, minute: 60, bowel: true),          // reiner Stuhlgang
            entry(daysAgo: 0, minute: 90, drink: 250),           // Kaffee
            entry(daysAgo: 0, minute: 120, drink: 200),
            entry(daysAgo: 0, minute: 150, drink: 100),
        ]
        let day = DaySummary(id: "t", date: .now, entries: entries)
        XCTAssertEqual(day.count, 6, "Eintragszahl bleibt die Gesamtzahl")
        XCTAssertEqual(day.visitCount, 3, "Gänge = Urin oder Stuhl, ohne Trinken")
        XCTAssertEqual(day.bowelCount, 1)
        XCTAssertEqual(day.totalMl, 350)
    }

    // MARK: - Fix11: Hinweise-Schnitt zählt nur Miktionen

    func testBaselineZaehltNurMiktionen() {
        var entries: [ToiletEntry] = []
        for i in 1...5 {                                          // 5 volle Vortage
            entries.append(entry(daysAgo: i, minute: 0, urine: 200))
            entries.append(entry(daysAgo: i, minute: 60, urine: 200))
            entries.append(entry(daysAgo: i, minute: 30, drink: 300))
            entries.append(entry(daysAgo: i, minute: 90, drink: 300))
        }
        let base = AlertEngine.baseline(entries: entries)
        XCTAssertNotNil(base)
        XCTAssertEqual(base?.avgCount, 2.0, "Kaffees blähen den Gänge-Schnitt nicht auf")
        XCTAssertEqual(base?.avgMl, 400)
        XCTAssertEqual(base?.days, 5)
    }

    func testNurTrinkTagIstKeinDatentag() {
        var entries: [ToiletEntry] = []
        for i in 1...5 {
            entries.append(entry(daysAgo: i, minute: 0, urine: 400))
        }
        entries.append(entry(daysAgo: 6, minute: 0, drink: 500))  // Tag nur mit Trinken
        let base = AlertEngine.baseline(entries: entries)
        XCTAssertEqual(base?.days, 5, "Ein Nur-Trink-Tag ist kein Protokolltag")
        XCTAssertEqual(base?.avgMl, 400, "…und drückt den Urin-Schnitt nicht auf 0")
    }

    func testBaselineBrauchtFuenfDatentage() {
        var entries: [ToiletEntry] = []
        for i in 1...4 { entries.append(entry(daysAgo: i, urine: 300)) }
        XCTAssertNil(AlertEngine.baseline(entries: entries))
    }

    // MARK: - Fix1/4.7: Fälligkeits-Rechnung (eine Wahrheit für alle Uhren)

    func testFaelligkeitOhneRuhezeit() {
        var s = AppSettings()
        s.quietHoursEnabled = false
        let start = Date.now
        let due = LiveActivityManager.quietAdjustedDueDate(start: start, intervalMinutes: 180, settings: s)
        XCTAssertEqual(due.timeIntervalSince(start), 180 * 60, accuracy: 1)
    }

    func testFaelligkeitVerschiebtSichAusDerRuhezeit() {
        var s = AppSettings()
        s.quietHoursEnabled = true; s.quietFrom = 22; s.quietTo = 6
        let start = cal.date(bySettingHour: 21, minute: 0, second: 0, of: .now)!
        let due = LiveActivityManager.quietAdjustedDueDate(start: start, intervalMinutes: 120, settings: s)
        let phys = start.addingTimeInterval(120 * 60)             // 23:00 = Ruhezeit
        XCTAssertGreaterThan(due, phys, "Fälligkeit rückt hinter die Ruhezeit")
        XCTAssertEqual(cal.component(.hour, from: due), 6, "…auf das Ruhezeit-Ende")
    }

    func testWeckerModusNaechsteFesteZeit() {
        let ten = cal.date(bySettingHour: 10, minute: 0, second: 0, of: .now)!
        let times = [9 * 60, 14 * 60]                             // 09:00, 14:00
        let next = AppSettings.nextFixedDue(after: ten, times: times)
        XCTAssertEqual(cal.component(.hour, from: next!), 14)
        let fifteen = cal.date(bySettingHour: 15, minute: 0, second: 0, of: .now)!
        let wrapped = AppSettings.nextFixedDue(after: fifteen, times: times)
        XCTAssertEqual(cal.component(.hour, from: wrapped!), 9, "Nach der letzten Zeit: morgen früh")
        XCTAssertGreaterThan(wrapped!, fifteen)
    }

    // MARK: - 4.11: Kathetersorten

    func testSortenMigrationLiestAltdatenAlsSorteEins() {
        var stock = CatheterStock()
        stock.enabled = true
        stock.stockAtAdjustment = 30
        stock.sizeCharriere = 12
        stock.sorts = nil                                         // Alt-Datenstand
        let sorts = stock.effectiveSorts
        XCTAssertEqual(sorts.count, 1)
        XCTAssertEqual(sorts.first?.name, "Sorte 1")
        XCTAssertEqual(sorts.first?.stockAtAdjustment, 30)
        XCTAssertEqual(sorts.first?.sizeCharriere, 12)
    }

    func testSortenBestandZaehltNurEigeneMiktionen() {
        let past = cal.date(byAdding: .day, value: -2, to: .now)!
        var stock = CatheterStock()
        stock.enabled = true
        stock.sorts = [
            CatheterSort(name: "A", stockAtAdjustment: 20, adjustmentDate: past),
            CatheterSort(name: "B", stockAtAdjustment: 10, adjustmentDate: past),
        ]
        let entries = [
            entry(daysAgo: 0, minute: 0, urine: 100, sort: "A"),
            entry(daysAgo: 0, minute: 30, urine: 100, sort: "A"),
            entry(daysAgo: 0, minute: 60, urine: 100, sort: "B"),
            entry(daysAgo: 0, minute: 90, urine: 100, sort: nil), // ohne Name → erste Sorte
            entry(daysAgo: 0, minute: 120, urine: 100, sort: "C"),// unbekannt → erste Sorte
            entry(daysAgo: 0, minute: 150, drink: 300, sort: "A"),// Trinken zählt NIE
        ]
        let a = stock.effectiveSorts[0], b = stock.effectiveSorts[1]
        XCTAssertEqual(stock.stock(of: a, entries: entries), 20 - 4)
        XCTAssertEqual(stock.stock(of: b, entries: entries), 10 - 1)
    }

    // MARK: - Vorschläge: Deckel und Gänge-Grenzen aus Miktionen

    func testVorschlaegeDeckelnEinzelmengeBei500() {
        var entries: [ToiletEntry] = []
        for i in 1...10 {                                         // 10 Tage à 3 Miktionen 600 ml
            for m in [0, 240, 480] {
                entries.append(entry(daysAgo: i, minute: m, urine: 600))
            }
            entries.append(entry(daysAgo: i, minute: 60, drink: 300))
        }
        let s = SuggestionEngine.compute(entries: entries)
        XCTAssertEqual(s?.singleOverMl, 500, "P95 über 500 wird gedeckelt")
        XCTAssertEqual(s?.singleCapped, true)
        XCTAssertEqual(s?.countOver, 5, "Gänge-Grenzen aus 3 Miktionen/Tag — Kaffees egal")
        XCTAssertEqual(s?.countUnder, 1)
    }

    // MARK: - Urinfarbe "Gelb" (4.11)

    func testUrinfarbeGelbSitztZwischenHellUndDunkel() throws {
        let cases = UrineColor.allCases
        let li = cases.firstIndex(of: .lightYellow)!
        XCTAssertEqual(cases[li + 1], .yellow, "Gelb steht zwischen Hell und Dunkel")
        XCTAssertEqual(cases[li + 2], .darkYellow)
        XCTAssertEqual(UrineColor(rawValue: "Gelb"), .yellow, "CSV-/Speicherwert")
        let entry = ToiletEntry(urineMl: 150, urineColor: .yellow)
        let back = try JSONDecoder().decode(ToiletEntry.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(back.urineColor, .yellow)
    }

    func testSiriKenntJedeUrinfarbe() {
        // Paritäts-Wächter: SiriUrineColor ist ein Spiegel-Enum — jeder neue
        // UrineColor-Fall muss dort nachgezogen werden (Lücke vom 23.08.).
        XCTAssertEqual(SiriUrineColor.allCases.count, UrineColor.allCases.count)
        let reachable = Set(SiriUrineColor.allCases.map(\.toUrineColor))
        XCTAssertEqual(reachable, Set(UrineColor.allCases), "Jede Farbe per Siri erreichbar")
        XCTAssertEqual(SiriUrineColor.yellow.toUrineColor, .yellow)
    }

    // MARK: - 4.12: Medikamente

    func testMedikamentenRoundtripUndAltdaten() throws {
        var s = MedicationSettings()
        s.enabled = true
        s.medications = [Medication(name: "Oxybutynin 5 mg", times: [480, 1200])]
        let back = try JSONDecoder().decode(MedicationSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s, "Einstellungen überleben den Roundtrip")
        let entry = ToiletEntry(urineMl: 100, medications: ["Baclofen"])
        let e2 = try JSONDecoder().decode(ToiletEntry.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(e2.medications, ["Baclofen"])
    }

    // MARK: - Datenmodell: Alt-Einträge decodieren ohne die neuen Felder

    func testAltEintragDecodiertOhneNeueFelder() throws {
        let full = ToiletEntry(urineMl: 150, bowel: false)
        var dict = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(full)) as! [String: Any]
        for key in ["drinkMl", "symptoms", "palpation", "adSigns",
                    "systolicBp", "stoolAmount", "catheterSort", "medications"] {
            dict.removeValue(forKey: key)                          // Stand alter Versionen
        }
        let data = try JSONSerialization.data(withJSONObject: dict)
        let old = try JSONDecoder().decode(ToiletEntry.self, from: data)
        XCTAssertEqual(old.urineMl, 150)
        XCTAssertNil(old.drinkMl)
        XCTAssertNil(old.catheterSort)
    }

    // MARK: - Abstände nach Tageszeit

    /// 10 gleichförmige Tage: 08, 11, 14, 17, 21, 23 Uhr.
    private func planDays(extraDuplicate: Bool = false) -> [ToiletEntry] {
        var e: [ToiletEntry] = []
        for d in 1...10 {
            e += [entry(daysAgo: d, minute: 0, urine: 300),     // 08:00
                  entry(daysAgo: d, minute: 180, urine: 300),   // 11:00  100 ml/h
                  entry(daysAgo: d, minute: 360, urine: 400),   // 14:00  133 ml/h
                  entry(daysAgo: d, minute: 540, urine: 300),   // 17:00  100 ml/h
                  entry(daysAgo: d, minute: 780, urine: 400),   // 21:00  100 ml/h
                  entry(daysAgo: d, minute: 900, urine: 200)]   // 23:00  100 ml/h
        }
        if extraDuplicate { e.append(entry(daysAgo: 3, minute: 184, urine: 50)) }
        return e
    }

    func testIntervalPlanFesteZeitenAusFuellrate() throws {
        let plan = try XCTUnwrap(SuggestionEngine.intervalPlan(entries: planDays(), targetMl: 400))
        XCTAssertEqual(plan.slots.map(\.suggestedMinutes), [240, 180, 240, 240])
        XCTAssertEqual(plan.wakeMinutes, 480)
        XCTAssertEqual(plan.bedMinutes, 1380)
        XCTAssertEqual(plan.times, [480, 720, 900, 1140, 1380])
        XCTAssertEqual(plan.overTarget, 0)
    }

    func testIntervalPlanKleinereZielmengeKuerzereAbstaende() throws {
        let p400 = try XCTUnwrap(SuggestionEngine.intervalPlan(entries: planDays(), targetMl: 400))
        let p250 = try XCTUnwrap(SuggestionEngine.intervalPlan(entries: planDays(), targetMl: 250))
        for (a, b) in zip(p250.slots, p400.slots) {
            XCTAssertLessThanOrEqual(a.suggestedMinutes, b.suggestedMinutes)
        }
        XCTAssertGreaterThan(p250.times.count, p400.times.count)
        XCTAssertTrue(p250.times.allSatisfy { $0 < 1440 })
        XCTAssertEqual(p250.times, p250.times.sorted())
    }

    func testIntervalPlanDoppelteEintraegeZaehlenEinmal() throws {
        let plan = try XCTUnwrap(SuggestionEngine.intervalPlan(entries: planDays(extraDuplicate: true), targetMl: 400))
        XCTAssertEqual(plan.volumes, 60, "Eintrag 4 Minuten nach dem vorigen = dieselbe Entleerung")
    }

    func testIntervalPlanBrauchtSiebenTage() {
        let few = planDays().filter { cal.dateComponents([.day], from: $0.timestamp, to: .now).day! < 5 }
        XCTAssertNil(SuggestionEngine.intervalPlan(entries: few, targetMl: 400))
    }

    // MARK: - Feste Zeiten an erster Morgen-Entleerung ausrichten

    func testShiftedTimesVerschiebtGanzenPlan() {
        let plan = [495, 720, 840, 960]          // 08:15, 12:00, 14:00, 16:00
        XCTAssertEqual(AppSettings.shiftedTimes(plan, firstVoidMinute: 450),
                       [450, 675, 795, 915])     // 07:30 → alles 45 min früher
        XCTAssertEqual(AppSettings.shiftedTimes([480, 1380], firstVoidMinute: 600),
                       [600], "Zeiten nach Mitternacht entfallen")
    }

    /// Eintrag heute um hh:mm (absolut, nicht relativ zu 08:00).
    private func today(_ h: Int, _ m: Int, urine: Int) -> ToiletEntry {
        let ts = cal.date(bySettingHour: h, minute: m, second: 0, of: .now)!
        return ToiletEntry(timestamp: ts, urineMl: urine)
    }

    func testFirstMorningVoidNachNachtpause() throws {
        let now = cal.date(bySettingHour: 10, minute: 0, second: 0, of: .now)!
        let entries = [today(0, 30, urine: 300),   // letzte vor der Nacht (nach Mitternacht)
                       today(7, 40, urine: 400),
                       today(9, 50, urine: 200)]
        let first = try XCTUnwrap(AppSettings.firstMorningVoid(entries: entries, now: now))
        XCTAssertEqual(cal.component(.hour, from: first), 7)
        XCTAssertEqual(cal.component(.minute, from: first), 40)
    }

    func testAlignFixedTimesEinmalProTag() {
        let now = cal.date(bySettingHour: 10, minute: 0, second: 0, of: .now)!
        var s = AppSettings()
        s.useFixedTimes = true
        s.anchorToFirstVoid = true
        s.fixedTimesTemplate = [480, 720, 960]   // 08:00, 12:00, 16:00
        s.fixedTimes = [480, 720, 960]
        let entries = [today(7, 0, urine: 400)]
        XCTAssertTrue(s.alignFixedTimes(entries: entries, now: now))
        XCTAssertEqual(s.fixedTimes, [420, 660, 900])
        XCTAssertEqual(s.fixedTemplate, [480, 720, 960], "Grundplan bleibt unverändert")
        XCTAssertFalse(s.alignFixedTimes(entries: entries, now: now),
                       "Gleiche Entleerung zweimal → nichts mehr verschieben")
        // Früher dran: 10:00 statt 11:00 → nächste 14:00 statt 15:00
        let more = entries + [today(10, 0, urine: 300)]
        XCTAssertTrue(s.alignFixedTimes(entries: more, now: now))
        XCTAssertEqual(s.fixedTimes, [420, 600, 840, 960],
                       "Plan endet 2 Std vor der letzten Grundplanzeit → 16:00 kommt als Tagesende dazu")
        XCTAssertFalse(s.alignFixedTimes(entries: more, now: now), "idempotent")
    }

    func testRechainedTimesFrueherUndSpaeter() {
        let plan = [480, 720, 840, 960]                 // 08:00, 12:00, 14:00, 16:00
        // 11:50 statt 12:00 → ersetzt 12:00, nächste 13:50, dann 15:50
        XCTAssertEqual(AppSettings.rechainedTimes(plan, afterVoidMinute: 710),
                       [480, 710, 830, 950])
        // 13:15 statt 14:00 → ersetzt 14:00, nächste 15:15
        XCTAssertEqual(AppSettings.rechainedTimes(plan, afterVoidMinute: 795),
                       [480, 720, 795, 915])
        // 12:20 statt 12:00 (später) → ersetzt 12:00, alles danach +20 min
        XCTAssertEqual(AppSettings.rechainedTimes(plan, afterVoidMinute: 740),
                       [480, 740, 860, 980])
        // genau zur geplanten Zeit → unverändert
        XCTAssertEqual(AppSettings.rechainedTimes(plan, afterVoidMinute: 720), plan)
        // nach der letzten Zeit → unverändert
        XCTAssertEqual(AppSettings.rechainedTimes(plan, afterVoidMinute: 1000), plan)
        // Zeiten über Mitternacht entfallen
        XCTAssertEqual(AppSettings.rechainedTimes([480, 1200, 1400], afterVoidMinute: 1300),
                       [480, 1300])
    }

    /// Regression 22.10.: Aufstehen 40 min später schob 23:45 auf 00:25 → Zeit
    /// fiel weg, obwohl spätere frühere Entleerungen sie auf 22:17 zurückzogen.
    func testAlignBehaeltZeitDieNurZwischenzeitlichNachMitternachtLag() {
        let now = cal.date(bySettingHour: 20, minute: 30, second: 0, of: .now)!
        var s = AppSettings()
        s.useFixedTimes = true
        s.anchorToFirstVoid = true
        let plan = [495, 720, 840, 960, 1125, 1290, 1425]   // 08:15 … 21:30, 23:45
        s.fixedTimesTemplate = plan
        s.fixedTimes = plan
        let voids = [(8, 55), (12, 23), (14, 19), (15, 25), (17, 56), (20, 2)]
        var entries: [ToiletEntry] = []
        for (h, m) in voids {                              // wie im Alltag: nach jedem Eintrag
            entries.append(today(h, m, urine: 300))
            let t = cal.date(bySettingHour: h, minute: m, second: 30, of: .now)!
            _ = s.alignFixedTimes(entries: entries, now: t)
        }
        _ = s.alignFixedTimes(entries: entries, now: now)
        XCTAssertEqual(s.fixedTimes, [535, 743, 859, 925, 1076, 1202, 1337],
                       "22:17 bleibt als letzte Erinnerung erhalten (23:45 nur 88 Min danach → kein Extra)")
        XCTAssertFalse(s.alignFixedTimes(entries: entries, now: now), "idempotent")
    }

    /// Regression 07.11.26: Nacht-Entleerung 04:31 galt als Aufwachen → ganzer Tag
    /// 3:44 Std vorgezogen, letzte Erinnerung 20:56, danach nichts mehr.
    func testNachtEntleerungIstKeinAufwachen() {
        var s = AppSettings()
        s.useFixedTimes = true
        s.anchorToFirstVoid = true
        let plan = [495, 720, 840, 960, 1125, 1290, 1425]   // 08:15 … 23:45
        s.fixedTimesTemplate = plan
        s.fixedTimes = plan
        let times = [(4, 31), (8, 46), (11, 47), (14, 24), (16, 21), (19, 35), (20, 56)]
        let entries = times.map { today($0.0, $0.1, urine: 250) }
        let now = cal.date(bySettingHour: 21, minute: 0, second: 0, of: .now)!
        let first = AppSettings.firstMorningVoid(entries: entries, now: now, wakeMinute: 495)
        XCTAssertEqual(first.map { cal.component(.hour, from: $0) }, 8, "Aufwachen = 08:46, nicht 04:31")
        _ = s.alignFixedTimes(entries: entries, now: now)
        XCTAssertEqual(s.fixedTimes, [526, 707, 864, 981, 1175, 1256, 1391],
                       "08:46 … 20:56, nächste Erinnerung 23:11")
        XCTAssertTrue(s.alignFixedTimes(entries: entries, now: now) == false, "idempotent")
    }

    /// Ohne Aufwachzeit bleibt das alte Fenster ab 04 Uhr (Abwärtskompatibilität).
    func testFirstMorningVoidOhneAufwachzeit() throws {
        let now = cal.date(bySettingHour: 10, minute: 0, second: 0, of: .now)!
        let entries = [today(4, 31, urine: 300), today(8, 46, urine: 300)]
        let first = try XCTUnwrap(AppSettings.firstMorningVoid(entries: entries, now: now))
        XCTAssertEqual(cal.component(.hour, from: first), 4)
    }

    /// Echte Entleerungen werden beim Neutakten nie ersetzt.
    func testRechainedTimesErsetztKeineEchteEntleerung() {
        // 19:35 war eine Entleerung; 20:56 liegt 81 Min danach und 84 Min vor 22:20
        XCTAssertEqual(AppSettings.rechainedTimes([1175, 1340, 1475], afterVoidMinute: 1256,
                                                  keepPastMidnight: true, protected: [1175]),
                       [1175, 1256, 1391], "20:56 ersetzt 22:20 → nächste 23:11")
    }

    /// Frühe Entleerungen lassen den Plan früh enden → letzte Grundplanzeit kommt dazu.
    func testTagesendeAnkerKommtZurueck() {
        var s = AppSettings()
        s.useFixedTimes = true
        s.anchorToFirstVoid = true
        let plan = [495, 720, 840, 960, 1125, 1290, 1425]
        s.fixedTimesTemplate = plan
        s.fixedTimes = plan
        let times = [(8, 15), (10, 0), (11, 30), (13, 0), (14, 30)]  // immer deutlich früher
        let entries = times.map { today($0.0, $0.1, urine: 250) }
        let now = cal.date(bySettingHour: 15, minute: 0, second: 0, of: .now)!
        _ = s.alignFixedTimes(entries: entries, now: now)
        XCTAssertEqual(s.sortedFixedTimes.last, 1425, "23:45 (vor dem Schlafen) bleibt")
        let fixed = s.sortedFixedTimes
        XCTAssertTrue(zip(fixed, fixed.dropFirst()).allSatisfy { $1 - $0 <= 240 },
                      "keine Lücke über 4 Std bis zum Abend")
    }

    /// Regression 25.10.2026 (Winterzeit, Tag mit 25 h): „Tagesbeginn + Minuten × 60 s“
    /// lag eine Stunde zu früh (12:43 statt 13:43).
    func testFixedDueAmTagDerZeitumstellung() throws {
        let oldTZ = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "Europe/Berlin")!
        defer { NSTimeZone.default = oldTZ }
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        func at(_ h: Int, _ m: Int, day: Int = 25, month: Int = 10) -> Date {
            c.date(from: DateComponents(year: 2026, month: month, day: day, hour: h, minute: m))!
        }
        var s = AppSettings()
        s.useFixedTimes = true
        s.fixedTimes = [541, 703, 823]
        let due = try XCTUnwrap(s.fixedDue(lastVoid: at(11, 43), now: at(11, 46)))
        XCTAssertEqual(due, at(13, 43))
        let dueM = try XCTUnwrap(s.fixedDue(lastVoid: at(11, 43, day: 29, month: 3),
                                            now: at(11, 46, day: 29, month: 3)))
        XCTAssertEqual(dueM, at(13, 43, day: 29, month: 3))
    }

    // MARK: - Lernender Grundplan (Leitplanken)

    /// Kleine Verschiebungen unter 15 Min werden ignoriert — kein tägliches Zittern.
    func testLearnedTemplateIgnoriertKleineVerschiebungen() {
        let cur = [495, 720, 840, 960, 1125, 1290, 1425]
        let prop = [500, 725, 850, 955, 1130, 1285, 1420]
        XCTAssertNil(AppSettings.learnedTemplate(current: cur, proposed: prop))
    }

    /// Nur Zeiten mit ≥ 15 Min Unterschied wandern; der Rest bleibt stehen.
    func testLearnedTemplateUebernimmtNurDeutlicheAenderungen() {
        let cur = [495, 720, 840, 960, 1125, 1290, 1425]
        let prop = [495, 690, 845, 930, 1125, 1290, 1425]   // Mittag −30, Nachmittag −30
        XCTAssertEqual(AppSettings.learnedTemplate(current: cur, proposed: prop),
                       [495, 690, 840, 930, 1125, 1290, 1425])
    }

    /// Andere Anzahl Erinnerungen (kürzere Abstände nötig) → Vorschlag gilt ganz.
    func testLearnedTemplateAndereAnzahlGiltGanz() {
        let cur = [495, 720, 960, 1200, 1425]
        let prop = [495, 660, 825, 990, 1155, 1320, 1425]
        XCTAssertEqual(AppSettings.learnedTemplate(current: cur, proposed: prop), prop)
        XCTAssertNil(AppSettings.learnedTemplate(current: prop, proposed: prop), "identisch → nil")
    }

    /// Lücken über 4 h im Vorschlag werden geschlossen (Lückenfüllung bleibt Pflicht).
    func testLearnedTemplateSchliesstLuecken() throws {
        let out = try XCTUnwrap(AppSettings.learnedTemplate(current: [480, 720, 960, 1200],
                                                            proposed: [480, 780, 1080, 1380]))
        XCTAssertTrue(zip(out, out.dropFirst()).allSatisfy { $1 - $0 <= 240 })
        XCTAssertEqual(out.first, 480); XCTAssertEqual(out.last, 1380)
    }

    /// Lern-Engine mit Zielmenge: hohe Füllrate (Nachmittag) → kürzerer Abstand dort.
    func testIntervalPlan14TageReagiertAufZielmenge() throws {
        var entries: [ToiletEntry] = []
        for d in 1...12 {
            // Tagesmuster: 08:00 300 ml, dann alle 3 h — nachmittags 480 ml (zu viel), sonst 300
            for (h, ml) in [(8, 300), (11, 300), (14, 300), (17, 480), (20, 300), (23, 300)] {
                let t = cal.date(byAdding: .day, value: -d, to: cal.date(bySettingHour: h, minute: 0, second: 0, of: .now)!)!
                entries.append(ToiletEntry(timestamp: t, urineMl: ml))
            }
        }
        let plan = try XCTUnwrap(SuggestionEngine.intervalPlan(entries: entries, targetMl: 400, days: 14))
        XCTAssertLessThan(plan.slots[2].suggestedMinutes, plan.slots[1].suggestedMinutes,
                          "Nachmittag (480 ml je 3 h) braucht kürzeren Abstand als Mittag")
        XCTAssertLessThanOrEqual(plan.slots[2].suggestedMinutes, 150)
        XCTAssertNil(SuggestionEngine.intervalPlan(entries: entries, targetMl: 400, days: 5), "zu wenig Tage → nil")
    }

    // MARK: - Wöchentliches iCloud-Backup

    func testAutoBackupFaelligkeit() {
        let now = Date.now
        let day: TimeInterval = 24 * 3600
        XCTAssertFalse(CloudBackupManager.isAutoBackupDue(enabled: false, last: nil, now: now))
        XCTAssertTrue(CloudBackupManager.isAutoBackupDue(enabled: true, last: nil, now: now))
        XCTAssertFalse(CloudBackupManager.isAutoBackupDue(enabled: true, last: now.addingTimeInterval(-6 * day), now: now))
        XCTAssertTrue(CloudBackupManager.isAutoBackupDue(enabled: true, last: now.addingTimeInterval(-7 * day), now: now))
    }

    // MARK: - Wecker-Modus: keine Ruhezeit-Anzeige in der Live Activity

    func testDueStateWeckerModusOhneRuhezeit() {
        var s = AppSettings()
        s.useFixedTimes = true
        s.quietHoursEnabled = true
        let start = Date.now.addingTimeInterval(-4 * 3600)   // rohe Fälligkeit längst vorbei
        let nowMin = cal.component(.hour, from: .now) * 60 + cal.component(.minute, from: .now)
        s.fixedTimes = [(nowMin + 40) % 1440]                 // nächste feste Zeit in 40 min
        let st = LiveActivityManager.dueState(start: start, intervalMinutes: 60, settings: s)
        XCTAssertNil(st.quietEnd, "Wecker-Modus darf nie Ruhezeit/Mond zeigen")
        XCTAssertEqual(st.physDue, st.shifted)
        XCTAssertGreaterThan(st.shifted, .now)
    }

    // MARK: - Morgen: Plan von gestern gilt nicht, verpasste Zeit ist überfällig

    func testEffectiveFixedTimesNeuerTagGrundplan() {
        var s = AppSettings()
        s.useFixedTimes = true
        s.anchorToFirstVoid = true
        s.fixedTimesTemplate = [495, 720, 840]          // Grundplan 08:15, 12:00, 14:00
        s.fixedTimes = [458, 698, 818]                  // gestern neu getaktet
        s.anchorDayKey = "2000-01-01"                   // nicht heute
        XCTAssertEqual(s.effectiveFixedTimes(), [495, 720, 840])
        s.anchorDayKey = Date.now.formatted(.iso8601.year().month().day())
        XCTAssertEqual(s.effectiveFixedTimes(), [458, 698, 818])
    }

    func testFixedDueMorgensUeberfaellig() throws {
        var s = AppSettings()
        s.useFixedTimes = true
        s.anchorToFirstVoid = true
        s.fixedTimesTemplate = [495, 720, 840]
        s.fixedTimes = [458, 698, 818]
        s.anchorDayKey = "2000-01-01"
        let now = cal.date(bySettingHour: 8, minute: 58, second: 0, of: .now)!
        let yesterdayLate = cal.date(byAdding: .hour, value: -10, to: now)!   // 22:58 gestern
        let due = try XCTUnwrap(s.fixedDue(lastVoid: yesterdayLate, now: now))
        XCTAssertEqual(cal.component(.hour, from: due), 8)
        XCTAssertEqual(cal.component(.minute, from: due), 15)
        XCTAssertLessThan(due, now, "08:15 verpasst → überfällig, nicht still auf 12:00 springen")
    }

    func testFixedDueNachEntleerungNaechsteZeit() throws {
        var s = AppSettings()
        s.useFixedTimes = true
        s.fixedTimes = [495, 720, 840]
        let now = cal.date(bySettingHour: 9, minute: 30, second: 0, of: .now)!
        let void = cal.date(bySettingHour: 8, minute: 20, second: 0, of: .now)!
        let due = try XCTUnwrap(s.fixedDue(lastVoid: void, now: now))
        XCTAssertEqual(cal.component(.hour, from: due), 12)
        let late = cal.date(bySettingHour: 14, minute: 30, second: 0, of: .now)!
        let tomorrow = try XCTUnwrap(s.fixedDue(lastVoid: late, now: late))
        XCTAssertFalse(cal.isDate(tomorrow, inSameDayAs: late), "nach der letzten Zeit → morgen")
    }

    func testFixedTemplateGapFindetVormittagsluecke() throws {
        // 08:15 14:00 16:00 18:45 21:30 23:45 → Lücke 08:15–14:00, Vorschlag 11:00
        let gap = try XCTUnwrap(AppSettings.fixedTemplateGap(in: [495, 840, 960, 1125, 1290, 1425]))
        XCTAssertEqual(gap.from, 495)
        XCTAssertEqual(gap.to, 840)
        XCTAssertEqual(gap.suggestion, 660)
    }

    func testFixedTemplateGapKeineBeiVierStunden() {
        XCTAssertNil(AppSettings.fixedTemplateGap(in: [480, 720, 960, 1200]), "genau 4 h ist noch ok")
        XCTAssertNil(AppSettings.fixedTemplateGap(in: []))
    }

    func testFilledFixedTimesSchliesstVormittagsluecke() {
        // Andrés Plan 06.11.: 08:15 14:00 16:00 18:45 21:30 23:45 → 11:00 kommt dazu, sonst nichts
        let filled = AppSettings.filledFixedTimes([495, 840, 960, 1125, 1290, 1425])
        XCTAssertEqual(filled, [495, 660, 840, 960, 1125, 1290, 1425])
        XCTAssertEqual(AppSettings.filledFixedTimes(filled), filled, "idempotent")
    }

    func testFilledFixedTimesTeiltGrosseLueckenMehrfach() {
        let filled = AppSettings.filledFixedTimes([480, 1425])
        for (a, b) in zip(filled, filled.dropFirst()) {
            XCTAssertLessThanOrEqual(b - a, AppSettings.maxFixedGap)
        }
        XCTAssertEqual(filled.first, 480)
        XCTAssertEqual(filled.last, 1425)
    }

    // MARK: - 4.21: Kompressen + Nachbestellung

    /// 10 Tage mit je 3× Sorte A und 1× Sorte B.
    private func mixEntries() -> [ToiletEntry] {
        var list: [ToiletEntry] = []
        for d in 1...10 {
            list.append(entry(daysAgo: d, minute: 0, urine: 300, sort: "A"))
            list.append(entry(daysAgo: d, minute: 180, urine: 300, sort: "A"))
            list.append(entry(daysAgo: d, minute: 360, urine: 300, sort: "A"))
            list.append(entry(daysAgo: d, minute: 540, urine: 300, sort: "B"))
            list.append(entry(daysAgo: d, minute: 600, drink: 250))          // zählt nie
        }
        return list
    }

    private func mixStock() -> CatheterStock {
        let past = cal.date(byAdding: .day, value: -40, to: .now)!
        var stock = CatheterStock()
        stock.enabled = true
        stock.packSize = 30
        stock.sorts = [
            CatheterSort(name: "A", stockAtAdjustment: 200, adjustmentDate: past),
            CatheterSort(name: "B", stockAtAdjustment: 100, adjustmentDate: past),
        ]
        return stock
    }

    func testBestellungFolgtSortenmixUndRundetAufPackungen() {
        var compress = CompressStock()
        compress.enabled = true
        compress.packSize = 50
        let lines = OrderPlan.lines(catheter: mixStock(), compress: compress,
                                    orderDays: 30, entries: mixEntries())
        // Ø 4 pro Tag × 30 Tage = 120 Stück, Mix 3:1 → 90 A + 30 B
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].name, "A")
        XCTAssertEqual(lines[0].packs, 3, "90 Stück = 3 Packungen à 30")
        XCTAssertEqual(lines[1].name, "B")
        XCTAssertEqual(lines[1].packs, 1, "30 Stück = 1 Packung")
        XCTAssertEqual(lines[2].kind, .compress)
        XCTAssertEqual(lines[2].packs, 3, "120 2er-Packs → 3 Packungen à 50 (aufgerundet)")
    }

    func testBestellungOhneKompressenWennAus() {
        let lines = OrderPlan.lines(catheter: mixStock(), compress: CompressStock(),
                                    orderDays: 30, entries: mixEntries())
        XCTAssertEqual(lines.map(\.kind), [.catheter, .catheter])
    }

    func testVerteilungErgibtExaktDieSumme() {
        XCTAssertEqual(OrderPlan.distribute(100, weights: [1, 1, 1]).reduce(0, +), 100)
        XCTAssertEqual(OrderPlan.distribute(120, weights: [30, 10]), [90, 30])
        XCTAssertEqual(OrderPlan.distribute(50, weights: [0, 7]), [0, 50])
        XCTAssertEqual(OrderPlan.distribute(50, weights: [0, 0]), [0, 0])
    }

    func testKompressenBestandZaehltJeEntleerungEinPack() {
        var compress = CompressStock()
        compress.enabled = true
        compress.stockAtAdjustment = 60
        compress.adjustmentDate = cal.date(byAdding: .day, value: -40, to: .now)!
        let entries = mixEntries()                                 // 40 Entleerungen
        XCTAssertEqual(compress.currentStock(entries: entries), 20)
        XCTAssertEqual(compress.daysRemaining(entries: entries), 5, "20 Packs bei Ø 4 pro Tag")
        let status = OrderPlan.status(catheter: mixStock(), compress: compress, entries: entries)
        XCTAssertTrue(status.compressLow, "5 Tage liegt unter der 10-Tage-Schwelle")
        XCTAssertFalse(status.catheterLow, "260 Katheter reichen 65 Tage")
        XCTAssertTrue(status.isDue)
    }

    func testBestellMerkerLaeuftNach21TagenAb() {
        let ordered = cal.date(byAdding: .day, value: -5, to: .now)!
        XCTAssertTrue(OrderState.isPending(orderedOn: ordered, now: .now))
        let old = cal.date(byAdding: .day, value: -22, to: .now)!
        XCTAssertFalse(OrderState.isPending(orderedOn: old, now: .now))
        XCTAssertFalse(OrderState.isPending(orderedOn: nil, now: .now))
    }

    func testBestellMailNenntMengenUndKundennummerNurBeimVersorger() {
        var settings = OrderSettings()
        settings.patientName = "Max Muster"
        settings.customerNumber = "4711"
        settings.supplierEmail = "a@example.org"
        settings.practiceEmail = "b@example.org"
        let line = OrderLine(id: "x", kind: .catheter, name: "A, Ch 12", packSize: 30, packs: 3)
        let supplier = OrderMail.body(lines: [line], recipient: .supplier, settings: settings)
        XCTAssertTrue(supplier.contains("A, Ch 12"))
        XCTAssertTrue(supplier.contains("90"))
        XCTAssertTrue(supplier.contains("4711"))
        let practice = OrderMail.body(lines: [line], recipient: .practice, settings: settings)
        XCTAssertFalse(practice.contains("4711"))
        XCTAssertEqual(OrderMail.recipients(.both, settings: settings), ["a@example.org", "b@example.org"])
    }

    // MARK: - Ø Menge je Kathetersorte (4.22)

    func testDurchschnittsmengeJeKathetersorte() {
        var stock = CatheterStock()
        stock.enabled = true
        stock.sorts = [CatheterSort(name: "Tag"), CatheterSort(name: "Nacht"), CatheterSort(name: "Reise")]
        let now = Date.now
        func e(_ ml: Int, _ sort: String?, daysAgo: Double = 1) -> ToiletEntry {
            ToiletEntry(timestamp: now.addingTimeInterval(-daysAgo * 86_400), urineMl: ml, catheterSort: sort)
        }
        let entries = [
            e(300, "Tag"), e(400, "Tag"), e(350, "Tag"),
            e(500, "Nacht"), e(600, "Nacht"), e(550, "Nacht"), e(551, "Nacht"),
            e(200, "Reise"), e(250, "Reise"),          // nur 2 → keine Zeile
            e(900, nil),                                 // ohne Sorte → zählt nirgends
            e(0, "Tag"),                                 // kein Urin → zählt nicht
            e(100, "Tag", daysAgo: 40)                   // außerhalb des Zeitraums
        ]
        let since = now.addingTimeInterval(-7 * 86_400)
        let rows = stock.averageMlPerSort(entries: entries, since: since)
        XCTAssertEqual(rows.map(\.sort.name), ["Tag", "Nacht"])
        XCTAssertEqual(rows[0].avgMl, 350)
        XCTAssertEqual(rows[0].count, 3)
        XCTAssertEqual(rows[1].avgMl, 550)             // 2201 / 4 = 550,25
        XCTAssertEqual(rows[1].count, 4)
        // Ohne Zeitgrenze zählt der alte Eintrag mit: (300+400+350+100)/4 = 287,5 → 288
        XCTAssertEqual(stock.averageMlPerSort(entries: entries).first?.avgMl, 288)
    }
}
