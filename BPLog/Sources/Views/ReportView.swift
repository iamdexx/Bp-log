import SwiftUI
import SwiftData
import PDFKit
import BPCore

struct ReportView: View {
    let profileID: UUID?
    @EnvironmentObject private var settings: AppSettings
    @Query private var readings: [Reading]
    @Query private var meds: [Medication]
    @Query(sort: \Profile.sortOrder) private var profiles: [Profile]
    @State private var period: ReportPeriod = .month
    @State private var pdfURL: URL?
    @State private var csvURL: URL?
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    init(profileID: UUID?) {
        self.profileID = profileID
        _readings = Query(filter: #Predicate<Reading> { $0.profileID == profileID }, sort: [SortDescriptor(\Reading.date, order: .reverse)])
        _meds = Query(filter: #Predicate<Medication> { $0.profileID == profileID && $0.isActive }, sort: [SortDescriptor(\Medication.createdAt)])
    }

    private var personName: String {
        if let profileID { return profiles.first { $0.id == profileID }?.name ?? "" }
        return settings.patientName
    }
    private var report: BPReport { BPReport(samples: readings.samples, period: period, patientName: personName) }
    private var medNames: [String] { meds.map { [$0.name, $0.dose].filter { !$0.isEmpty }.joined(separator: " ") } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Period", selection: $period) {
                        ForEach(ReportPeriod.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    summary
                    BigButton(title: "Share PDF with doctor", systemImage: "square.and.arrow.up") { share(csv: false) }
                        .disabled(report.samples.isEmpty)
                    HStack(spacing: 12) {
                        Button { share(csv: true) } label: {
                            Label("Email PDF + spreadsheet", systemImage: "envelope").frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        Button { exportCSVOnly() } label: {
                            Label("CSV only", systemImage: "tablecells").frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                    .disabled(report.samples.isEmpty)
                    if profileID == nil {
                        TextField("Your name on the report (optional)", text: $settings.patientName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                    }
                    if let pdfURL {
                        PDFPreview(url: pdfURL)
                            .frame(height: 420)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Doctor report")
            .sheet(isPresented: $showShare) {
                ShareSheet(items: shareItems)
            }
            .task(id: "\(period.rawValue)-\(readings.count)-\(personName)-\(settings.guidelineRaw)-\(meds.count)") { regenerate() }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let avg = report.overall {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(avg.systolic)/\(avg.diastolic)").font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(avg.category.color)
                    Text("average").foregroundStyle(.secondary)
                    Spacer()
                    CategoryPill(category: avg.category)
                }
                Text("\(avg.count) readings, \(String(format: "%.1f", report.readingsPerDay)) per day")
                    .font(.subheadline).foregroundStyle(.secondary)
                if report.highShare > 0 {
                    Text("\(Int((report.highShare * 100).rounded()))% of readings were in the high range.")
                        .font(.subheadline)
                }
                HStack(spacing: 12) {
                    ForEach([TimeOfDay.morning, .evening], id: \.self) { tod in
                        if let a = report.byTimeOfDay[tod] {
                            VStack(alignment: .leading) {
                                Text(tod.title).font(.caption).foregroundStyle(.secondary)
                                Text("\(a.systolic)/\(a.diastolic)").font(.headline).monospacedDigit()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } else {
                Text("No readings in the last \(period.title). Log a few and your report will build itself.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func regenerate() {
        guard !report.samples.isEmpty else { pdfURL = nil; csvURL = nil; return }
        let data = PDFReportBuilder.render(report, medications: medNames)
        let dir = FileManager.default.temporaryDirectory
        let pdf = dir.appendingPathComponent("BP-Log-\(period.days)-days.pdf")
        try? data.write(to: pdf, options: .atomic)
        pdfURL = pdf
        let inPeriod = readings.filter { r in report.samples.contains { $0.id == r.id } }
        let csv = dir.appendingPathComponent("BP-Log-\(period.days)-days.csv")
        try? CSVExporter.render(inPeriod).data(using: .utf8)?.write(to: csv, options: .atomic)
        csvURL = csv
    }

    private func share(csv: Bool) {
        if pdfURL == nil { regenerate() }
        guard let pdfURL else { return }
        shareItems = csv ? [pdfURL, csvURL].compactMap { $0 } : [pdfURL]
        showShare = true
    }

    private func exportCSVOnly() {
        if csvURL == nil { regenerate() }
        guard let csvURL else { return }
        shareItems = [csvURL]
        showShare = true
    }
}

struct PDFPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.backgroundColor = .secondarySystemBackground
        return v
    }
    func updateUIView(_ v: PDFView, context: Context) {
        if v.document?.documentURL != url { v.document = PDFDocument(url: url) }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
