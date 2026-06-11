import SwiftUI

/// Walks the user through Google's device-flow sign-in: the watch shows a
/// short code, you enter it at google.com/device on your phone, and the watch
/// picks up the grant automatically. Cancel-safe; nothing happens until the
/// code is approved on the other device.
struct GoogleSignInView: View {
    @Environment(\.dismiss) private var dismiss
    private var auth: GoogleAuth { .shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                switch auth.phase {
                case .signedOut, .requestingCode:
                    if let error = auth.lastError {
                        errorCard(error)
                    } else {
                        contactingCard
                    }
                case .awaitingApproval(let code, _):
                    approvalCard(code: code)
                case .signedIn:
                    successCard
                }
            }
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Google")
        .brandBackdrop()
        .onAppear {
            if !auth.isSignedIn { auth.startSignIn() }
        }
        .onDisappear {
            if !auth.isSignedIn { auth.cancelSignIn() }
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            guard signedIn else { return }
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                dismiss()
            }
        }
    }

    private var contactingCard: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.large)
            Text("Contacting Google…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    private func approvalCard(code: String) -> some View {
        VStack(spacing: 8) {
            Text("On your phone, open")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("google.com/device")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.blue)
            Text(code)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .kerning(1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.12))
                )
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for approval…")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Button(role: .cancel) {
                auth.cancelSignIn()
                dismiss()
            } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var successCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("Signed in")
                .font(.headline)
            Text("Playback now uses your YouTube account.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(.yellow)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button {
                auth.startSignIn()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}
