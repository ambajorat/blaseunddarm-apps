import SwiftUI
import MessageUI

// MARK: - Bestell-Sheet (4.21)

/// Nachbestellung von Kathetern und Kompressen: Vorschlag aus dem Verbrauch,
/// Mengen anpassbar, fertige Mail an Versorger und/oder Praxis.
/// Abgeschickt wird die Mail immer vom Nutzer selbst.
struct OrderView: View {
    let entries: [ToiletEntry]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var settings = OrderSettings.load()
    @State private var lines: [OrderLine] = []
    @State private var recipient: OrderRecipient = .supplier
    @State private var showMail = false
    @State private var didLoad = false

    private var activeLines: [OrderLine] { lines.filter { $0.packs > 0 } }

    private var messageText: String {
        OrderMail.body(lines: activeLines, recipient: recipient, settings: settings)
    }

    private var addresses: [String] {
        OrderMail.recipients(recipient, settings: settings)
    }

    private var addressMissing: Bool {
        addresses.count < (recipient == .both ? 2 : 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                recipientSection
                linesSection
                messageSection
                sendSection
            }
            .navigationTitle("Nachbestellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .tint(Color.accent)
            .sheet(isPresented: $showMail) {
                MailComposer(recipients: addresses,
                             subject: OrderMail.subject(settings: settings),
                             text: messageText) { result in
                    showMail = false
                    if result == .sent { finish() }
                }
                .ignoresSafeArea()
            }
            .onAppear { loadOnce() }
        }
    }

    private var recipientSection: some View {
        Section {
            Picker("Empfänger", selection: $recipient) {
                ForEach(OrderRecipient.allCases) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Empfänger")
        } footer: {
            if addressMissing {
                Text("Für diese Auswahl fehlt eine E-Mail-Adresse — eintragen unter Einstellungen › Nachbestellung. Du kannst die Adresse auch direkt in der Mail ergänzen.")
                    .font(.caption)
            }
        }
    }

    private var linesSection: some View {
        Section {
            if lines.isEmpty {
                Text("Kein Bestand aktiv — schalte den Katheterbestand in den Einstellungen ein.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach($lines) { $line in
                Stepper(value: $line.packs, in: 0...40) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.name)
                            .font(.subheadline.weight(.medium))
                        Text(packText(line))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Bestellung")
        } footer: {
            Text(planFooter)
                .font(.caption)
        }
    }

    private var messageSection: some View {
        Section {
            Text(messageText)
                .font(.callout)
                .textSelection(.enabled)
                .padding(.vertical, 4)
        } header: {
            Text("Nachricht")
        }
    }

    private var sendSection: some View {
        Section {
            Button {
                if MailComposer.canSend {
                    showMail = true
                } else if let url = mailURL {
                    openURL(url)
                }
            } label: {
                Label("Als E-Mail senden", systemImage: "envelope")
            }
            .disabled(activeLines.isEmpty)

            ShareLink(item: messageText, subject: Text(OrderMail.subject(settings: settings))) {
                Label("Senden über …", systemImage: "square.and.arrow.up")
            }
            .disabled(activeLines.isEmpty)

            Button {
                finish()
            } label: {
                Label("Als bestellt markieren", systemImage: "checkmark.circle")
            }
            .disabled(activeLines.isEmpty)
        } footer: {
            Text("Wird die Mail aus der App gesendet, gilt die Bestellung automatisch als bestellt. Bis die Lieferung eingebucht ist, erinnert die App nicht erneut.")
                .font(.caption)
        }
    }

    private func packText(_ line: OrderLine) -> String {
        let format = line.packs == 1
            ? String(localized: "%lld Packung · %lld Stück")
            : String(localized: "%lld Packungen · %lld Stück")
        return String(format: format, line.packs, line.pieces)
    }

    private var planFooter: String {
        if let usage = SupplyUsage.dailyVoids(entries: entries) {
            return String(format: String(localized: "Bedarf für %lld Tage bei Ø %.1f Entleerungen pro Tag, auf ganze Packungen aufgerundet. Sortenmix nach deinem Verbrauch der letzten 30 Tage."),
                          settings.orderDays, usage)
        }
        return String(localized: "Noch zu wenige Einträge für eine Bedarfsrechnung — vorgeschlagen ist je eine Packung. Passe die Mengen an.")
    }

    private func loadOnce() {
        guard !didLoad else { return }
        didLoad = true
        lines = OrderPlan.lines(catheter: CatheterStock.load(), compress: CompressStock.load(),
                                orderDays: settings.orderDays, entries: entries)
        let last = OrderRecipient(rawValue: settings.lastRecipient) ?? .supplier
        if OrderMail.recipients(last, settings: settings).isEmpty,
           !OrderMail.recipients(.practice, settings: settings).isEmpty {
            recipient = .practice
        } else {
            recipient = last
        }
    }

    private func finish() {
        var stored = OrderSettings.load()
        stored.lastRecipient = recipient.rawValue
        stored.save()
        OrderState.markOrdered()
        dismiss()
    }

    /// Ersatzweg ohne eingerichtetes Apple Mail (z. B. Gmail als Standard).
    private var mailURL: URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }
        let to = addresses.map(enc).joined(separator: ",")
        let body = messageText.replacingOccurrences(of: "\n", with: "\r\n")
        return URL(string: "mailto:\(to)?subject=\(enc(OrderMail.subject(settings: settings)))&body=\(enc(body))")
    }
}

