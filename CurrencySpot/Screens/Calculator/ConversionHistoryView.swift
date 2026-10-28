import SwiftUI

struct ConversionHistoryView: View {
    private enum Deletion {
        case all
        case selection
    }

    @Environment(ConversionHistoryViewModel.self) private var historyViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var editMode = EditMode.inactive
    @State private var selection = Set<ConversionRecord.ID>()
    @State private var pendingDeletion: Deletion?

    private var isConfirmingDeletion: Binding<Bool> {
        Binding { pendingDeletion != nil } set: { if !$0 { pendingDeletion = nil } }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(.calculatorHistoryTitle)
                .toolbarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .environment(\.editMode, $editMode)
        }
    }

    // MARK: - Views

    private var content: some View {
        List(selection: $selection.animation()) {
            ForEach(historyViewModel.sections) { section in
                Section(historyViewModel.title(for: section)) {
                    ForEach(section.records) { record in
                        row(for: record)
                    }
                }
            }
        }
        .overlay {
            if historyViewModel.isEmpty {
                ContentUnavailableView {
                    Label { Text(.calculatorHistoryEmptyTitle) } icon: { Image(systemName: "clock") }
                } description: {
                    Text(.calculatorHistoryEmptyMessage)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func row(for record: ConversionRecord) -> some View {
        Group {
            if editMode.isEditing {
                rowContent(for: record)
            } else {
                Button { choose(record) } label: { rowContent(for: record) }
                    .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .combine)
        .listRowInsets(EdgeInsets(top: Spacing.element, leading: 0, bottom: Spacing.element, trailing: 0))
        .alignmentGuide(.listRowSeparatorLeading) { _ in Spacing.cardPadding }
        .alignmentGuide(.listRowSeparatorTrailing) { $0.width - Spacing.cardPadding }
        .swipeActions {
            Button(role: .destructive) { historyViewModel.delete(ids: [record.id]) } label: {
                Label { Text(.calculatorHistoryDelete) } icon: { Image(systemName: "trash") }
            }
            .tint(.red)
            Button { copyConvertedAmount(of: record) } label: {
                Label { Text(.calculatorHistoryCopy) } icon: { Image(systemName: "doc.on.doc") }
            }
            .accessibilityLabel(Text(.calculatorHistoryCopyConverted))
        }
        .contextMenu {
            Button { UIPasteboard.general.string = historyViewModel.summary(for: record) } label: {
                Label { Text(record.calculation == nil ? .calculatorHistoryCopyAmount : .calculatorHistoryCopySteps) } icon: {
                    Image(systemName: "doc.on.doc")
                }
            }
            Button { copyConvertedAmount(of: record) } label: {
                Label { Text(.calculatorHistoryCopyConverted) } icon: { Image(systemName: "doc.on.doc") }
            }
        }
    }

    private func rowContent(for record: ConversionRecord) -> some View {
        VStack(alignment: .trailing, spacing: Spacing.hairline) {
            Text(verbatim: historyViewModel.summary(for: record))
                .font(.appSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
            Text(verbatim: historyViewModel.convertedAmount(for: record))
                .font(.appTitle3.monospacedDigit())
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, Spacing.cardPadding)
        .contentShape(.rect)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if historyViewModel.isEmpty == false {
            ToolbarItem(placement: .topBarLeading) {
                editToggle
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            trailingAction
                .confirmationDialog(
                    Text(.calculatorHistoryClearAllConfirm),
                    isPresented: isConfirmingDeletion,
                    titleVisibility: .hidden,
                    presenting: pendingDeletion
                ) { deletion in
                    Button(role: .destructive) { confirm(deletion) } label: { Text(confirmationTitle(for: deletion)) }
                } message: { deletion in
                    Text(confirmationMessage(for: deletion))
                }
        }
    }

    @ViewBuilder
    private var editToggle: some View {
        if editMode.isEditing {
            if #available(iOS 26.0, *) {
                Button(role: .confirm) { setEditing(false) }
            } else {
                Button(.currencyPickerDone) { setEditing(false) }
            }
        } else {
            Button(.calculatorHistoryEdit) { setEditing(true) }
        }
    }

    @ViewBuilder
    private var trailingAction: some View {
        if !editMode.isEditing {
            Button(.currencyPickerDone) { dismiss() }
        } else if selection.isEmpty {
            Button(.calculatorHistoryClearAll, role: .destructive) { pendingDeletion = .all }
                .tint(.red)
        } else {
            Button(.calculatorHistoryDeleteSelected(count: selection.count), role: .destructive) {
                pendingDeletion = .selection
            }
            .tint(.red)
        }
    }

    private func confirmationTitle(for deletion: Deletion) -> LocalizedStringResource {
        switch deletion {
        case .all: .calculatorHistoryClearAllConfirm
        case .selection: .calculatorHistoryDeleteSelectedConfirm(count: selection.count)
        }
    }

    private func confirmationMessage(for deletion: Deletion) -> LocalizedStringResource {
        switch deletion {
        case .all: .calculatorHistoryClearAllMessage
        case .selection: .calculatorHistoryDeleteSelectedMessage(count: selection.count)
        }
    }

    // MARK: - Actions

    private func setEditing(_ isEditing: Bool) {
        withAnimation {
            editMode = isEditing ? .active : .inactive
            if !isEditing { selection = [] }
        }
    }

    private func copyConvertedAmount(of record: ConversionRecord) {
        UIPasteboard.general.string = historyViewModel.convertedAmount(for: record)
    }

    private func choose(_ record: ConversionRecord) {
        historyViewModel.choose(record)
        dismiss()
    }

    private func confirm(_ deletion: Deletion) {
        switch deletion {
        case .all: historyViewModel.clearAll()
        case .selection: historyViewModel.delete(ids: selection)
        }
        withAnimation {
            selection = []
            if historyViewModel.isEmpty { editMode = .inactive }
        }
    }
}

#if DEBUG
#Preview {
    ConversionHistoryView()
        .withDependencyContainer(.preview())
}
#endif
