//
//  ContentView.swift
//  DCP Recorder
//
//  Created by Brian Haeffner on 8/1/26.
//

import Charts
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DCPProject.updatedAt, order: .reverse) private var projects: [DCPProject]

    @AppStorage("preferredUnitSystem") private var unitSystem: DCPUnitSystem = .english
    @State private var projectTitle = "Untitled Project"
    @State private var deflectionInput = ""
    @State private var blows: [DCPBlow] = []
    @State private var selectedProject: DCPProject?
    @State private var selectedProjectID: PersistentIdentifier?
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
    @State private var saveStatus = "Not saved"
    @State private var errorMessage: String?

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
        NavigationSplitView(preferredCompactColumn: $preferredCompactColumn) {
            projectSidebar
        } detail: {
            projectEditor
        }
        Group {
            Text("Copyright 2026 smallPond Technologies, LLC")
            Text("Developed by Brian A Haeffner")
        }
        .font(.caption)

    }

    private var projectSidebar: some View {
        List(selection: $selectedProjectID) {
            Button {
                newProject()
            } label: {
                Label("New Project", systemImage: "plus")
            }

            Section("Saved Projects") {
                if projects.isEmpty {
                    Text("No saved projects")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(projects) { project in
                        Button {
                            loadProject(project)
                        } label: {
                            ProjectRow(project: project, isSelected: project.persistentModelID == selectedProjectID)
                        }
                        .buttonStyle(.plain)
                        .tag(project.persistentModelID)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            ShareLink(
                                item: csvExport(for: project),
                                preview: SharePreview(
                                    "\(project.title).csv",
                                    image: Image(systemName: "tablecells")
                                )
                            ) {
                                Label("CSV", systemImage: "square.and.arrow.up")
                            }
                            .tint(.green)

                            Button(role: .destructive) {
                                deleteProject(project)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteProject(project)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteProjects)
                }
            }
        }
        .navigationTitle("DCP Recorder")
    }

    private var projectEditor: some View {
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
        .navigationTitle(projectTitle)
        .toolbar {
            ToolbarItem {
                Button {
                    newProject()
                } label: {
                    Label("New Project", systemImage: "doc.badge.plus")
                }
            }
        }
        .onDisappear {
            autosaveProject()
        }
        .alert("Unable to Autosave Project", isPresented: errorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
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
                    value: averageCBR.map { "\(DCPNumberFormatter.measurement($0))%" } ?? "--",
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
        .frame(minHeight: 76)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var entryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            projectSettingsSection
            blowInputSection
        }
    }

    private var projectSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Project Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Project name", text: $projectTitle)
                    .textFieldStyle(.roundedBorder)
            }

            Picker("Units", selection: $unitSystem) {
                ForEach(DCPUnitSystem.allCases) { system in
                    Text(system.pickerLabel).tag(system)
                }
            }
            .pickerStyle(.segmented)

            Text(saveStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var blowInputSection: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    ForEach(records.indices, id: \.self) { index in
                        let record = records[index]

                        GridRow {
                            Text("\(record.blowNumber)")
                                .monospacedDigit()

                            TextField(
                                unitSystem.lengthSymbol,
                                value: incrementBinding(for: index),
                                format: .number.precision(.fractionLength(0...2))
                            )
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 110)

                            Text(unitSystem.formattedLength(record.totalPenetration))
                                .monospacedDigit()

                            Text(unitSystem.formattedPenetrationIndex(record.penetrationIndex))
                                .monospacedDigit()

                            Text(DCPNumberFormatter.measurement(record.cbr) + "%")
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

    private func incrementBinding(for index: Int) -> Binding<Double> {
        Binding {
            guard blows.indices.contains(index) else { return 0 }
            return unitSystem.displayLength(blows[index].incrementalPenetration)
        } set: { newValue in
            guard blows.indices.contains(index), newValue > 0 else { return }
            blows[index].incrementalPenetration = unitSystem.metricLength(fromDisplayed: newValue)
        }
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
            .chartYScale(domain: .automatic(includesZero: true, reversed: true))
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

    private var errorBinding: Binding<Bool> {
        Binding {
            errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                errorMessage = nil
            }
        }
    }

    private func newProject() {
        autosaveProject()

        let now = Date()
        let project = DCPProject(
            title: nextProjectTitle(),
            createdAt: now,
            updatedAt: now,
            unitSystemRawValue: unitSystem.rawValue
        )
        modelContext.insert(project)

        do {
            try modelContext.save()
            loadProject(project)
            preferredCompactColumn = .detail
        } catch {
            modelContext.delete(project)
            errorMessage = error.localizedDescription
        }
    }

    private func resetEditor() {
        withAnimation {
            selectedProject = nil
            selectedProjectID = nil
            projectTitle = "Untitled Project"
            deflectionInput = ""
            blows = []
            saveStatus = "Not saved"
        }
    }

    private func nextProjectTitle() -> String {
        let baseTitle = "DCP Project"
        let existingTitles = Set(projects.map(\.title))

        if !existingTitles.contains(baseTitle) {
            return baseTitle
        }

        var index = projects.count + 1
        while existingTitles.contains("\(baseTitle) \(index)") {
            index += 1
        }

        return "\(baseTitle) \(index)"
    }

    private func loadProject(_ project: DCPProject) {
        autosaveProject()

        withAnimation {
            selectedProject = project
            selectedProjectID = project.persistentModelID
            projectTitle = project.title
            unitSystem = DCPUnitSystem(rawValue: project.unitSystemRawValue) ?? .english
            deflectionInput = ""
            blows = (project.blows ?? [])
                .sorted { $0.position < $1.position }
                .map { DCPBlow(incrementalPenetration: $0.incrementalPenetration) }
            saveStatus = "Last saved \(project.updatedAt.formatted(date: .abbreviated, time: .shortened))"
            preferredCompactColumn = .detail
        }
    }

    private func autosaveProject() {
        guard selectedProject != nil else { return }

        let trimmedTitle = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmedTitle.isEmpty ? "Untitled Project" : trimmedTitle

        let project = selectedProject ?? DCPProject()
        if selectedProject == nil {
            modelContext.insert(project)
            selectedProject = project
        }

        project.title = title
        project.unitSystemRawValue = unitSystem.rawValue
        project.updatedAt = Date()

        replaceStoredBlows(for: project)

        do {
            try modelContext.save()
            saveStatus = "Last saved \(project.updatedAt.formatted(date: .abbreviated, time: .shortened))"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replaceStoredBlows(for project: DCPProject) {
        for storedBlow in project.blows ?? [] {
            modelContext.delete(storedBlow)
        }

        let storedBlows = blows.enumerated().map { index, blow in
            DCPProjectBlow(
                position: index,
                incrementalPenetration: blow.incrementalPenetration,
                project: project
            )
        }
        project.blows = storedBlows
    }

    private func deleteProjects(offsets: IndexSet) {
        for index in offsets {
            deleteProject(projects[index])
        }
    }

    private func deleteProject(_ project: DCPProject) {
        if project === selectedProject {
            resetEditor()
        }

        modelContext.delete(project)

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func csvExport(for project: DCPProject) -> CSVExport {
        let exportUnitSystem = DCPUnitSystem(rawValue: project.unitSystemRawValue) ?? .english
        let sourceBlows: [DCPBlow]

        if project === selectedProject {
            sourceBlows = blows
        } else {
            sourceBlows = (project.blows ?? [])
                .sorted { $0.position < $1.position }
                .map { DCPBlow(incrementalPenetration: $0.incrementalPenetration) }
        }

        let records = DCPRecord.records(from: sourceBlows)
        let csv = DCPProjectCSVBuilder.csv(
            project: project,
            unitSystem: exportUnitSystem,
            records: records
        )

        return CSVExport(
            filename: DCPProjectCSVBuilder.filename(for: project),
            content: csv
        )
    }
}

private struct CSVExport: Transferable {
    let filename: String
    let content: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            Data(export.content.utf8)
        }
        .suggestedFileName { export in
            export.filename
        }
    }
}

private enum DCPProjectCSVBuilder {
    static func filename(for project: DCPProject) -> String {
        let sanitizedTitle = project.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        return "\(sanitizedTitle.isEmpty ? "DCP-Project" : sanitizedTitle).csv"
    }

    static func csv(project: DCPProject, unitSystem: DCPUnitSystem, records: [DCPRecord]) -> String {
        var rows = [
            [
                "Project Name",
                "Created At",
                "Updated At",
                "Units",
                "Blow Number",
                "Incremental Penetration (\(unitSystem.lengthSymbol))",
                "Total Penetration (\(unitSystem.lengthSymbol))",
                "Penetration Index (\(unitSystem.penetrationIndexSymbol))",
                "CBR (%)"
            ]
        ]

        rows += records.map { record in
            [
                project.title,
                project.createdAt.ISO8601Format(),
                project.updatedAt.ISO8601Format(),
                unitSystem.name,
                "\(record.blowNumber)",
                decimalString(unitSystem.displayLength(record.incrementalPenetration)),
                decimalString(unitSystem.displayLength(record.totalPenetration)),
                decimalString(unitSystem.displayPenetrationIndex(record.penetrationIndex)),
                decimalString(record.cbr)
            ]
        }

        return rows
            .map { row in row.map(escapedField).joined(separator: ",") }
            .joined(separator: "\n")
    }

    nonisolated private static func decimalString(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...3)))
    }

    nonisolated private static func escapedField(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")

        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }

        return escaped
    }
}