// MARK: - Apple-Mail-Fenster

struct MailComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let text: String
    let onFinish: (MFMailComposeResult) -> Void

    static var canSend: Bool { MFMailComposeViewController.canSendMail() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(text, isHTML: false)
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void
        init(onFinish: @escaping (MFMailComposeResult) -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            onFinish(result)
        }
    }
}

// MARK: - Einstellungen: Kompressen + Nachbestellung

/// Zwei Sektionen für die Einstellungen (unter dem Katheterbestand).
/// Eigenes View mit eigenem Zustand, damit die große SettingsView-List
/// nicht weiter wächst (Typprüfer-Grenze). Gespeichert wird direkt im
/// Binding-Setter, nicht per onChange.
struct SupplySettingsSections: View {
    let catheter: CatheterStock
    let entries: [ToiletEntry]

    @State private var compress = CompressStock.load()
    @State private var order = OrderSettings.load()
    @State private var orderedOn = OrderState.orderedOn
    @State private var stockInput = ""
    @State private var deliveryInput = ""
    @State private var showOrder = false

    private enum Field: Hashable { case stock, delivery }
    @FocusState private var focus: Field?

    private var compressBinding: Binding<CompressStock> {
        Binding(get: { compress }, set: { compress = $0; $0.save() })
    }

    private var orderBinding: Binding<OrderSettings> {
        Binding(get: { order }, set: { order = $0; $0.save() })
    }

    var body: some View {
        if catheter.enabled {
            compressSection
            orderSection
        }
    }

