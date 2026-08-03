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
    @FocusState private var crownFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("\(Int(ml)) ml")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Farbe.blase)
                .focusable()
                .focused($crownFocused)
                .digitalCrownRotation($ml, from: 0, through: 1000, by: 25,
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
        let entry = ToiletEntry(urineMl: Int(ml))
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
