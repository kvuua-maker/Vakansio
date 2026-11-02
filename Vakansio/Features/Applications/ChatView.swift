import SwiftUI
import Foundation

struct ChatView: View {
    @EnvironmentObject private var app: AppState

    let applicationId: String
    let title: String
    let counterpartyName: String

    @State private var messages: [ChatMessage] = []
    @State private var text = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var lastError: String?
    @FocusState private var inputFocused: Bool

    private let pollInterval: UInt64 = 5_000_000_000
    private let bottomAnchor = "chat-bottom"

    var body: some View {
        ZStack {
            VK.screen.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        intro

                        if isLoading && messages.isEmpty {
                            ForEach(0..<4, id: \.self) { index in
                                messageSkeleton(isMine: index % 2 == 0)
                            }
                        } else if messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(messages) { message in
                                bubble(message)
                                    .id(message.id)
                            }
                        }

                        if let lastError, !messages.isEmpty {
                            Text(lastError)
                                .font(.system(size: 11))
                                .foregroundStyle(VK.danger)
                                .frame(maxWidth: .infinity)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchor)
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await loadMessages(silent: true)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomAnchor, anchor: .bottom)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            inputBar
        }
        .navigationTitle(counterpartyName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            await pollMessages()
        }
    }

    private var intro: some View {
        HStack(spacing: 8) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VK.brand)

            Text("Чат щодо «\(title)»")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VK.textSecondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VK.brand.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(VK.brand.opacity(0.6))

            Text("Повідомлень ще немає")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VK.textPrimary)

            Text("Напишіть перше повідомлення — відповідь з'явиться тут автоматично.")
                .font(.system(size: 12))
                .foregroundStyle(VK.textSecondary)
                .multilineTextAlignment(.center)

            if let lastError {
                Text(lastError)
                    .font(.system(size: 11))
                    .foregroundStyle(VK.danger)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await loadMessages() }
            } label: {
                Text("Оновити")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VK.brand)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(VK.brand.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func messageSkeleton(isMine: Bool) -> some View {
        HStack {
            if isMine { Spacer(minLength: 60) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
                SkeletonBlock(width: 180, height: 14)
                SkeletonBlock(width: 120, height: 14)
            }
            .padding(12)
            .background(VK.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !isMine { Spacer(minLength: 60) }
        }
        .shimmering()
    }

    private func bubble(_ message: ChatMessage) -> some View {
        let isMine = message.senderId == app.userId

        return HStack(alignment: .bottom, spacing: 8) {
            if isMine { Spacer(minLength: 52) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if !isMine {
                    Text(message.senderName.isEmpty ? counterpartyName : message.senderName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VK.textSecondary)
                }

                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(isMine ? Color.white : VK.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        isMine ? VK.brand : VK.card,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isMine ? Color.clear : VK.hairline, lineWidth: 1)
                    )
                    .fixedSize(horizontal: false, vertical: true)

                Text(timeText(message.createdAt))
                    .font(.system(size: 9))
                    .foregroundStyle(VK.textTertiary)
            }

            if !isMine { Spacer(minLength: 52) }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(VK.hairline)

            HStack(spacing: 8) {
                TextField("Повідомлення…", text: $text)
                    .font(.system(size: 15))
                    .foregroundStyle(VK.textPrimary)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { send() }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(VK.card, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(VK.hairline, lineWidth: 1)
                    )

                Button {
                    send()
                } label: {
                    ZStack {
                        Circle()
                            .fill(canSend ? VK.brand : VK.textTertiary.opacity(0.25))
                            .frame(width: 42, height: 42)

                        if isSending {
                            ProgressView()
                                .tint(Color.white)
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Надіслати")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .background(.regularMaterial)
    }

    private var canSend: Bool {
        !text.vkTrimmed.isEmpty && !isSending
    }

    private func pollMessages() async {
        await loadMessages()

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: pollInterval)
            if Task.isCancelled { return }
            await loadMessages(silent: true)
        }
    }

    @MainActor
    private func loadMessages(silent: Bool = false) async {
        if !silent { isLoading = true }

        do {
            let fetched = try await app.fetchMessages(applicationId: applicationId)
            messages = fetched
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        if !silent { isLoading = false }
    }

    private func send() {
        let value = text.vkTrimmed
        guard !value.isEmpty, !isSending else { return }

        isSending = true
        text = ""

        Task { @MainActor in
            do {
                let message = try await app.sendChatMessage(applicationId: applicationId, text: value)
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
                lastError = nil
            } catch {
                lastError = error.localizedDescription
                text = value
            }
            isSending = false
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
