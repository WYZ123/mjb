import SwiftUI

struct WishCodeEntryView: View {
    @EnvironmentObject private var launchRouter: WishLaunchRouter
    @State private var code = ""
    @State private var error: String?
    @State private var submitting = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)
            Text("Enter a code")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(WishTheme.ink)
            TextField("Code", text: $code)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .focused($focused)
                .padding(14)
                .background(WishTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WishTheme.line, lineWidth: 1)
                }
            if let error {
                Text(error)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(WishTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            WishPrimaryButton(title: submitting ? "Checking…" : "Continue", enabled: !submitting && !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                Task { await submit() }
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WishTheme.background.ignoresSafeArea())
        .onAppear { focused = true }
    }

    private func submit() async {
        guard !submitting else { return }
        submitting = true
        error = await launchRouter.submitAccessCode(code)
        submitting = false
    }
}
