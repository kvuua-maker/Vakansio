import Foundation

// MARK: - Configuration

enum APIConfig {
    static let fallbackBaseURL = "http://178.105.32.46:8090"

    static var baseURLString: String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "VakansioAPIBaseURL") as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return fallbackBaseURL
    }

    static var internalToken: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "VakansioInternalToken") as? String else {
            return ""
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case missingConfiguration(String)
    case invalidResponse
    case unauthorized
    case notFound
    case server(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let message):
            return message
        case .invalidResponse:
            return "Сервер повернув некоректну відповідь"
        case .unauthorized:
            return "Немає доступу до API. Перевірте внутрішній токен."
        case .notFound:
            return "Дані не знайдено"
        case .server(let message):
            return message
        case .transport(let message):
            return "Немає зв'язку з сервером: \(message)"
        }
    }
}

// MARK: - Client

struct APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 40
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration)
    }

    // MARK: Public endpoints

    func fetchJobs() async throws -> [Vacancy] {
        let dtos: [JobDTO] = try await get(path: "/v1/jobs")
        return dtos.map { $0.toModel() }
    }

    func fetchRecommendedJobs(userId: String) async throws -> [Vacancy] {
        let dtos: [JobDTO] = try await get(
            path: "/v1/jobs/recommended",
            query: [URLQueryItem(name: "userId", value: userId)]
        )
        return dtos.map { $0.toModel() }
    }

    func generateResume(userId: String, answers: AIResumeAnswers) async throws -> GeneratedResume {
        let body = GenerateResumeRequest(
            userId: userId,
            answers: ResumeAnswersPayload(
                fullName: answers.fullName,
                position: answers.position,
                city: answers.city,
                experience: answers.experience,
                skills: answers.skills
            )
        )
        let dto: GeneratedResumeDTO = try await post(path: "/v1/resume/generate", body: body)
        return dto.toModel()
    }

    func fetchMessages(applicationId: String, userId: String) async throws -> [ChatMessage] {
        let dtos: [ChatMessageDTO] = try await get(
            path: "/v1/messages",
            query: [
                URLQueryItem(name: "applicationId", value: applicationId),
                URLQueryItem(name: "userId", value: userId)
            ]
        )
        return dtos.map { $0.toModel() }
    }

    func sendMessage(applicationId: String, userId: String, text: String) async throws -> ChatMessage {
        let dto: ChatMessageDTO = try await post(
            path: "/v1/messages",
            body: ChatMessageRequest(applicationId: applicationId, userId: userId, text: text)
        )
        return dto.toModel()
    }

    func registerDevice(userId: String, token: String) async throws {
        let _: OKResponse = try await post(
            path: "/v1/devices",
            body: DeviceRequest(userId: userId, token: token, platform: "ios")
        )
    }

    func verifyCompany(userId: String, edrpou: String) async throws -> CompanyVerificationResult {
        let dto: CompanyVerificationDTO = try await post(
            path: "/v1/company/verify",
            body: VerifyCompanyRequest(userId: userId, edrpou: edrpou)
        )
        return dto.toModel()
    }

    func fetchAdminOverview(userId: String) async throws -> AdminOverview {
        let dto: AdminOverviewDTO = try await get(
            path: "/v1/admin/overview",
            query: [URLQueryItem(name: "userId", value: userId)]
        )
        return dto.toModel()
    }

    func fetchEmployerJobs(employerId: String) async throws -> [Vacancy] {
        let dtos: [JobDTO] = try await get(
            path: "/v1/jobs/employer",
            query: [URLQueryItem(name: "employerId", value: employerId)]
        )
        return dtos.map { $0.toModel() }
    }

    func createJob(_ body: CreateJobRequest) async throws -> Vacancy {
        let dto: JobDTO = try await post(path: "/v1/jobs", body: body)
        return dto.toModel()
    }

    func fetchMyApplications(userId: String) async throws -> [Application] {
        let dtos: [ApplicationDTO] = try await get(
            path: "/v1/applications/my",
            query: [URLQueryItem(name: "userId", value: userId)]
        )
        return dtos.map { $0.toModel() }
    }

    func fetchEmployerApplications(employerId: String) async throws -> [Application] {
        let dtos: [ApplicationDTO] = try await get(
            path: "/v1/applications/employer",
            query: [URLQueryItem(name: "employerId", value: employerId)]
        )
        return dtos.map { $0.toModel() }
    }

    func createApplication(_ body: CreateApplicationRequest) async throws -> Application {
        let dto: ApplicationDTO = try await post(path: "/v1/applications", body: body)
        return dto.toModel()
    }

    func markApplicationsViewed(employerId: String) async throws {
        let _: MarkViewedResponse = try await post(
            path: "/v1/applications/mark-viewed",
            body: MarkViewedRequest(employerId: employerId)
        )
    }

    func updateApplicationStatus(
        applicationId: String,
        employerId: String,
        status: ApplicationStatus
    ) async throws -> Application {
        let dto: ApplicationDTO = try await post(
            path: "/v1/applications/\(applicationId)/status",
            body: StatusUpdateRequest(employerId: employerId, status: status.rawValue)
        )
        return dto.toModel()
    }

    func fetchProfile(userId: String) async throws -> UserProfile? {
        do {
            let dto: ProfileDTO = try await get(
                path: "/v1/profile",
                query: [URLQueryItem(name: "userId", value: userId)]
            )
            return dto.toModel()
        } catch APIError.notFound {
            return nil
        }
    }

    func saveProfile(_ body: UpdateProfileRequest) async throws -> UserProfile {
        let dto: ProfileDTO = try await post(path: "/v1/profile", body: body)
        return dto.toModel()
    }

    func deleteProfile(userId: String) async throws {
        let _: DeleteResponse = try await delete(
            path: "/v1/profile",
            query: [URLQueryItem(name: "userId", value: userId)]
        )
    }

    // MARK: Request building

    private func makeRequest(
        path: String,
        method: String,
        query: [URLQueryItem],
        body: Data?
    ) throws -> URLRequest {
        let token = APIConfig.internalToken
        guard !token.isEmpty else {
            throw APIError.missingConfiguration(
                "Не налаштовано внутрішній токен API (VakansioInternalToken)."
            )
        }

        guard var components = URLComponents(string: APIConfig.baseURLString) else {
            throw APIError.missingConfiguration("Некоректна адреса API.")
        }

        components.path = path
        components.queryItems = query.isEmpty ? nil : query

        guard let url = components.url else {
            throw APIError.missingConfiguration("Не вдалося побудувати URL запиту.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 25
        request.setValue(token, forHTTPHeaderField: "x-internal-token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }

    private func get<T: Decodable>(path: String, query: [URLQueryItem] = []) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", query: query, body: nil)
        return try await execute(request)
    }

    private func post<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        let data = try encoder.encode(body)
        let request = try makeRequest(path: path, method: "POST", query: [], body: data)
        return try await execute(request)
    }

    private func delete<T: Decodable>(path: String, query: [URLQueryItem]) async throws -> T {
        let request = try makeRequest(path: path, method: "DELETE", query: query, body: nil)
        return try await execute(request)
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            break
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            let message = (try? decoder.decode(ServerError.self, from: data))?.error
            throw APIError.server(message ?? "Помилка сервера (\(http.statusCode))")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.server("Не вдалося прочитати відповідь сервера.")
        }
    }
}

