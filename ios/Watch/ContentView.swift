//
//  ContentView.swift
//  Blase & Darm — Watch
//
//  Schnellerfassung am Handgelenk:
//    Tageszeile oben (vom iPhone gespiegelt)
//    Blase -> Menge per Digital Crown (+ Presets) -> voller Eintrag ans iPhone
//    Darm  -> Bristol-Typ aus Liste -> voller Eintrag ans iPhone
//

import SwiftUI
import WatchKit

private enum Farbe {
    static let blase = Color(red: 0xE8/255, green: 0x92/255, blue: 0x3A/255)
    static let darm  = Color(red: 0x9B/255, green: 0x7E/255, blue: 0xC8/255)
}

struct ContentView: View {
    @EnvironmentObject private var session: WatchSessionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    todayCard
                    timerCard

                    NavigationLink {
                        BladderEntryView()
                    } label: {
                        actionLabel(title: "Blase", icon: "drop.fill", color: Farbe.blase)
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        BowelEntryView()
                    } label: {
                        actionLabel(title: "Darm", icon: "circle.hexagongrid.fill", color: Farbe.darm)
                    }
                    .buttonStyle(.plain)

                    statusLine
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Blase & Darm")
        }
    }

    // MARK: - Bausteine

    private var todayCard: some View {
        VStack(spacing: 2) {
            Text("Heute")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(session.todayMl) ml")
                .font(.title3).bold()
            Text("\(session.todayCount)× Blase · \(session.todayBowel)× Darm")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    /// Countdown zur nächsten Erinnerung — gleiche Logik wie iPhone-Header
    /// und Live Activity: orange bis zur körperlichen Fälligkeit, Mond in der
    /// Ruhezeit, rot ab Ruhezeitende. TimelineView sorgt für den Zustandswechsel.
    @ViewBuilder
    private var timerCard: some View {
        if let info = session.currentDue() {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let now = context.date
                let inQuietWindow = info.due <= now && (info.quietEnd.map { now < $0 } ?? false)
                let overdue = info.due <= now && !inQuietWindow
                let overdueAnchor = info.quietEnd ?? info.due

                VStack(spacing: 2) {
                    if inQuietWindow, let quietEnd = info.quietEnd {
                        Label("Ruhezeit", systemImage: "moon.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(quietEnd, style: .timer)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } else if overdue {
                        Text(overdueAnchor, style: .timer)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.red)
                        Text("überfällig")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    } else {
                        Text(info.due, style: .timer)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Farbe.blase)
                        Text("nächste Erinnerung")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
    }

    private func actionLabel(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.headline)
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).opacity(0.5)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color, lineWidth: 1.5))
        .foregroundStyle(color)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch session.lastSendState {
        case .idle:
            EmptyView()
        case .sent(let label, let date):
            Label("\(label) erfasst, \(date.formatted(date: .omitted, time: .shortened))",
                  systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .queued(let label):
            Label("\(label) gespeichert — wird gesendet, sobald das iPhone erreichbar ist",
                  systemImage: "clock.arrow.circlepath")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Blase: Menge per Digital Crown

struct BladderEntryView: View {
    @EnvironmentObject private var session: WatchSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var ml: Double = 200
    @State private var color: UrineColor = .none
    @FocusState private var crownFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text("\(Int(ml)) ml")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Farbe.blase)
                .focusable()
                .focused($crownFocused)
                .digitalCrownRotation($ml, from: 0, through: 1000, by: 5,
                                      sensitivity: .medium, isContinuous: false)

            if !session.quickValues.isEmpty {
                HStack(spacing: 6) {
                    ForEach(session.quickValues.prefix(4), id: \.self) { v in
                        Button("\(v)") { ml = Double(v) }
                            .font(.caption2)
                            .buttonStyle(.bordered)
                            .tint(Farbe.blase)
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(UrineColor.allCases.filter { $0 != .none }) { c in
                    Button {
                        color = color == c ? .none : c
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text(c.emoji)
                            .font(.system(size: 18))
                            .padding(5)
                            .background(
                                color == c ? Farbe.blase.opacity(0.25) : Color.clear,
                                in: Circle()
                            )
                            .overlay(
                                Circle().strokeBorder(
                                    color == c ? Farbe.blase : Color.clear,
                                    lineWidth: 1.5
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.rawValue)
                }
            }

            Button {
                save()
            } label: {
                Label("Erfassen", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .tint(Farbe.blase)
        }
        .padding(.horizontal, 6)
        .navigationTitle("Blase")
        .onAppear { crownFocused = true }
    }

    private func save() {
        let entry = ToiletEntry(urineMl: Int(ml), urineColor: color)
        session.applyLocally(entry)
        session.send(entry, label: "Blase")
        WKInterfaceDevice.current().play(.success)
        dismiss()
    }
}

// MARK: - Darm: Bristol-Typ aus Liste

struct BowelEntryView: View {
    @EnvironmentObject private var session: WatchSessionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Button {
                save(.none)
            } label: {
                Label("Nur erfassen", systemImage: "checkmark.circle")
            }

            ForEach(BristolType.allCases.filter { $0 != .none }) { type in
                Button {
                    save(type)
                } label: {
                    HStack(spacing: 8) {
                        Text(type.emoji)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(type.label).font(.headline)
                            Text(type.shortDesc)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Darm")
    }

    private func save(_ type: BristolType) {
        let entry = ToiletEntry(bowel: true, bristolType: type)
        session.applyLocally(entry)
        session.send(entry, label: "Darm")
        WKInterfaceDevice.current().play(.success)
        dismiss()
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSessionManager.shared)
}
