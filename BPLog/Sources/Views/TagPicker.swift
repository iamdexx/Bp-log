import SwiftUI

/// Tap-to-toggle chips. Two columns so the labels stay big.
struct TagPicker: View {
    @Binding var selected: Set<ReadingTag>

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(ReadingTag.allCases) { tag in
                let on = selected.contains(tag)
                Button {
                    if on { selected.remove(tag) } else { selected.insert(tag) }
                    if tag == .beforeMeds, !on { selected.remove(.afterMeds) }
                    if tag == .afterMeds, !on { selected.remove(.beforeMeds) }
                    if tag == .sitting, !on { selected.remove(.lyingDown) }
                    if tag == .lyingDown, !on { selected.remove(.sitting) }
                } label: {
                    Label(tag.title, systemImage: tag.symbol)
                        .font(.subheadline.weight(on ? .semibold : .regular))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(on ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? Color.accentColor : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
