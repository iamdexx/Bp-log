import SwiftUI
import SwiftData
import BPCore

struct HomeView: View {
    @Query(sort: \Reading.date, order: .reverse) private var readings: [Reading]
    @State private var showLog = false
    @State private var showLegend = false

    private var samples: [BPSample] { readings.samples }
    private var latest: Reading? { readings.first }
    private var week: BPAverage? { BPStats.average(samples, lastDays: 7) }
    private var month: BPAverage? { BPStats.average(samples, lastDays: 30) }
    private var weekByTime: [TimeOfDay: BPAverage] { BPStats.averagesByTimeOfDay(BPStats.samples(samples, lastDays: 7)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    latestCard
                    BigButton(title: "Log a reading", systemImage: "plus.circle.fill") { showLog = true }
                        .padding(.horizontal)
                    if !readings.isEmpty {
                        averagesCard
                        TrendChart(samples: BPStats.samples(samples, lastDays: 30))
                            .padding(.horizontal)
                    } else {
                        tips
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("BP Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showLegend = true } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("What the colors mean")
                }
            }
            .sheet(isPresented: $showLog) { LogReadingView() }
            .sheet(isPresented: $showLegend) {
                NavigationStack {
                    List {
                        Section("Blood pressure ranges (AHA)") { LegendView() }
                        Section {
                            Text("These ranges come from the American Heart Association. BP Log is a logbook. It does not diagnose or treat anything. Talk to your doctor about what your numbers mean for you.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("Ranges")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showLegend = false } } }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var latestCard: some View {
        VStack(spacing: 10) {
            if let latest {
                Text("Latest reading").font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(latest.systolic)").font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("/").font(.system(size: 40, weight: .light)).foregroundStyle(.secondary)
                    Text("\(latest.diastolic)").font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                }
                .foregroundStyle(latest.category.color)
                HStack(spacing: 12) {
                    CategoryPill(category: latest.category)
                    if let pulse = latest.pulse {
                        Label("\(pulse) bpm", systemImage: "heart.fill").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Text(latest.date, format: .dateTime.weekday(.wide).month().day().hour().minute())
                    .font(.footnote).foregroundStyle(.secondary)
                Text(latest.category.guidance)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(latest.category == .crisis ? .red : .secondary)
                    .padding(.top, 4)
            } else {
                Image(systemName: "heart.text.square").font(.system(size: 48)).foregroundStyle(.secondary)
                Text("No readings yet").font(.title3.weight(.semibold))
                Text("Take a reading on your cuff, then tap the button below.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private var averagesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Averages").font(.headline)
            HStack(spacing: 12) {
                AverageTile(title: "7 days", average: week)
                AverageTile(title: "30 days", average: month)
            }
            if weekByTime[.morning] != nil || weekByTime[.evening] != nil {
                Divider()
                HStack(spacing: 12) {
                    AverageTile(title: "Mornings (7d)", average: weekByTime[.morning], small: true)
                    AverageTile(title: "Evenings (7d)", average: weekByTime[.evening], small: true)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to get a good reading").font(.headline)
            ForEach(["Sit quietly for 5 minutes first, feet flat, back supported.",
                     "Arm at heart level, cuff on bare skin.",
                     "No coffee, smoking or exercise in the 30 minutes before.",
                     "Take two readings a minute apart. Log both.",
                     "Same times every day, morning and evening, is what doctors want to see."], id: \.self) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(tip).font(.subheadline)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
}

struct AverageTile: View {
    let title: String
    let average: BPAverage?
    var small = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            if let average {
                Text("\(average.systolic)/\(average.diastolic)")
                    .font(small ? .title3.weight(.semibold) : .title.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(average.category.color)
                HStack(spacing: 6) {
                    CategoryPill(category: average.category, compact: true)
                    Text("\(average.count) readings").font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text("No data").font(small ? .subheadline : .title3).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
