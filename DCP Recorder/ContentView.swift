//
//  ContentView.swift
//  DCP Recorder
//
//  Created by Brian Haeffner on 8/1/26.
//

import Charts
import SwiftUI

struct ContentView: View {
    @State private var unitSystem: DCPUnitSystem = .english
    @State private var deflectionInput = ""
    @State private var blows: [DCPBlow] = DCPBlow.sampleData

    private var records: [DCPRecord] {
        DCPRecord.records(from: blows)
    }

    private var currentTotal: Double {
        records.last?.totalPenetration ?? 0
    }

    private var averagePenetrationIndex: Double {
        guard !records.isEmpty else { return 0 }
        let total = records.reduce(0) { $0 + $1.incrementalPenetration }
        return total / Double(records.count)
    }

    private var averageCBR: Double? {
        DCPRecord.cbr(forPenetrationIndex: averagePenetrationIndex)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    testSummary
                    entryPanel
                    readingsTable
                    penetrationChart
                }
                .padding()
                .frame(maxWidth: 1100, alignment: .topLeading)
            }
            .navigationTitle("DCP Recorder")
        }
    }

    private var testSummary: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                summaryTile(
                    title: "Blows",
                    value: "\(records.count)",
                    systemImage: "hammer"
                )

                summaryTile(
                    title: "Total Penetration",
                    value: unitSystem.formattedLength(currentTotal),
                    systemImage: "ruler"
                )
            }

            GridRow {
                summaryTile(
                    title: "Average PI",
                    value: unitSystem.formattedPenetrationIndex(averagePenetrationIndex),
                    systemImage: "arrow.down.to.line.compact"
                )

                summaryTile(
                    title: "Estimated CBR",
                    value: averageCBR.map { "\($0.formatted(.number.precision(.fractionLength(1))))%" } ?? "--",
                    systemImage: "percent"
                )
            }
        }
    }

    private func summaryTile(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var entryPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Units", selection: $unitSystem) {
                ForEach(DCPUnitSystem.allCases) { system in
                    Text(system.name).tag(system)
                }
            }
            .pickerStyle(.segmented)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Deflection Per Blow")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(unitSystem.inputPlaceholder, text: $deflectionInput)
                        .textFieldStyle(.roundedBorder)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                }

                Button {
                    addBlow()
                } label: {
                    Label("Add Blow", systemImage: "plus")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedDeflection == nil)
            }

            HStack(spacing: 10) {
                Button {
                    removeLastBlow()
                } label: {
                    Label("Remove Last", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .disabled(blows.isEmpty)

                Button(role: .destructive) {
                    clearBlows()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(blows.isEmpty)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var readingsTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Blow Readings")
                .font(.title3.bold())

            Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    tableHeader("Blow")
                    tableHeader("Increment")
                    tableHeader("Total")
                    tableHeader("PI")
                    tableHeader("CBR")
                }

                Divider()
                    .gridCellColumns(5)

                if records.isEmpty {
                    GridRow {
                        Text("No blows recorded")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .gridCellColumns(5)
                    }
                } else {
                    ForEach(records) { record in
                        GridRow {
                            Text("\(record.blowNumber)")
                                .monospacedDigit()

                            Text(unitSystem.formattedLength(record.incrementalPenetration))
                                .monospacedDigit()

                            Text(unitSystem.formattedLength(record.totalPenetration))
                                .monospacedDigit()

                            Text(unitSystem.formattedPenetrationIndex(record.penetrationIndex))
                                .monospacedDigit()

                            Text(record.cbr.formatted(.number.precision(.fractionLength(1))) + "%")
                                .monospacedDigit()
                        }

                        Divider()
                            .gridCellColumns(5)
                    }
                }
            }
            .font(.callout)
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func tableHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var penetrationChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Penetration Profile")
                .font(.title3.bold())

            Chart(records) { record in
                LineMark(
                    x: .value("Penetration Index", unitSystem.displayPenetrationIndex(record.penetrationIndex)),
                    y: .value("Penetration Below Top of Soil", unitSystem.displayLength(record.totalPenetration))
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Penetration Index", unitSystem.displayPenetrationIndex(record.penetrationIndex)),
                    y: .value("Penetration Below Top of Soil", unitSystem.displayLength(record.totalPenetration))
                )
            }
            .chartXAxisLabel("Penetration index (\(unitSystem.penetrationIndexSymbol))")
            .chartYAxisLabel("Penetration below top of soil (\(unitSystem.lengthSymbol))")
            .chartYScale(domain: .automatic(includesZero: true), reversed: true)
            .frame(height: 320)
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var parsedDeflection: Double? {
        let normalized = deflectionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(normalized), value > 0 else { return nil }
        return unitSystem.metricLength(fromDisplayed: value)
    }

    private func addBlow() {
        guard let deflection = parsedDeflection else { return }
        withAnimation {
            blows.append(DCPBlow(incrementalPenetration: deflection))
            deflectionInput = ""
        }
    }

    private func removeLastBlow() {
        guard !blows.isEmpty else { return }
        withAnimation {
            _ = blows.removeLast()
        }
    }

    private func clearBlows() {
        withAnimation {
            blows.removeAll()
        }
    }
}

private enum DCPUnitSystem: String, CaseIterable, Identifiable {
    case english
    case metric

    var id: Self { self }

    var name: String {
        switch self {
        case .english:
            "English"
        case .metric:
            "Metric"
        }
    }

    var lengthSymbol: String {
        switch self {
        case .english:
            "in"
        case .metric:
            "mm"
        }
    }

    var penetrationIndexSymbol: String {
        switch self {
        case .english:
            "in/blow"
        case .metric:
            "mm/blow"
        }
    }

    var inputPlaceholder: String {
        switch self {
        case .english:
            "inches"
        case .metric:
            "millimeters"
        }
    }

    func metricLength(fromDisplayed value: Double) -> Double {
        switch self {
        case .english:
            value * 25.4
        case .metric:
            value
        }
    }

    func displayLength(_ millimeters: Double) -> Double {
        switch self {
        case .english:
            millimeters / 25.4
        case .metric:
            millimeters
        }
    }

    func displayPenetrationIndex(_ millimetersPerBlow: Double) -> Double {
        displayLength(millimetersPerBlow)
    }

    func formattedLength(_ millimeters: Double) -> String {
        "\(displayLength(millimeters).formatted(.number.precision(.fractionLength(2)))) \(lengthSymbol)"
    }

    func formattedPenetrationIndex(_ millimetersPerBlow: Double) -> String {
        "\(displayPenetrationIndex(millimetersPerBlow).formatted(.number.precision(.fractionLength(2)))) \(penetrationIndexSymbol)"
    }
}

private struct DCPBlow: Identifiable {
    let id = UUID()
    let incrementalPenetration: Double

    static let sampleData = [
        DCPBlow(incrementalPenetration: 7.6),
        DCPBlow(incrementalPenetration: 8.1),
        DCPBlow(incrementalPenetration: 9.0),
        DCPBlow(incrementalPenetration: 10.4),
        DCPBlow(incrementalPenetration: 12.2)
    ]
}

private struct DCPRecord: Identifiable {
    let id: UUID
    let blowNumber: Int
    let incrementalPenetration: Double
    let totalPenetration: Double
    let penetrationIndex: Double
    let cbr: Double

    static func records(from blows: [DCPBlow]) -> [DCPRecord] {
        var totalPenetration = 0.0

        return blows.enumerated().map { index, blow in
            totalPenetration += blow.incrementalPenetration
            let penetrationIndex = blow.incrementalPenetration

            return DCPRecord(
                id: blow.id,
                blowNumber: index + 1,
                incrementalPenetration: blow.incrementalPenetration,
                totalPenetration: totalPenetration,
                penetrationIndex: penetrationIndex,
                cbr: cbr(forPenetrationIndex: penetrationIndex) ?? 0
            )
        }
    }

    static func cbr(forPenetrationIndex penetrationIndex: Double) -> Double? {
        guard penetrationIndex > 0 else { return nil }
        return 292 / pow(penetrationIndex, 1.12)
    }
}

#Preview {
    ContentView()
}
