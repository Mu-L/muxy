import SwiftUI

struct BrowserSuggestionList: View {
    let model: BrowserSuggestionModel
    let onSelect: (BrowserHistoryEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.suggestions.enumerated()), id: \.element.id) { index, entry in
                row(for: entry, isSelected: index == model.selectedIndex)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(entry) }
                    .onHover { hovering in
                        if hovering { model.selectedIndex = index }
                    }
            }
        }
        .padding(.vertical, UIMetrics.spacing1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MuxyTheme.bg)
        .background(MuxyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: UIMetrics.radiusMD))
        .overlay(
            RoundedRectangle(cornerRadius: UIMetrics.radiusMD)
                .strokeBorder(MuxyTheme.border, lineWidth: 1)
        )
    }

    private func row(for entry: BrowserHistoryEntry, isSelected: Bool) -> some View {
        HStack(spacing: UIMetrics.spacing3) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: UIMetrics.fontCaption))
                .foregroundStyle(MuxyTheme.fgDim)
                .frame(width: UIMetrics.iconMD)

            VStack(alignment: .leading, spacing: 0) {
                if let title = entry.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: UIMetrics.fontBody))
                        .foregroundStyle(MuxyTheme.fg)
                        .lineLimit(1)
                }
                Text(entry.url)
                    .font(.system(size: UIMetrics.fontCaption))
                    .foregroundStyle(MuxyTheme.fgMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, UIMetrics.spacing4)
        .padding(.vertical, UIMetrics.spacing2)
        .background(isSelected ? MuxyTheme.hover : Color.clear)
    }
}