// MARK: - Requests

struct CreateJobRequest: Encodable {
    let employerId: String
    let title: String
    let companyName: String
    let description: String
    let salaryMin: Int
    let salaryMax: Int
    let city: String
    let category: String
    let requirements: [String]
    let benefits: [String]
    let contactEmail: String
}

struct CreateApplicationRequest: Encodable {
    let jobId: String
    let userId: String
    let name: String
    let email: String
    let resumeText: String
    let coverLetter: String
    let photoBase64: String?
}

struct UpdateProfileRequest: Encodable {
    let id: String
    let name: String
    let email: String
    let photoBase64: String?
    let headline: String
    let about: String
    let skills: String
    let city: String
    let resumeText: String
}

private struct StatusUpdateRequest: Encodable {
    let employerId: String
    let status: String
}

private struct MarkViewedRequest: Encodable {
    let employerId: String
}

private struct MarkViewedResponse: Decodable {
    let updated: Int?
}

private struct DeleteResponse: Decodable {
    let deleted: Bool?
}

private struct ServerError: Decodable {
    let error: String?
}

// MARK: - DTOs

struct JobDTO: Decodable {
    let id: String
    let employerId: String?
    let title: String
    let companyName: String?
    let description: String?
    let summary: String?
    let salaryMin: Int?
    let salaryMax: Int?
    let city: String?
    let category: String?
    let isRemote: Bool?
    let employmentType: String?
    let experience: String?
    let requirements: [String]?
    let benefits: [String]?
    let contactEmail: String?
    let status: String?
    let verified: Bool?
    let applicationsCount: Int?
    let companyEdrpou: String?
    let companyVerified: Bool?
    let aiVerified: Bool?
    let matchScore: Int?
    let matchReason: String?
    let matchSource: String?
    let createdAt: String?

