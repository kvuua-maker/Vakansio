import SwiftUI
import Foundation

struct SearchView: View {
    @EnvironmentObject private var app: AppState

    @State private var path = NavigationPath()
    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var selectedCity: String? = nil
    @State private var selectedCategory: String? = nil
    @State private var minSalary: Double = 0
    @State private var remoteOnly = false
    @State private var officeOnly = false
    @State private var showFilters = false
    @State private var results: [Vacancy] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var page = 1
    @State private var total = 0
    @State private var hasMore = false
    @State private var parsedQuery: JobSearchParsed?
    @State private var searchTask: Task<Void, Never>?
    @State private var searchGeneration = 0
    @State private var filterDebounce: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    private var activeFilterCount: Int {
        var count = 0
        if selectedCity != nil { count += 1 }
        if selectedCategory != nil { count += 1 }
        if minSalary > 0 { count += 1 }
        if remoteOnly { count += 1 }
        if officeOnly { count += 1 }
        return count
    }

    private var maxSalary: Double {
        let maximum = app.jobs.map { $0.salaryMax }.max() ?? 0
        return Double(max(50000, maximum))
    }

    private var salaryLabel: String {
        minSalary <= 0 ? "Будь-яка" : "від \(vkFormatMoney(Int(minSalary))) ₴"
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                VK.screen.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        searchRow
                        searchHint
                        filterStrip
                        if !app.jobs.isEmpty {
                            salaryCard
                        }
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
                await app.loadRecommendedJobs()
            }
            if !isSearching && results.isEmpty {
                performSearch(reset: true)
            }
        }
        .onChange(of: query) { _, newValue in
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                debouncedQuery = newValue
                performSearch(reset: true)
            }
        }
        .onChange(of: selectedCity) { _, _ in scheduleFilterSearch() }
        .onChange(of: selectedCategory) { _, _ in scheduleFilterSearch() }
        .onChange(of: remoteOnly) { _, _ in scheduleFilterSearch() }
        .onChange(of: officeOnly) { _, _ in scheduleFilterSearch() }
        .onChange(of: minSalary) { _, _ in scheduleFilterSearch() }
        .onChange(of: maxSalary) { _, newValue in
            if minSalary > newValue {
                minSalary = newValue
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
        HStack(alignment: .top, spacing: 10) {
            SearchField(text: $query, focus: $isSearchFocused) {
                isSearchFocused = false
                debouncedQuery = query
                performSearch(reset: true)
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

                FilterChip(title: "Віддалено", icon: "wifi", isSelected: remoteOnly) {
                    remoteOnly.toggle()
                }

                FilterChip(title: "Офіс", icon: "building.2", isSelected: officeOnly) {
                    officeOnly.toggle()
                }

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

    private var salaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Зарплата", systemImage: "banknote")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VK.textSecondary)

                Spacer()

                Text(salaryLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VK.brand)
            }

            Slider(value: $minSalary, in: 0...maxSalary, step: 5000)
                .tint(VK.brand)

            HStack {
                Text("0 ₴")
                    .font(.system(size: 10))
                    .foregroundStyle(VK.textTertiary)
                Spacer()
                Text("\(vkFormatMoney(Int(maxSalary))) ₴")
                    .font(.system(size: 10))
                    .foregroundStyle(VK.textTertiary)
            }
        }
        .padding(12)
        .background(VK.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(VK.hairline, lineWidth: 1)
        )
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
                        minSalary = 0
                        remoteOnly = false
                        officeOnly = false
                    }
                    scheduleFilterSearch()
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
        if isSearching && results.isEmpty {
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonVacancyCard()
                }
            }
        } else if let searchError, results.isEmpty {
            EmptyStateView(
                icon: "wifi.exclamationmark",
                title: "Не вдалося знайти",
                message: searchError,
                actionTitle: "Спробувати ще",
                action: {
                    performSearch(reset: true)
                }
            )
            .vkCard()
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text("Результати")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VK.textPrimary)

                Spacer()

                Text("\(total) вакансій")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VK.textSecondary)
            }
            .padding(.top, 2)

            if let parsedQuery, !parsedQuery.position.isEmpty || !parsedQuery.city.isEmpty || !parsedQuery.experience.isEmpty {
                parsedChip(parsedQuery)
            }

            if let searchError, !results.isEmpty {
                Text(searchError)
                    .font(.system(size: 11))
                    .foregroundStyle(VK.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if results.isEmpty {
                EmptyStateView(
                    icon: "text.magnifyingglass",
                    title: "Нічого не знайдено",
                    message: "Спробуйте іншу фразу або скиньте фільтри.",
                    actionTitle: "Скинути фільтри",
                    action: {
                        resetSearch()
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

                    if hasMore {
                        Button {
                            performSearch(reset: false)
                        } label: {
                            HStack(spacing: 7) {
                                if isSearching {
                                    ProgressView().tint(VK.brand)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                }
                                Text(isSearching ? "Завантажуємо…" : "Показати ще")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(VK.brand)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(VK.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSearching)
                    }
                }
            }
        }
    }

    private var searchHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💡 Пишіть цілою фразою — AI розбере посаду, місто та досвід")
                .font(.system(size: 11))
                .foregroundStyle(VK.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    exampleChip("Водій з авто")
                    exampleChip("Продавець")
                    exampleChip("Медсестра у Дніпрі")
                }
            }
        }
    }

    private func exampleChip(_ value: String) -> some View {
        Button {
            query = value
            debouncedQuery = value
            isSearchFocused = false
            performSearch(reset: true)
        } label: {
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VK.brand)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(VK.brand.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func parsedChip(_ parsed: JobSearchParsed) -> some View {
        var parts: [String] = []
        if !parsed.position.isEmpty { parts.append(parsed.position) }
        if !parsed.city.isEmpty { parts.append(parsed.city) }
        if !parsed.experience.isEmpty { parts.append(parsed.experience) }
        if !parsed.keywords.isEmpty { parts.append(parsed.keywords.prefix(3).joined(separator: ", ")) }

        return HStack(spacing: 7) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VK.brand)

            Text("AI зрозумів: \(parts.joined(separator: " · "))")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VK.textSecondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(VK.brand.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func performSearch(reset: Bool) {
        searchGeneration += 1
        let generation = searchGeneration
        searchTask?.cancel()

        if reset {
            isSearching = true
            searchError = nil
        }

        let requestPage = reset ? 1 : page + 1
        let requestQuery = debouncedQuery
        let requestCity = selectedCity
        let requestCategory = selectedCategory
        let requestSalary = Int(minSalary)
        let requestRemote = remoteOnly
        let requestOffice = officeOnly

        searchTask = Task { @MainActor in
            do {
                let response = try await app.searchJobs(
                    query: requestQuery,
                    city: requestCity,
                    category: requestCategory,
                    minSalary: requestSalary,
                    remote: requestRemote,
                    office: requestOffice,
                    page: requestPage
                )
                guard generation == searchGeneration else { return }

                if reset {
                    results = response.items
                    page = 1
                } else {
                    results.append(contentsOf: response.items)
                    page = response.page
                }
                total = response.total
                hasMore = response.hasMore
                parsedQuery = response.parsed
                searchError = nil
            } catch {
                guard generation == searchGeneration else { return }
                searchError = error.localizedDescription
                if reset {
                    results = []
                    total = 0
                    hasMore = false
                    parsedQuery = nil
                }
            }

            if generation == searchGeneration {
                isSearching = false
            }
        }
    }

    private func scheduleFilterSearch() {
        filterDebounce?.cancel()
        filterDebounce = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            performSearch(reset: true)
        }
    }

    private func resetSearch() {
        query = ""
        debouncedQuery = ""
        selectedCity = nil
        selectedCategory = nil
        minSalary = 0
        remoteOnly = false
        officeOnly = false
        performSearch(reset: true)
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
