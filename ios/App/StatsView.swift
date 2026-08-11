import SwiftUI
import Charts
import UIKit

enum TimeRange: String, CaseIterable, Identifiable {
    case week = "7 Tage"
    case month = "30 Tage"
    case quarter = "3 Monate"
    case year = "1 Jahr"
    case all = "Alle"
    var id: String { rawValue }
    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .year: 365
        case .all: 9999
        }
    }
}

struct StatsView: View {
    @Environment(DataStore.self) private var store
    @State private var range: TimeRange = .week

    private var summaries: [DaySummary] { store.entries.summariesForRange(days: range.days) }
    private var activeDays: [DaySummary] { summaries.filter { $0.count > 0 } }
    private var avgMl: Int { guard !activeDays.isEmpty else { return 0 }; return activeDays.reduce(0) { $0 + $1.totalMl } / activeDays.count }
    private var avgCount: Double { guard !activeDays.isEmpty else { return 0 }; return Double(activeDays.reduce(0) { $0 + $1.count }) / Double(activeDays.count) }
    private var avgBowel: Double { let w = activeDays.filter { $0.bowelCount > 0 }; guard !w.isEmpty else { return 0 }; return Double(w.reduce(0) { $0 + $1.bowelCount }) / Double(w.count) }

    private var xAxisStride: Calendar.Component {
        switch range {
        case .week: .day
        case .month: .weekOfYear
        case .quarter: .weekOfYear
        case .year: .month
        case .all: .month
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch range {
        case .week: .dateTime.weekday(.abbreviated)
        default: .dateTime.day().month(.twoDigits)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill").font(.system(size: 40)).foregroundStyle(.quaternary)
                        Text(String(localized: "no_data")).font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            rangePicker
                            averageCards
                            catheterCard
                            urineChart
                            toiletCountChart
                            dailyTable
                            exportButton
                        }
                        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 40)
                    }
                }
            }
            .background(Color.pageBg)
            .navigationTitle(String(localized: "tab_stats"))
        }
    }

    private var rangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TimeRange.allCases) { r in
                    Button(r.rawValue) { range = r }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(range == r ? Color.pillActiveBg : Color.clear, in: .capsule)
                        .foregroundStyle(range == r ? Color.pillActiveText : .primary)
                        .overlay(Capsule().stroke(range == r ? Color.clear : Color.pillBorder, lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private var catheterCard: some View {
        let stock = CatheterStock.load()
        if stock.enabled {
            let count = stock.currentStock(entries: store.entries)
            HStack(spacing: 12) {
                Image(systemName: "cross.vial.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) Katheter im Bestand")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    if let days = stock.daysRemaining(entries: store.entries),
                       let empty = stock.estimatedEmptyDate(entries: store.entries) {
                        Text("Reicht etwa \(days) Tage — bis ca. \(empty.formatted(.dateTime.day().month()))")
                            .font(.caption)
                            .foregroundStyle(days <= stock.warnDays ? Color.red : Color.secondary)
                    } else {
                        Text("Reichweite folgt nach ein paar Tagen mit Einträgen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(Color.cardBg, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
        }
    }

    private var averageCards: some View {
        HStack(spacing: 0) {
            avgItem("⌀ Urin", "\(avgMl)", "ml", Color.accent)
            Rectangle().fill(Color.pillBorder).frame(width: 0.5, height: 30)
            avgItem("⌀ Gänge", String(format: "%.1f", avgCount), nil, Color.subtleText)
            Rectangle().fill(Color.pillBorder).frame(width: 0.5, height: 30)
            avgItem("⌀ Stuhl", String(format: "%.1f", avgBowel), nil, Color.bowel)
        }
        .padding(.vertical, 14)
        .background(Color.cardBg, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
    }

    private func avgItem(_ title: String, _ value: String, _ unit: String?, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundStyle(Color.subtleText)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value).font(.title3.weight(.bold)).foregroundStyle(color)
                if let unit { Text(unit).font(.caption2).foregroundStyle(color.opacity(0.7)) }
            }
        }.frame(maxWidth: .infinity)
    }

    private var urineChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "urine_per_day")).font(.caption.weight(.bold)).foregroundStyle(Color.subtleText)
            Chart(summaries) { day in
                BarMark(x: .value("Tag", day.date, unit: .day), y: .value("ml", day.totalMl))
                    .foregroundStyle(Color.accent.gradient).cornerRadius(2)
            }
            .chartXAxis { AxisMarks(values: .stride(by: xAxisStride)) { _ in AxisValueLabel(format: xAxisFormat); AxisGridLine(stroke: StrokeStyle(lineWidth: 0.2)) } }
            .chartYAxis { AxisMarks { _ in AxisValueLabel(); AxisGridLine(stroke: StrokeStyle(lineWidth: 0.2, dash: [4])) } }
            .frame(height: 150)
        }
        .padding(16).background(Color.cardBg, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
    }

    private var toiletCountChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "visits_per_day")).font(.caption.weight(.bold)).foregroundStyle(Color.subtleText)
            Chart(summaries) { day in
                BarMark(x: .value("Tag", day.date, unit: .day), y: .value("Urin", day.count - day.bowelCount))
                    .foregroundStyle(Color.accent.gradient).cornerRadius(2)
                if day.bowelCount > 0 {
                    BarMark(x: .value("Tag", day.date, unit: .day), y: .value("Stuhl", day.bowelCount))
                        .foregroundStyle(Color.bowel.gradient).cornerRadius(2)
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: xAxisStride)) { _ in AxisValueLabel(format: xAxisFormat); AxisGridLine(stroke: StrokeStyle(lineWidth: 0.2)) } }
            .chartYAxis { AxisMarks { _ in AxisValueLabel(); AxisGridLine(stroke: StrokeStyle(lineWidth: 0.2, dash: [4])) } }
            .frame(height: 150)
            HStack(spacing: 14) {
                HStack(spacing: 4) { Circle().fill(Color.accent).frame(width: 6, height: 6); Text(String(localized: "urine")).font(.caption2).foregroundStyle(Color.subtleText) }
                HStack(spacing: 4) { Circle().fill(Color.bowel).frame(width: 6, height: 6); Text(String(localized: "stool")).font(.caption2).foregroundStyle(Color.subtleText) }
            }.frame(maxWidth: .infinity)
        }
        .padding(16).background(Color.cardBg, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
    }

    private var dailyTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "daily_overview")).font(.caption.weight(.bold)).foregroundStyle(Color.subtleText)
            VStack(spacing: 0) {
                HStack {
                    Text("Tag").frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(localized: "urine")).frame(width: 60, alignment: .trailing)
                    Text("Gänge").frame(width: 42, alignment: .trailing)
                    Text(String(localized: "stool")).frame(width: 42, alignment: .trailing)
                }.font(.caption2.weight(.bold)).foregroundStyle(Color.subtleText).padding(.bottom, 6)
                Divider()
                ForEach(activeDays) { day in
                    HStack {
                        Text(day.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits))).frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(day.totalMl) ml").foregroundStyle(Color.accent).fontWeight(.semibold).frame(width: 60, alignment: .trailing)
                        Text("\(day.count)").fontWeight(.semibold).frame(width: 42, alignment: .trailing)
                        Text("\(day.bowelCount)").foregroundStyle(Color.bowel).fontWeight(.semibold).frame(width: 42, alignment: .trailing)
                    }.font(.caption).monospacedDigit().padding(.vertical, 5)
                    Divider()
                }
            }
        }
        .padding(16).background(Color.cardBg, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
    }

    private var exportButton: some View {
        HStack(spacing: 10) {
            Button(action: exportStats) {
                HStack {
                    Image(systemName: "tablecells")
                    Text("CSV")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accent, in: .rect(cornerRadius: 8))
                .foregroundStyle(Color.pillActiveText)
            }
            Button(action: exportPDF) {
                HStack {
                    Image(systemName: "doc.richtext")
                    Text("PDF")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accent, in: .rect(cornerRadius: 8))
                .foregroundStyle(Color.pillActiveText)
            }
        }
    }

    private func exportPDF() {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        let tf = DateFormatter()
        tf.dateFormat = "dd.MM.yyyy HH:mm"

        let pw: CGFloat = 595  // A4 width
        let ph: CGFloat = 842  // A4 height
        let m: CGFloat = 40    // margin
        let cw = pw - 2 * m    // content width
        let orange = UIColor(red: 0.91, green: 0.57, blue: 0.23, alpha: 1)
        let purple = UIColor(red: 0.61, green: 0.49, blue: 0.78, alpha: 1)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pw, height: ph))

        let data = renderer.pdfData { ctx in
            func newPage() -> CGFloat { ctx.beginPage(); drawFooter(); return m }

            func drawFooter() {
                let f: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.gray]
                "Blase & Darm Manager — blaseunddarm.de — Erstellt am \(df.string(from: .now))".draw(at: CGPoint(x: m, y: ph - 30), withAttributes: f)
            }

            func drawLine(at y: CGFloat, color: UIColor = .separator) {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: m, y: y))
                p.addLine(to: CGPoint(x: pw - m, y: y))
                color.setStroke()
                p.lineWidth = 0.5
                p.stroke()
            }

            func drawRect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: UIColor) {
                let r = UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: 4)
                color.setFill()
                r.fill()
            }

            // Page 1
            var y = newPage()

            // Header bar
            drawRect(x: 0, y: 0, w: pw, h: 80, color: orange)
            let logoAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.white]
            "Blase & Darm Manager".draw(at: CGPoint(x: m, y: 28), withAttributes: logoAttrs)
            let headerSub: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.white.withAlphaComponent(0.8)]
            "Toiletten-Protokoll — Statistik-Report".draw(at: CGPoint(x: m, y: 55), withAttributes: headerSub)
            y = 100

            // Report info
            let infoAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.darkGray]
            let boldInfoAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 11), .foregroundColor: UIColor.darkGray]
            "Zeitraum:".draw(at: CGPoint(x: m, y: y), withAttributes: boldInfoAttrs)
            range.rawValue.draw(at: CGPoint(x: m + 70, y: y), withAttributes: infoAttrs)
            "Tage mit Daten:".draw(at: CGPoint(x: 300, y: y), withAttributes: boldInfoAttrs)
            "\(activeDays.count)".draw(at: CGPoint(x: 410, y: y), withAttributes: infoAttrs)
            y += 18
            "Erstellt:".draw(at: CGPoint(x: m, y: y), withAttributes: boldInfoAttrs)
            df.string(from: .now).draw(at: CGPoint(x: m + 70, y: y), withAttributes: infoAttrs)
            "Einträge gesamt:".draw(at: CGPoint(x: 300, y: y), withAttributes: boldInfoAttrs)
            "\(summaries.reduce(0) { $0 + $1.count })".draw(at: CGPoint(x: 410, y: y), withAttributes: infoAttrs)
            y += 30

            drawLine(at: y)
            y += 15

            // Averages boxes
            let boxW = (cw - 20) / 3
            let boxH: CGFloat = 55

            // Urin box
            drawRect(x: m, y: y, w: boxW, h: boxH, color: orange.withAlphaComponent(0.1))
            let boxLabel: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.gray]
            let boxValue: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: orange]
            "⌀ Urin / Tag".draw(at: CGPoint(x: m + 10, y: y + 8), withAttributes: boxLabel)
            "\(avgMl) ml".draw(at: CGPoint(x: m + 10, y: y + 25), withAttributes: boxValue)

            // Gänge box
            let bx2 = m + boxW + 10
            drawRect(x: bx2, y: y, w: boxW, h: boxH, color: UIColor.systemGray6)
            let boxValue2: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: UIColor.label]
            "⌀ Gänge / Tag".draw(at: CGPoint(x: bx2 + 10, y: y + 8), withAttributes: boxLabel)
            String(format: "%.1f", avgCount).draw(at: CGPoint(x: bx2 + 10, y: y + 25), withAttributes: boxValue2)

            // Stuhl box
            let bx3 = m + 2 * (boxW + 10)
            drawRect(x: bx3, y: y, w: boxW, h: boxH, color: purple.withAlphaComponent(0.1))
            let boxValue3: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: purple]
            "⌀ Stuhl / Tag".draw(at: CGPoint(x: bx3 + 10, y: y + 8), withAttributes: boxLabel)
            String(format: "%.1f", avgBowel).draw(at: CGPoint(x: bx3 + 10, y: y + 25), withAttributes: boxValue3)

            y += boxH + 25

            // Section: Daily overview
            let sectionAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: orange]
            "Tagesübersicht".draw(at: CGPoint(x: m, y: y), withAttributes: sectionAttrs)
            y += 25

            // Table header
            let thAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.white]
            drawRect(x: m, y: y, w: cw, h: 22, color: UIColor.darkGray)
            "Datum".draw(at: CGPoint(x: m + 8, y: y + 5), withAttributes: thAttrs)
            "Urin (ml)".draw(at: CGPoint(x: 180, y: y + 5), withAttributes: thAttrs)
            "Gänge".draw(at: CGPoint(x: 280, y: y + 5), withAttributes: thAttrs)
            "Stuhl".draw(at: CGPoint(x: 360, y: y + 5), withAttributes: thAttrs)
            "Urinfarben".draw(at: CGPoint(x: 430, y: y + 5), withAttributes: thAttrs)
            y += 24

            // Table rows
            let tdAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular), .foregroundColor: UIColor.label]
            let tdBold: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold), .foregroundColor: orange]
            let tdPurple: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold), .foregroundColor: purple]
            let tdSmall: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.gray]

            for (i, day) in activeDays.enumerated() {
                if y > ph - 60 { y = newPage() }

                // Alternating row background
                if i % 2 == 0 {
                    drawRect(x: m, y: y - 2, w: cw, h: 18, color: UIColor.systemGray6.withAlphaComponent(0.5))
                }

                df.string(from: day.date).draw(at: CGPoint(x: m + 8, y: y), withAttributes: tdAttrs)
                "\(day.totalMl)".draw(at: CGPoint(x: 180, y: y), withAttributes: tdBold)
                "\(day.count)".draw(at: CGPoint(x: 280, y: y), withAttributes: tdAttrs)
                "\(day.bowelCount)".draw(at: CGPoint(x: 360, y: y), withAttributes: tdPurple)

                // Color summary
                let dayEntries = summaries.first { $0.date == day.date }?.entries ?? []
                let colors = dayEntries.compactMap { $0.urineColor != .none ? $0.urineColor.localizedName : nil }
                if !colors.isEmpty {
                    let colorStr = Array(Set(colors)).joined(separator: ", ")
                    colorStr.draw(at: CGPoint(x: 430, y: y), withAttributes: tdSmall)
                }

                y += 18
            }

            y += 20
            if y > ph - 150 { y = newPage() }

            // Section: Detailed entries
            drawLine(at: y)
            y += 15
            "Einzeleinträge".draw(at: CGPoint(x: m, y: y), withAttributes: sectionAttrs)
            y += 25

            // Detail table header
            drawRect(x: m, y: y, w: cw, h: 22, color: UIColor.darkGray)
            "Datum & Uhrzeit".draw(at: CGPoint(x: m + 8, y: y + 5), withAttributes: thAttrs)
            "ml".draw(at: CGPoint(x: 200, y: y + 5), withAttributes: thAttrs)
            "Farbe".draw(at: CGPoint(x: 260, y: y + 5), withAttributes: thAttrs)
            "Stuhl".draw(at: CGPoint(x: 340, y: y + 5), withAttributes: thAttrs)
            "Bristol".draw(at: CGPoint(x: 400, y: y + 5), withAttributes: thAttrs)
            "Notiz".draw(at: CGPoint(x: 460, y: y + 5), withAttributes: thAttrs)
            y += 24

            let allEntries = summaries.flatMap(\.entries).sorted { $0.timestamp > $1.timestamp }
            for (i, entry) in allEntries.enumerated() {
                if y > ph - 60 { y = newPage() }

                if i % 2 == 0 {
                    drawRect(x: m, y: y - 2, w: cw, h: 16, color: UIColor.systemGray6.withAlphaComponent(0.5))
                }

                tf.string(from: entry.timestamp).draw(at: CGPoint(x: m + 8, y: y), withAttributes: tdAttrs)
                if entry.urineMl > 0 {
                    "\(entry.urineMl)".draw(at: CGPoint(x: 200, y: y), withAttributes: tdBold)
                }
                if entry.urineColor != .none {
                    entry.urineColor.localizedName.draw(at: CGPoint(x: 260, y: y), withAttributes: tdSmall)
                }
                if entry.bowel {
                    "Ja".draw(at: CGPoint(x: 340, y: y), withAttributes: tdPurple)
                }
                if entry.bristolType != .none {
                    entry.bristolType.label.draw(at: CGPoint(x: 400, y: y), withAttributes: tdSmall)
                }
                if !entry.note.isEmpty {
                    let note = String(entry.note.prefix(15))
                    note.draw(at: CGPoint(x: 460, y: y), withAttributes: tdSmall)
                }
                y += 16
            }

            // Disclaimer
            y += 20
            if y > ph - 60 { y = newPage() }
            drawLine(at: y)
            y += 10
            let disclaimerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.italicSystemFont(ofSize: 8), .foregroundColor: UIColor.gray]
            "Diese Daten dienen der Selbstbeobachtung und ersetzen keine ärztliche Beratung.".draw(at: CGPoint(x: m, y: y), withAttributes: disclaimerAttrs)
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Blase_Darm_Statistik_\(df.string(from: .now)).pdf")
        try? data.write(to: url)
        shareFile(url)
    }

    private func exportStats() {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        let tf = DateFormatter()
        tf.dateFormat = "dd.MM.yyyy;HH:mm"

        var csv = "Datum;Uhrzeit;Urin_ml;Urinfarbe;Stuhlgang;Bristol;Notiz\n"

        // Individual entries (not just daily summaries)
        let allEntries = summaries.flatMap(\.entries).sorted { $0.timestamp > $1.timestamp }
        for entry in allEntries {
            let dateTime = tf.string(from: entry.timestamp)
            let color = entry.urineColor != .none ? entry.urineColor.localizedName : ""
            let bowelStr = entry.bowel ? "Ja" : "Nein"
            let bristol = entry.bristolType != .none ? entry.bristolType.label : ""
            let note = entry.note.replacingOccurrences(of: ";", with: ",")
            csv += "\(dateTime);\(entry.urineMl);\(color);\(bowelStr);\(bristol);\(note)\n"
        }

        // Add summary section
        csv += "\n\nZusammenfassung;\(range.rawValue)\n"
        csv += "Tage mit Daten;\(activeDays.count)\n"
        csv += "Durchschnitt Urin/Tag;\(avgMl) ml\n"
        csv += "Durchschnitt Gänge/Tag;\(String(format: "%.1f", avgCount))\n"
        csv += "Durchschnitt Stuhl/Tag;\(String(format: "%.1f", avgBowel))\n"
        csv += "\nTagesübersicht\n"
        csv += "Datum;Urin_ml;Gänge;Stuhlgang\n"
        for day in activeDays {
            csv += "\(df.string(from: day.date));\(day.totalMl);\(day.count);\(day.bowelCount)\n"
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Blase_Darm_Export_\(df.string(from: .now)).csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        shareFile(url)
    }

    private func shareFile(_ url: URL) {
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            if let popover = av.popoverPresentationController {
                popover.sourceView = root.view
                popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            }
            root.present(av, animated: true)
        }
    }
}

#Preview { StatsView().environment(DataStore()) }
