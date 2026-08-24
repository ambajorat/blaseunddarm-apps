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

    // MARK: - Datenmodell: Alt-Einträge decodieren ohne die neuen Felder

    func testAltEintragDecodiertOhneNeueFelder() throws {
        let full = ToiletEntry(urineMl: 150, bowel: false)
        var dict = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(full)) as! [String: Any]
        for key in ["drinkMl", "symptoms", "palpation", "adSigns",
                    "systolicBp", "stoolAmount", "catheterSort"] {
            dict.removeValue(forKey: key)                          // Stand alter Versionen
        }
        let data = try JSONSerialization.data(withJSONObject: dict)
        let old = try JSONDecoder().decode(ToiletEntry.self, from: data)
        XCTAssertEqual(old.urineMl, 150)
        XCTAssertNil(old.drinkMl)
        XCTAssertNil(old.catheterSort)
    }
}
