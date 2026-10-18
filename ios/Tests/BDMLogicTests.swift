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
        XCTAssertEqual(s.fixedTimes, [420, 600, 840])
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
}
