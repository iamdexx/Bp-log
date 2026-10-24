import SwiftUI
import SwiftData
import PDFKit
import BPCore

struct ReportView: View {
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \Reading.date, order: .reverse) private var readings: [Reading]
    @State private var period: ReportPeriod = .month
    @State private var pdfURL: URL?
    @State private var showShare = false

    private var report: BPReport { BPReport(samples: readings.samples, period: period, patientName: settings.patientName) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Period", selection: $period) {
                        ForEach(ReportPeriod.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    summary
                    BigButton(title: "Share PDF with doctor", systemImage: "square.and.arrow.up") { share() }
                        .disabled(report.samples.isEmpty)
                    TextField("Your name on the report (optional)", text: $settings.patientName)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
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
                if let pdfURL { ShareSheet(items: [pdfURL]) }
            }
            .task(id: "\(period.rawValue)-\(readings.count)-\(settings.patientName)") { regenerate() }
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
        guard !report.samples.isEmpty else { pdfURL = nil; return }
        let data = PDFReportBuilder.render(report)
        let name = "BP-Log-\(period.days)-days.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url, options: .atomic)
        pdfURL = url
    }

    private func share() {
        if pdfURL == nil { regenerate() }
        showShare = pdfURL != nil
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