    private var compressSection: some View {
        Section {
            Toggle(isOn: compressBinding.enabled) {
                Label("Kompressenbestand verfolgen", systemImage: "bandage.fill")
            }
            .onAppear {
                compress = CompressStock.load()
                order = OrderSettings.load()
                orderedOn = OrderState.orderedOn
            }

            if compress.enabled {
                HStack {
                    Text("Bezeichnung")
                    TextField("Sterile Kompressen 10 × 10 cm, 2er-Pack", text: compressBinding.name)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Aktueller Bestand")
                    Spacer()
                    Text(String(format: String(localized: "%lld 2er-Packs"), compress.currentStock(entries: entries)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("Bestand eintragen", text: $stockInput)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: .stock)
                        .toolbar { doneToolbar(for: .stock) }
                    Button {
                        if let val = Int(stockInput), val >= 0 {
                            var next = compress
                            next.setStock(val)
                            compressBinding.wrappedValue = next
                            stockInput = ""
                            focus = nil
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentBlue)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled((Int(stockInput) ?? -1) < 0)
                }

                HStack {
                    TextField("Lieferung erfassen (2er-Packs)", text: $deliveryInput)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: .delivery)
                        .toolbar { doneToolbar(for: .delivery) }
                    Button {
                        if let val = Int(deliveryInput), val > 0 {
                            var next = compress
                            next.addDelivery(val, entries: entries)
                            compressBinding.wrappedValue = next
                            deliveryInput = ""
                            focus = nil
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentBlue)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled((Int(deliveryInput) ?? 0) <= 0)
                }

                Stepper(value: compressBinding.packSize, in: 10...200, step: 10) {
                    HStack {
                        Text("2er-Packs je Packung")
                        Spacer()
                        Text("\(compress.packSize)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Kompressen")
        } footer: {
            Text(compressFooter)
                .font(.caption)
        }
    }

    private var orderSection: some View {
        Section {
            HStack {
                Text("Versorger")
                TextField("E-Mail", text: orderBinding.supplierEmail)
                    .mailField()
            }
            HStack {
                Text("Kundennummer")
                TextField("optional", text: orderBinding.customerNumber)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
            }
            HStack {
                Text("Praxis")
                TextField("E-Mail", text: orderBinding.practiceEmail)
                    .mailField()
            }
            HStack {
                Text("Dein Name")
                TextField("optional", text: orderBinding.patientName)
                    .multilineTextAlignment(.trailing)
                    .textContentType(.name)
            }
            HStack {
                Text("Geburtsdatum")
                TextField("optional", text: orderBinding.birthDate)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
            }

            Stepper(value: orderBinding.orderDays, in: 10...90, step: 5) {
                HStack {
                    Text("Bestellen für")
                    Spacer()
                    Text(String(format: String(localized: "%lld Tage"), order.orderDays))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            if OrderState.isPending(orderedOn: orderedOn, now: .now), let date = orderedOn {
                HStack {
                    Text(String(format: String(localized: "Bestellt am %@"), date.formatted(.dateTime.day().month())))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Zurücksetzen") {
                        OrderState.clear()
                        orderedOn = nil
                    }
                    .buttonStyle(.borderless)
                }
            }

            Button {
                focus = nil
                showOrder = true
            } label: {
                Label("Jetzt nachbestellen", systemImage: "shippingbox.fill")
            }
            .sheet(isPresented: $showOrder, onDismiss: {
                order = OrderSettings.load()
                orderedOn = OrderState.orderedOn
            }) {
                OrderView(entries: entries)
            }
        } header: {
            Text("Nachbestellung")
        } footer: {
            Text(String(format: String(localized: "Reichen Katheter oder Kompressen für weniger als %lld Tage, erinnert dich die App ans Nachbestellen. Die Mail ist vorbereitet — abschicken tust du sie selbst."), catheter.warnDays))
                .font(.caption)
        }
    }

    private var compressFooter: String {
        guard compress.enabled else {
            return String(localized: "Optional: Zählt deine sterilen Kompressen mit — jede Blasenentleerung verbraucht ein 2er-Pack.")
        }
        if compress.currentStock(entries: entries) == 0 {
            return String(localized: "Trage deinen aktuellen Bestand in 2er-Packs ein, um zu starten.")
        }
        if let days = compress.daysRemaining(entries: entries) {
            return String(format: String(localized: "Ein 2er-Pack je Entleerung — reicht noch etwa %lld Tage."), days)
        }
        return String(localized: "Ein 2er-Pack je Entleerung. Die Reichweite erscheint nach ein paar Tagen mit Einträgen.")
    }

    @ToolbarContentBuilder
    private func doneToolbar(for field: Field) -> some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            if focus == field {
                Spacer()
                Button("Fertig") { focus = nil }
            }
        }
    }
}

private extension View {
    func mailField() -> some View {
        self
            .multilineTextAlignment(.trailing)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}

// MARK: - Statistik-Karte: Kompressen + Bestellstatus

/// Karte unter dem Katheterbestand: Kompressenbestand und — sobald die
/// Reichweite unter der Warnschwelle liegt — der Knopf zum Nachbestellen.
struct SupplyStatusCard: View {
    let entries: [ToiletEntry]

    @State private var showOrder = false
    @State private var orderedOn = OrderState.orderedOn

    var body: some View {
        let catheter = CatheterStock.load()
        let compress = CompressStock.load()
        let status = OrderPlan.status(catheter: catheter, compress: compress, entries: entries)
        if catheter.enabled && (compress.enabled || status.isDue) {
            VStack(alignment: .leading, spacing: 10) {
                if compress.enabled {
                    HStack(spacing: 12) {
                        Image(systemName: "bandage.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: String(localized: "%lld 2er-Packs Kompressen im Bestand"),
                                        compress.currentStock(entries: entries)))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                            if let days = status.compressDays {
                                Text(String(format: String(localized: "Reicht etwa %lld Tage"), days))
                                    .font(.caption)
                                    .foregroundStyle(status.compressLow ? Color.red : Color.secondary)
                            } else {
                                Text("Reichweite folgt nach ein paar Tagen mit Einträgen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
                if status.isDue {
                    SupplyOrderRow(entries: entries, showOrder: $showOrder, orderedOn: $orderedOn)
                }
            }
            .padding(16)
            .background(Color.cardBg, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pillBorder, lineWidth: 0.5))
            .onAppear { orderedOn = OrderState.orderedOn }
        }
    }
}

/// Sektion für den Hinweise-Reiter — erscheint nur, wenn Vorrat knapp ist.
struct SupplyOrderAlertSection: View {
    let entries: [ToiletEntry]

    @State private var showOrder = false
    @State private var orderedOn = OrderState.orderedOn

    var body: some View {
        let status = OrderPlan.status(catheter: CatheterStock.load(), compress: CompressStock.load(), entries: entries)
        if status.isDue {
            Section {
                Text(SupplyOrderRow.summary(status))
                    .font(.subheadline)
                    .onAppear { orderedOn = OrderState.orderedOn }
                SupplyOrderRow(entries: entries, showOrder: $showOrder, orderedOn: $orderedOn)
            } header: {
                Text("Vorrat")
            }
        }
    }
}

/// Gemeinsame Zeile: "Bestellt am …" oder der Bestell-Knopf samt Sheet.
struct SupplyOrderRow: View {
    let entries: [ToiletEntry]
    @Binding var showOrder: Bool
    @Binding var orderedOn: Date?

    static func summary(_ status: SupplyStatus) -> String {
        if status.catheterLow, status.compressLow, let c = status.catheterDays, let k = status.compressDays {
            return String(format: String(localized: "Katheter reichen noch etwa %lld Tage, Kompressen etwa %lld Tage."), c, k)
        }
        if status.compressLow, let k = status.compressDays {
            return String(format: String(localized: "Kompressen reichen noch etwa %lld Tage."), k)
        }
        return String(format: String(localized: "Katheter reichen noch etwa %lld Tage."), status.catheterDays ?? 0)
    }

    var body: some View {
        Group {
            if OrderState.isPending(orderedOn: orderedOn, now: .now), let date = orderedOn {
                Label(String(format: String(localized: "Bestellt am %@ — wartet auf Lieferung"),
                             date.formatted(.dateTime.day().month())),
                      systemImage: "shippingbox")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    showOrder = true
                } label: {
                    Label("Jetzt nachbestellen", systemImage: "shippingbox.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $showOrder, onDismiss: { orderedOn = OrderState.orderedOn }) {
            OrderView(entries: entries)
        }
    }
}
