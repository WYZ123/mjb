import SwiftUI

struct WishPageHeader: View {
    var eyebrow: String?
    var tab: WishAppTab?
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(WishTheme.seal)
            }
            Text(title)
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(WishTheme.ink)
            Text(detail)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(WishTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

struct WishSectionHeading: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(WishTheme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(WishTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WishSurfaceCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WishTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(WishTheme.line, lineWidth: 1)
            }
    }
}

struct WishSealMark: View {
    var size: CGFloat = 48

    var body: some View {
        Text("W")
            .font(.custom("Georgia-Bold", size: size * 0.46))
            .foregroundStyle(WishTheme.onSeal)
            .frame(width: size, height: size)
            .background(WishTheme.seal, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .rotationEffect(.degrees(-6))
            .accessibilityHidden(true)
    }
}

struct WishProgressTrack: View {
    var progress: Double
    var tint: Color = WishTheme.seal
    var height: CGFloat = 10

    @State private var shown = 0.0

    var body: some View {
        GeometryReader { geo in
            let width = max(0, min(1, shown)) * geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WishTheme.track)
                if width > 0.5 {
                    Capsule()
                        .fill(tint)
                        .frame(width: width)
                }
            }
        }
        .frame(height: height)
        .accessibilityLabel("Progress")
        .accessibilityValue(WishFormat.percent(progress))
        .onAppear {
            withAnimation(.spring(duration: 0.5)) {
                shown = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(duration: 0.45)) {
                shown = newValue
            }
        }
    }
}

struct WishStatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(WishTheme.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(WishTheme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(WishTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WishTheme.line, lineWidth: 1)
        }
    }
}

struct WishPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(WishTheme.onSeal.opacity(enabled ? 1 : 0.72))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    WishTheme.seal.opacity(enabled ? 1 : 0.38),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .buttonStyle(WishPressableStyle())
        .disabled(!enabled)
    }
}

struct WishPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.84 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct WishReadableColumn: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
    }
}

struct WishTabScreen<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    content()
                }
                .modifier(WishReadableColumn())
            }
            .scrollDismissesKeyboard(.interactively)
            .background(WishTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
