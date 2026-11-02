import SwiftUI
import Foundation

struct SearchView: View {
    @EnvironmentObject private var app: AppState

    @State private var path = NavigationPath()
    @State private var query = ""
    @State private var selectedCity: String? = nil
    @State private var selectedCategory: String? = nil
    @State private var showFilters = false
    @FocusState private var isSearchFocused: Bool

    private var activeFilterCount: Int {
        var count = 0
        if selectedCity != nil { count += 1 }
        if selectedCategory != nil { count += 1 }
        return count
    }

    private var results: [Vacancy] {
        let text = query.vkTrimmed.lowercased()

        return app.jobs.filter { vacancy in
            let matchesQuery = text.isEmpty
                || vacancy.title.lowercased().contains(text)
                || vacancy.company.name.lowercased().contains(text)
                || vacancy.city.lowercased().contains(text)
                || vacancy.category.lowercased().contains(text)

            let matchesCity = selectedCity == nil
                || vacancy.city == selectedCity
                || (selectedCity == "Віддалено" && vacancy.isRemote)

            let matchesCategory = selectedCategory == nil || vacancy.category == selectedCategory

            return matchesQuery && matchesCity && matchesCategory
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                VK.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        searchRow
                        filterStrip
                        activeFilters
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        isSearchFocused = false
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VK.brand)
                }
            }
            .navigationDestination(for: Vacancy.self) { vacancy in
                VacancyDetailView(vacancy: vacancy)
            }
        }
        .sheet(isPresented: $showFilters) {
            SearchFiltersSheet(selectedCity: $selectedCity, selectedCategory: $selectedCategory)
                .presentationDetents([.large])
        }
        .task {
            if app.jobs.isEmpty {
                await app.loadJobs()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Пошук")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(VK.textPrimary)

            Text("Знайдіть вакансію за містом, категорією або назвою")
                .font(.system(size: 13))
                .foregroundStyle(VK.textSecondary)
        }
        .padding(.top, 4)
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            SearchField(text: $query, focus: $isSearchFocused) {
                isSearchFocused = false
            }

            Button {
                isSearchFocused = false
                showFilters = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(activeFilterCount > 0 ? VK.brand : VK.card)

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(VK.hairline, lineWidth: 1)

                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(activeFilterCount > 0 ? Color.white : VK.textPrimary)
                }
                .frame(width: 48, height: 48)
                .overlay(alignment: .topTrailing) {
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 18, height: 18)
                            .background(VK.danger, in: Circle())
                            .overlay(Circle().strokeBorder(VK.screen, lineWidth: 2))
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Фільтри")
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                cityMenu

                ForEach(FilterOptions.categories, id: \.self) { category in
                    FilterChip(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var cityMenu: some View {
        Menu {
            Button("Усі міста") { selectedCity = nil }
            ForEach(FilterOptions.cities, id: \.self) { city in
                Button {
                    selectedCity = city
                } label: {
                    if selectedCity == city {
                        Label(city, systemImage: "checkmark")
                    } else {
                        Text(city)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 11, weight: .semibold))

                Text(selectedCity ?? "Місто")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(selectedCity == nil ? VK.textSecondary : Color.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(selectedCity == nil ? VK.card : VK.brand, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(selectedCity == nil ? VK.hairline : Color.clear, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var activeFilters: some View {
        if activeFilterCount > 0 {
            HStack(spacing: 8) {
                Text("Активних фільтрів: \(activeFilterCount)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VK.textSecondary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCity = nil
                        selectedCategory = nil
                    }
                } label: {
                    Text("Скинути")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VK.brand)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if app.isLoadingJobs && app.jobs.isEmpty {
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonVacancyCard()
                }
            }
        } else if app.jobs.isEmpty {
            EmptyStateView(
                icon: "wifi.exclamationmark",
                title: "Немає даних",
                message: app.lastErrorMessage ?? "Вакансії ще не завантажені.",
                actionTitle: "Спробувати ще",
                action: {
                    Task { await app.loadJobs() }
                }
            )
            .vkCard()
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text("Результати")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                Text("\(results.count) вакансій")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VK.textSecondary)
            }
            .padding(.top, 2)

            if results.isEmpty {
                EmptyStateView(
                    icon: "text.magnifyingglass",
                    title: "Нічого не знайдено",
                    message: "Спробуйте змінити запит або скинути фільтри.",
                    actionTitle: "Скинути фільтри",
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            query = ""
                            selectedCity = nil
                            selectedCategory = nil
                        }
                    }
                )
                .vkCard()
            } else {
                VStack(spacing: 12) {
                    ForEach(results) { vacancy in
                        VacancyCard(
                            vacancy: vacancy,
                            isSaved: app.isSaved(vacancy),
                            onOpen: { path.append(vacancy) },
                            onToggleSave: { app.toggleSaved(vacancy) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Filters

struct SearchFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedCity: String?
    @Binding var selectedCategory: String?

    @State private var city: String? = nil
    @State private var category: String? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Місто")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(VK.textPrimary)

                        LazyVGrid(columns: columns, spacing: 8) {
                            choiceButton("Будь-яке", isSelected: city == nil) {
                                city = nil
                            }

                            ForEach(FilterOptions.cities, id: \.self) { item in
                                choiceButton(item, isSelected: city == item) {
                                    city = item
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Категорія")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(VK.textPrimary)

                        LazyVGrid(columns: columns, spacing: 8) {
                            choiceButton("Будь-яка", isSelected: category == nil) {
                                category = nil
                            }

                            ForEach(FilterOptions.categories, id: \.self) { item in
                                choiceButton(item, isSelected: category == item) {
                                    category = item
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(VK.screen)
            .navigationTitle("Фільтри")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скинути") {
                        city = nil
                        category = nil
                    }
                    .foregroundStyle(VK.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        selectedCity = city
                        selectedCategory = category
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VK.brand)
                }
            }
        }
        .onAppear {
            city = selectedCity
            category = selectedCategory
        }
    }

    private func choiceButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : VK.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(isSelected ? VK.brand : VK.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : VK.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