    func toModel() -> Vacancy {
        let edrpou = (companyEdrpou ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let company = Company(
            name: companyName ?? "Компанія",
            isVerified: companyVerified ?? verified ?? false,
            industry: category ?? "IT та телеком",
            edrpou: edrpou.isEmpty ? nil : edrpou
        )
        let salaryMin = self.salaryMin ?? 0
        let salaryMax = self.salaryMax ?? 0
        let description = self.description ?? ""
        let postedAt = APIDateParser.date(from: createdAt) ?? Date()

        return Vacancy(
            id: id,
            title: title,
            company: company,
            salaryMin: salaryMin,
            salaryMax: salaryMax,
            city: city ?? "Україна",
            isRemote: isRemote ?? false,
            category: category ?? "IT та телеком",
            employmentType: employmentType ?? "Повна зайнятість",
            experience: experience ?? "1–3 роки",
            summary: summary ?? String(description.prefix(160)),
            description: description,
            responsibilities: [],
            requirements: requirements ?? [],
            benefits: benefits ?? [],
            contactEmail: contactEmail ?? "hr@vakansio.app",
            contactPhone: nil,
            postedAt: postedAt,
            isVerified: verified ?? false,
            isUrgent: false,
            status: JobStatus(rawValue: status ?? "active") ?? .active,
            applicationsCount: applicationsCount ?? 0,
            aiVerified: aiVerified ?? true,
            matchScore: matchScore,
            matchReason: matchReason,
            matchSource: matchSource
        )
    }
}

struct ApplicationDTO: Decodable {
    let id: String
    let status: String?
    let candidateName: String?
    let candidateEmail: String?
    let photoBase64: String?
    let resumeText: String?
    let coverLetter: String?
    let aiScore: Int?
    let aiSummary: String?
    let createdAt: String?
    let job: JobDTO

    func toModel() -> Application {
        Application(
            id: id,
            vacancy: job.toModel(),
            status: ApplicationStatus(rawValue: status ?? "sent") ?? .sent,
            appliedAt: APIDateParser.date(from: createdAt) ?? Date(),
            coverLetter: coverLetter ?? "",
            resumeText: resumeText ?? "",
            candidateName: candidateName ?? "",
            candidateEmail: candidateEmail ?? "",
            candidatePhotoBase64: photoBase64,
            aiScore: aiScore ?? 0,
            aiSummary: aiSummary ?? ""
        )
    }
}

struct ProfileDTO: Decodable {
    let id: String
    let name: String?
    let email: String?
    let photoBase64: String?
    let headline: String?
    let about: String?
    let skills: String?
    let city: String?
    let resumeText: String?
    let isAdmin: Bool?
    let companyEdrpou: String?
    let companyVerified: Bool?
    let verificationStatus: String?

