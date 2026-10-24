import SwiftUI
import Charts
import BPCore

struct TrendChart: View {
    let samples: [BPSample]
    var title = "Last 30 days"

    private var sorted: [BPSample] { samples.sorted { $0.date < $1.date } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            if sorted.count < 2 {
                Text("Log a few more readings to see your trend.").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    RectangleMark(yStart: .value("", 0), yEnd: .value("", 80)).foregroundStyle(BPCategory.normal.color.opacity(0.07))
                    RectangleMark(yStart: .value("", 80), yEnd: .value("", 90)).foregroundStyle(BPCategory.stage1.color.opacity(0.07))
                    RectangleMark(yStart: .value("", 120), yEnd: .value("", 130)).foregroundStyle(BPCategory.elevated.color.opacity(0.08))
                    RectangleMark(yStart: .value("", 130), yEnd: .value("", 140)).foregroundStyle(BPCategory.stage1.color.opacity(0.08))
                    RectangleMark(yStart: .value("", 140), yEnd: .value("", 200)).foregroundStyle(BPCategory.stage2.color.opacity(0.07))
                    ForEach(sorted) { s in
                        LineMark(x: .value("Date", s.date), y: .value("Systolic", s.systolic), series: .value("Series", "Systolic"))
                            .foregroundStyle(.red.opacity(0.8))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Date", s.date), y: .value("Systolic", s.systolic))
                            .foregroundStyle(s.category.color)
                            .symbolSize(30)
                        LineMark(x: .value("Date", s.date), y: .value("Diastolic", s.diastolic), series: .value("Series", "Diastolic"))
                            .foregroundStyle(.blue.opacity(0.8))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Date", s.date), y: .value("Diastolic", s.diastolic))
                            .foregroundStyle(.blue)
                            .symbolSize(20)
                    }
                }
                .chartYScale(domain: yDomain)
                .chartYAxis { AxisMarks(values: [60, 80, 100, 120, 140, 160, 180]) }
                .frame(height: 200)
                HStack(spacing: 16) {
                    Label("Systolic (top)", systemImage: "circle.fill").foregroundStyle(.red)
                    Label("Diastolic (bottom)", systemImage: "circle.fill").foregroundStyle(.blue)
                }
                .font(.caption)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var yDomain: ClosedRange<Int> {
        guard let mm = BPStats.minMax(sorted) else { return 50...180 }
        let lo = max(30, min(60, mm.diastolic.lowerBound - 10))
        let hi = min(260, max(160, mm.systolic.upperBound + 10))
        return lo...hi
    }
}
