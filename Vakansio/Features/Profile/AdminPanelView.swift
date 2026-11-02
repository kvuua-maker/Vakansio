import SwiftUI
import Foundation

struct AdminPanelView: View {
    @EnvironmentObject private var app: AppState

    @State private var overview: AdminOverview?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var processingID: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if !app.isAdmin {
                    accessDenied
                } else if let overview {
                    usageCard(overview.usage)
                    countsGrid(overview.counts)
                    pendingJobsCard(overview.pendingJobs)
                    pendingCard(overview.pending)
                    monthNote(overview.usage)
                } else if isLoading {
                    skeleton
                } else {
                    errorCard
                }

                Button {
                    Task { await load() }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Оновити")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(VK.brand)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(VK.brand.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(VK.screen)
        .navigationTitle("Адмін-панель")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
    }

    private func usageCard(_ usage: AdminUsage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VK.brand)

                    Text("Overit API")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VK.textPrimary)

                    Spacer()

                    Text(usage.month)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VK.textTertiary)
                }

                HStack(spacing: 10) {
                    statTile(
                        title: "Безкоштовні",
                        value: "\(usage.freeUsed) з \(usage.freeLimit)",
                        tint: VK.brand
                    )

                    statTile(
                        title: "Платні",
                        value: "\(usage.paidBalance) залишилось",
                        tint: VK.success
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(
                        value: Double(min(usage.freeUsed, usage.freeLimit)),
                        total: Double(max(usage.freeLimit, 1))
                    )
                    .tint(VK.brand)

                    Text("Використано безкоштовних перевірок цього місяця")
                        .font(.system(size: 10))
                        .foregroundStyle(VK.textTertiary)
                }
            }
        .vkCard()
    }

    private func statTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VK.textSecondary)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func countsGrid(_ counts: AdminCounts) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Платформа")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(VK.textPrimary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                countCell(title: "Користувачі", value: counts.users, icon: "person.2.fill", tint: VK.brand)
                countCell(title: "Вакансії", value: counts.jobs, icon: "briefcase.fill", tint: VK.success)
                countCell(title: "Відгуки", value: counts.applications, icon: "paperplane.fill", tint: VK.warning)
                countCell(title: "На перевірці", value: counts.pendingVerifications, icon: "clock.badge.exclamationmark", tint: VK.danger)
                countCell(title: "Ручна модерація", value: counts.pendingJobs, icon: "person.crop.circle.badge.questionmark", tint: VK.warning)
            }
        }
    }

    private func countCell(title: String, value: Int, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(VK.textPrimary)

                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(VK.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(VK.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
    }

    private func pendingJobsCard(_ jobs: [AdminPendingJob]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Вакансії на ручній перевірці")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                Text("\(jobs.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VK.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(VK.warning.opacity(0.12), in: Capsule())
            }

            if jobs.isEmpty {
                Text("Немає вакансій, які AI передав на ручну перевірку.")
                    .font(.system(size: 12))
                    .foregroundStyle(VK.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(jobs) { job in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(job.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VK.textPrimary)
                            .lineLimit(2)

                        Text("\(job.companyName) · \(job.city)")
                            .font(.system(size: 11))
                            .foregroundStyle(VK.textSecondary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Button("Схвалити") {
                                Task { await moderateJob(job, approve: true) }
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(VK.success, in: Capsule())
                            .buttonStyle(.plain)
                            .disabled(processingID != nil)

                            Button("Відхилити") {
                                Task { await moderateJob(job, approve: false) }
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VK.danger)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(VK.danger.opacity(0.1), in: Capsule())
                            .buttonStyle(.plain)
                            .disabled(processingID != nil)

                            if processingID == job.id {
                                ProgressView().scaleEffect(0.7)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VK.screen, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .vkCard()
    }

    private func pendingCard(_ pending: [AdminPendingVerification]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Ручна перевірка")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                Text("\(pending.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VK.danger)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(VK.danger.opacity(0.1), in: Capsule())
            }

            if pending.isEmpty {
                Text("Немає заявок, що очікують ручної перевірки.")
                    .font(.system(size: 12))
                    .foregroundStyle(VK.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(pending) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ЄДРПОУ \(item.edrpou)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VK.textPrimary)

                        Text(item.note.isEmpty ? "Очікує рішення адміністратора" : item.note)
                            .font(.system(size: 11))
                            .foregroundStyle(VK.textSecondary)
                            .lineLimit(2)

                        Text(dateText(item.createdAt))
                            .font(.system(size: 10))
                            .foregroundStyle(VK.textTertiary)

                        HStack(spacing: 8) {
                            Button("Схвалити") {
                                Task { await moderateVerification(item, approve: true) }
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(VK.success, in: Capsule())
                            .buttonStyle(.plain)
                            .disabled(processingID != nil)

                            Button("Відхилити") {
                                Task { await moderateVerification(item, approve: false) }
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VK.danger)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(VK.danger.opacity(0.1), in: Capsule())
                            .buttonStyle(.plain)
                            .disabled(processingID != nil)

                            if processingID == item.id {
                                ProgressView().scaleEffect(0.7)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VK.screen, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if item.id != pending.last?.id {
                        Divider().overlay(VK.hairline)
                    }
                }
            }
        }
        .vkCard()
    }

    private func monthNote(_ usage: AdminUsage) -> some View {
        Text("Ліміт: \(usage.freeLimit) безкоштовних перевірок на місяць. Після вичерпання — автоматичне списання 499 ₴ через Stripe та +100 платних перевірок.")
            .font(.system(size: 11))
            .foregroundStyle(VK.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
    }

    private var accessDenied: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(VK.textTertiary)

            Text("Доступ лише для адміністратора")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VK.textPrimary)

            Text("Увійдіть з email kvuua@yahoo.com, щоб побачити панель.")
                .font(.system(size: 12))
                .foregroundStyle(VK.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var skeleton: some View {
        VStack(spacing: 12) {
            SkeletonBlock(width: nil, height: 130)
            SkeletonBlock(width: nil, height: 110)
            SkeletonBlock(width: nil, height: 100)
        }
        .shimmering()
    }

    private var errorCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(VK.warning)

            Text(errorMessage ?? "Не вдалося завантажити статистику")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(VK.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func moderateJob(_ job: AdminPendingJob, approve: Bool) async {
        guard processingID == nil else { return }
        processingID = job.id
        let success = await app.moderateAdminJob(id: job.id, approve: approve)
        processingID = nil
        if success { await load() }
    }

    private func moderateVerification(_ request: AdminPendingVerification, approve: Bool) async {
        guard processingID == nil else { return }
        processingID = request.id
        let success = await app.moderateAdminVerification(id: request.id, approve: approve)
        processingID = nil
        if success { await load() }
    }

    private func load() async {
        guard app.isAdmin else {
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            overview = try await app.fetchAdminOverview()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }
}