    func toModel() -> UserProfile {
        UserProfile(
            id: id,
            name: name ?? "",
            email: email ?? "",
            photoBase64: photoBase64,
            headline: headline ?? "",
            about: about ?? "",
            skills: skills ?? "",
            city: city ?? "",
            resumeText: resumeText ?? "",
            isAdmin: isAdmin ?? false,
            companyEdrpou: companyEdrpou ?? "",
            companyVerified: companyVerified ?? false,
            verificationStatus: verificationStatus ?? ""
        )
    }
}

enum APIDateParser {
    static func date(from value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}


// MARK: - AI / chat requests

struct GenerateResumeRequest: Encodable {
    let userId: String
    let answers: ResumeAnswersPayload
}

struct ResumeAnswersPayload: Encodable {
    let fullName: String
    let position: String
    let city: String
    let experience: String
    let skills: String
}

private struct ChatMessageRequest: Encodable {
    let applicationId: String
    let userId: String
    let text: String
}

private struct DeviceRequest: Encodable {
    let userId: String
    let token: String
    let platform: String
}

private struct OKResponse: Decodable {
    let ok: Bool?
}

struct GeneratedResumeDTO: Decodable {
    let resumeText: String?
    let headline: String?
    let about: String?
    let skills: String?
    let city: String?
    let source: String?

    func toModel() -> GeneratedResume {
        GeneratedResume(
            resumeText: resumeText ?? "",
            headline: headline ?? "",
            about: about ?? "",
            skills: skills ?? "",
            city: city ?? "",
            source: source ?? "fallback"
        )
    }
}

struct ChatMessageDTO: Decodable {
    let id: String
    let applicationId: String?
    let senderId: String?
    let senderRole: String?
    let senderName: String?
    let text: String?
    let createdAt: String?

    func toModel() -> ChatMessage {
        ChatMessage(
            id: id,
            applicationId: applicationId ?? "",
            senderId: senderId ?? "",
            senderRole: senderRole ?? "seeker",
            senderName: senderName ?? "",
            text: text ?? "",
            createdAt: APIDateParser.date(from: createdAt) ?? Date()
        )
    }
}


// MARK: - Overit verification / admin DTOs

private struct VerifyCompanyRequest: Encodable {
    let userId: String
    let edrpou: String
}

struct CompanyVerificationDTO: Decodable {
    let status: String?
    let verified: Bool?
    let edrpou: String?
    let companyName: String?
    let reason: String?

    func toModel() -> CompanyVerificationResult {
        CompanyVerificationResult(
            status: status ?? "pending_manual_review",
            verified: verified ?? false,
            edrpou: edrpou ?? "",
            companyName: companyName ?? "",
            reason: reason
        )
    }
}

struct AdminUsageDTO: Decodable {
    let month: String?
    let freeUsed: Int?
    let freeLimit: Int?
    let paidBalance: Int?

    func toModel() -> AdminUsage {
        AdminUsage(
            month: month ?? "",
            freeUsed: freeUsed ?? 0,
            freeLimit: freeLimit ?? 25,
            paidBalance: paidBalance ?? 0
        )
    }
}

struct AdminCountsDTO: Decodable {
    let users: Int?
    let jobs: Int?
    let applications: Int?
    let pendingVerifications: Int?

    func toModel() -> AdminCounts {
        AdminCounts(
            users: users ?? 0,
            jobs: jobs ?? 0,
            applications: applications ?? 0,
            pendingVerifications: pendingVerifications ?? 0
        )
    }
}

struct AdminPendingDTO: Decodable {
    let id: String
    let userId: String?
    let edrpou: String?
    let companyName: String?
    let status: String?
    let note: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case edrpou
        case companyName = "company_name"
        case status
        case note
        case createdAt = "created_at"
    }

    func toModel() -> AdminPendingVerification {
        AdminPendingVerification(
            id: id,
            userId: userId ?? "",
            edrpou: edrpou ?? "",
            companyName: companyName ?? "",
            status: status ?? "",
            note: note ?? "",
            createdAt: APIDateParser.date(from: createdAt) ?? Date()
        )
    }
}

struct AdminOverviewDTO: Decodable {
    let usage: AdminUsageDTO?
    let counts: AdminCountsDTO?
    let pending: [AdminPendingDTO]?

    func toModel() -> AdminOverview {
        AdminOverview(
            usage: usage?.toModel() ?? AdminUsage(month: "", freeUsed: 0, freeLimit: 25, paidBalance: 0),
            counts: counts?.toModel() ?? AdminCounts(users: 0, jobs: 0, applications: 0, pendingVerifications: 0),
            pending: (pending ?? []).map { $0.toModel() }
        )
    }
}