private struct ProjectRow: View {
    let project: DCPProject
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "folder.fill" : "folder")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(project.title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Text(project.updatedAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\((project.blows ?? []).count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
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

    var pickerLabel: String {
        "\(name) (\(lengthSymbol))"
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
        "\(DCPNumberFormatter.measurement(displayLength(millimeters))) \(lengthSymbol)"
    }

    func formattedPenetrationIndex(_ millimetersPerBlow: Double) -> String {
        "\(DCPNumberFormatter.measurement(displayPenetrationIndex(millimetersPerBlow))) \(penetrationIndexSymbol)"
    }
}

private enum DCPNumberFormatter {
    static func measurement(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

private struct DCPBlow: Identifiable {
    let id = UUID()
    var incrementalPenetration: Double

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
        .modelContainer(ContentPreviewData.container)
}

@MainActor
private enum ContentPreviewData {
    static let container: ModelContainer = {
        let schema = Schema([
            DCPProject.self,
            DCPProjectBlow.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext

            let project = DCPProject(
                title: "Sample DCP Test",
                unitSystemRawValue: DCPUnitSystem.english.rawValue,
                blows: DCPBlow.sampleData.enumerated().map { index, blow in
                    DCPProjectBlow(position: index, incrementalPenetration: blow.incrementalPenetration)
                }
            )
            context.insert(project)

            return container
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }()
}
