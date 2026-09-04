import SwiftUI
import VisionKit

// MARK: - Scan-Ergebnis

struct ScanResult: Equatable {
    var name: String
    var barcode: String?
    var charriere: Int?
    var material: String?
}

// MARK: - Scanner-Sheet

/// Kameraansicht zum Scannen von Packungen per Texterkennung (OCR)
/// und Barcode. Erkannte Textblöcke erscheinen als antippbare Liste.
///
/// Ablauf:
/// 1. Barcode erkannt → Katalog-Treffer → sofort übernehmen
/// 2. Kein Treffer → OCR-Texte als antippbare Liste
/// 3. Nutzer tippt auf Text → Name übernommen
/// 4. Barcode + Name im Katalog gespeichert
struct ScannerSheet: View {
    let category: ProductCategory
    let onResult: (ScanResult) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var catalog = ProductCatalog.load()
    @State private var recognizedTexts: [String] = []
    @State private var lastBarcode: String?
    @State private var autoMatched: ScannedProduct?
    @State private var charriere: Int?
    @State private var material: String?

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    scannerContent
                } else {
                    unsupportedView
                }
            }
            .navigationTitle(String(localized: "scan_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Abbrechen")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Scanner-Inhalt

    @ViewBuilder
    private var scannerContent: some View {
        VStack(spacing: 0) {
            DataScannerRepresentable(
                onBarcode: handleBarcode,
                onTexts: handleTexts
            )
            .frame(maxHeight: .infinity)

            resultsPanel
                .frame(maxHeight: 260)
                .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var resultsPanel: some View {
        if let match = autoMatched {
            catalogMatchView(match)
        } else if recognizedTexts.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "scan_hint_title"), systemImage: "viewfinder")
            } description: {
                Text(String(localized: "scan_hint_body"))
            }
        } else {
            textListView
        }
    }

    private func catalogMatchView(_ match: ScannedProduct) -> some View {
        VStack(spacing: 8) {
            Label(String(localized: "scan_known"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)
            Text(match.name).font(.title3.bold())
            if let ch = match.charriere {
                Text("Ch \(ch)").foregroundStyle(.secondary)
            }
            Button(String(localized: "scan_use")) {
                accept(ScanResult(name: match.name,
                                  barcode: match.barcode,
                                  charriere: match.charriere,
                                  material: match.material))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var textListView: some View {
        ScrollView {
            VStack(spacing: 2) {
                Text(String(localized: "scan_tap_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                ForEach(Array(recognizedTexts.enumerated()), id: \.offset) { _, text in
                    Button {
                        pickText(text)
                    } label: {
                        HStack {
                            Text(text)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading)
                }
            }
        }
    }

    // MARK: - Nicht unterstützt

    private var unsupportedView: some View {
        ContentUnavailableView {
            Label(String(localized: "scan_unsupported_title"), systemImage: "camera.fill")
        } description: {
            Text(String(localized: "scan_unsupported_body"))
        }
    }

    // MARK: - Callbacks

    private func handleBarcode(_ code: String) {
        guard lastBarcode != code else { return }
        lastBarcode = code
        if let match = catalog.find(barcode: code) {
            autoMatched = match
        }
    }

    private func handleTexts(_ texts: [String]) {
        let filtered = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 && $0.count <= 80 }
            .filter { !$0.allSatisfy(\.isNumber) }

        if category == .catheter {
            let allText = texts.joined(separator: " ")
            if charriere == nil { charriere = extractCharriere(from: allText) }
            if material == nil { material = extractMaterial(from: allText) }
        }

        let unique = NSOrderedSet(array: filtered).array as? [String] ?? filtered
        if unique != recognizedTexts {
            recognizedTexts = unique
        }
    }

    private func pickText(_ text: String) {
        let ch = charriere ?? extractCharriere(from: text)
        let mat = material ?? extractMaterial(from: text)

        var cleanName = text
        let chPatterns = [
            #"(?i)\s*(?:ch|charrière|charriere|fr)[.\s]*\d{1,2}\s*"#,
            #"(?i)\s*\d{1,2}\s*(?:ch|charrière|charriere|fr)\s*"#
        ]
        for p in chPatterns {
            if let regex = try? NSRegularExpression(pattern: p) {
                cleanName = regex.stringByReplacingMatches(
                    in: cleanName, range: NSRange(cleanName.startIndex..., in: cleanName),
                    withTemplate: " ")
            }
        }
        cleanName = cleanName.trimmingCharacters(in: .whitespaces)
        if cleanName.isEmpty { cleanName = text }

        if let bc = lastBarcode {
            catalog.upsert(barcode: bc, name: cleanName,
                           category: category,
                           charriere: ch, material: mat)
        }

        accept(ScanResult(name: cleanName, barcode: lastBarcode,
                          charriere: ch, material: mat))
    }

    private func accept(_ result: ScanResult) {
        onResult(result)
        dismiss()
    }
}

// MARK: - DataScannerViewController UIKit-Bridge

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onBarcode: (String) -> Void
    let onTexts: ([String]) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.ean8, .ean13, .dataMatrix, .code128, .code39]),
                .text()
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        if !vc.isScanning {
            try? vc.startScanning()
        }
    }

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) {
        if vc.isScanning { vc.stopScanning() }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcode, onTexts: onTexts)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onBarcode: (String) -> Void
        let onTexts: ([String]) -> Void
        private var debounceTask: Task<Void, Never>?

        init(onBarcode: @escaping (String) -> Void, onTexts: @escaping ([String]) -> Void) {
            self.onBarcode = onBarcode
            self.onTexts = onTexts
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            processItems(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            processItems(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didRemove removedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            processItems(allItems)
        }

        private func processItems(_ items: [RecognizedItem]) {
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }

                var texts: [String] = []
                for item in items {
                    switch item {
                    case .barcode(let barcode):
                        if let value = barcode.payloadStringValue, !value.isEmpty {
                            self.onBarcode(value)
                        }
                    case .text(let text):
                        texts.append(text.transcript)
                    @unknown default:
                        break
                    }
                }
                self.onTexts(texts)
            }
        }
    }
}

