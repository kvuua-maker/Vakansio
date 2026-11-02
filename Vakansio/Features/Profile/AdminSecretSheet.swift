import SwiftUI

struct AdminSecretSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var secret = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                VK.screen.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(VK.danger.opacity(0.1))
                                .frame(width: 42, height: 42)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(VK.danger)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Адмін-доступ")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(VK.textPrimary)
                            Text("Введіть секретний код власника")
                                .font(.system(size: 11))
                                .foregroundStyle(VK.textSecondary)
                        }
                    }

                    SecureField("Секретний код", text: $secret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 15))
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .background(VK.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(VK.hairline, lineWidth: 1)
                        )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(VK.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Код зберігається лише на сервері. Після активації в Профілі з'явиться «Адмін-панель».")
                        .font(.system(size: 11))
                        .foregroundStyle(VK.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    PrimaryButton(
                        title: "Активувати",
                        icon: "lock.open.fill",
                        isLoading: isSaving,
                        isEnabled: !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        save()
                    }

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Адмін-код")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрити") { dismiss() }
                        .foregroundStyle(VK.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            let success = await app.claimAdmin(secret: secret)
            isSaving = false

            if success {
                dismiss()
            } else {
                errorMessage = "Невірний адмін-код."
            }
        }
    }
}
