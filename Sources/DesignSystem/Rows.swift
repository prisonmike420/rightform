import SwiftUI

// Rows of the grouped forms: a title over a detail line, a whole-row
// button, a size estimate and a checklist step.

/// A row's text: its title, and below it a quieter detail line.
struct TitleDetail: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

/// A whole-row button, as in System Settings: an icon, a title and a detail
/// line, and at the end what the row leads to — a chevron, an estimate.
struct ListRowButton<Icon: View, Accessory: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let accessory: () -> Accessory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
                TitleDetail(title: title, detail: detail)
                Spacer(minLength: 8)
                accessory()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The end of a row that opens something.
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .imageScale(.small)
            .foregroundStyle(.tertiary)
    }
}

/// The expected size on the right: the new size, and below it how much
/// smaller in green. "Already light" when it wouldn't get smaller.
struct SizeTag: View {
    let original: Int64
    let estimate: Int64

    /// What the tag shows, to tell whether two estimates look the same.
    static func label(original: Int64, estimate: Int64) -> String {
        let percent = estimate < original ? Int((Double(original - estimate) / Double(original) * 100).rounded()) : 0
        return "\(formatBytes(estimate)) \(percent)"
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("~\(formatBytes(estimate))")
                .font(.callout)
            if estimate < original {
                let percent = Int((Double(original - estimate) / Double(original) * 100).rounded())
                Text("−\(percent)%")
                    .font(.caption)
                    .foregroundStyle(Design.Status.success)
            } else {
                Text("Already light")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }
}

/// One step of a short checklist: a check when done, a spinner while it
/// runs, an empty circle while it waits; then its title and any detail.
struct ChecklistStep: View {
    enum Status { case done, active, pending }

    let title: String
    var detail: String?
    let state: Status

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Group {
                switch state {
                case .done:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Design.Status.success)
                case .active:
                    ProgressView().controlSize(.small)
                case .pending:
                    Image(systemName: "circle").foregroundStyle(.tertiary)
                }
            }
            .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .foregroundStyle(state == .pending ? .secondary : .primary)
                if let detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
