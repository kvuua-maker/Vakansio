import SwiftUI
import Foundation

struct HelpSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    private let faq: [(question: String, answer: String)] = [
        (
            "Як надіслати відгук на вакансію?",
            "Відкрийте вакансію у стрічці або пошуку та натисніть «Відгукнутися» внизу екрана. Додайте супровідний лист — і відгук одразу побачить роботодавець."
        ),
        (
            "Як працює бейдж «Перевірено»?",
            "Ми перевіряємо юридичну особу, домен сайту та історію вакансій. Бейдж означає, що компанія пройшла базову перевірку Vakansio."
        ),
        (
            "Чи можна змінити роль?",
            "Так, роль змінюється у профілі в будь-який момент. У режимі «Наймаю» з'являються вакансії, статистика та тарифи."
        ),
        (
            "Що робити, якщо роботодавець просить передоплату?",
            "Не платіть. Напишіть нам через кнопку нижче — ми перевіримо вакансію та заблокуємо її за потреби."
        )
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(faq.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(faq[index].question)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(VK.textPrimary)

                            Text(faq[index].answer)
                                .font(.system(size: 13))
                                .foregroundStyle(VK.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(VK.card)
                    }
                } header: {
                    Text("Часті питання")
                        .foregroundStyle(VK.textSecondary)
                }

                Section {
                    Button {
                        app.showToast("Підтримка відповість протягом 24 годин", icon: "envelope.fill", style: .info)
                    } label: {
                        Label("Написати в підтримку", systemImage: "envelope.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VK.brand)
                    }
                    .listRowBackground(VK.card)
                } footer: {
                    Text("Vakansio · support@vakansio.app")
                        .foregroundStyle(VK.textTertiary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(VK.screen)
            .navigationTitle("Допомога")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                        .foregroundStyle(VK.brand)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