// MARK: - ScanButton (wiederverwendbar)

/// Kamera-Icon neben einem Textfeld. Zeigt sich nur auf Geräten
/// die DataScanner unterstützen.
struct ScanButton: View {
    let category: ProductCategory
    let onResult: (ScanResult) -> Void
    @State private var showScanner = false

    var body: some View {
        if DataScannerViewController.isSupported {
            Button {
                showScanner = true
            } label: {
                Image(systemName: "barcode.viewfinder")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "scan_a11y_label"))
            .sheet(isPresented: $showScanner) {
                ScannerSheet(category: category, onResult: onResult)
            }
        }
    }
}

// MARK: - Katalog-Übersicht

/// Liste aller gespeicherten Scan-Zuordnungen.
struct ProductCatalogView: View {
    @State private var catalog = ProductCatalog.load()

    private var catheterProducts: [ScannedProduct] { catalog.products(for: .catheter) }
    private var medProducts: [ScannedProduct] { catalog.products(for: .medication) }

    var body: some View {
        List {
            if catalog.products.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "catalog_empty_title"), systemImage: "barcode.viewfinder")
                } description: {
                    Text(String(localized: "catalog_empty_body"))
                }
            } else {
                if !catheterProducts.isEmpty {
                    Section(String(localized: "catalog_section_catheter")) {
                        ForEach(catheterProducts) { product in
                            catalogRow(product)
                        }
                        .onDelete { offsets in
                            for idx in offsets { catalog.remove(id: catheterProducts[idx].id) }
                        }
                    }
                }
                if !medProducts.isEmpty {
                    Section(String(localized: "catalog_section_med")) {
                        ForEach(medProducts) { product in
                            catalogRow(product)
                        }
                        .onDelete { offsets in
                            for idx in offsets { catalog.remove(id: medProducts[idx].id) }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "catalog_title"))
    }

    @ViewBuilder
    private func catalogRow(_ product: ScannedProduct) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.name).font(.body)
            HStack(spacing: 12) {
                if let bc = product.barcode {
                    Label(bc, systemImage: "barcode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let ch = product.charriere {
                    Text("Ch \(ch)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let mat = product.material {
                    Text(mat)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
