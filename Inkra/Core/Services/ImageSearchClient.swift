import Foundation

// MARK: - BackgroundImage Model
struct BackgroundImage {
    let url: String
    let downloadUrl: String
    let provider: String
    let photographer: String?
    let description: String?
    let width: Int
    let height: Int
}

protocol ImageSearchClient {
    func searchImages(query: String, count: Int, orientation: String?) async throws -> [BackgroundImage]
}

class PexelsImageClient: ImageSearchClient {
    private let apiKey: String
    private let baseURL = "https://api.pexels.com/v1"
    
    init() throws {
        guard let key = ProcessInfo.processInfo.environment["PEXELS_API_KEY"] else {
            throw ImageSearchError.missingAPIKey("PEXELS_API_KEY")
        }
        self.apiKey = key
    }
    
    func searchImages(query: String, count: Int, orientation: String? = nil) async throws -> [BackgroundImage] {
        let enhancedQuery = "\(query) high quality professional"
        let orientationParam = orientation == "portrait" ? "portrait" : "landscape"
        guard let encodedQuery = enhancedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search?query=\(encodedQuery)&per_page=\(count)&orientation=\(orientationParam)&size=large") else {
            throw ImageSearchError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageSearchError.networkError
        }
        
        let pexelsResponse = try JSONDecoder().decode(PexelsResponse.self, from: data)
        
        return pexelsResponse.photos.compactMap { photo in
            guard let originalUrl = photo.src.original ?? photo.src.large2x ?? photo.src.large,
                  photo.width >= 1920 && photo.height >= 1080 else {
                return nil
            }
            
            return BackgroundImage(
                url: originalUrl,
                downloadUrl: originalUrl,
                provider: "Pexels",
                photographer: photo.photographer,
                description: photo.alt,
                width: photo.width,
                height: photo.height
            )
        }
    }
}

class UnsplashImageClient: ImageSearchClient {
    private let apiKey: String?
    private let baseURL = "https://api.unsplash.com"
    
    init() {
        self.apiKey = ProcessInfo.processInfo.environment["UNSPLASH_API_KEY"]
    }
    
    func searchImages(query: String, count: Int, orientation: String? = nil) async throws -> [BackgroundImage] {
        guard let apiKey = apiKey else {
            throw ImageSearchError.networkError
        }
        
        let enhancedQuery = "\(query) high resolution professional"
        let orientationParam = orientation == "portrait" ? "portrait" : "landscape"
        guard let encodedQuery = enhancedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/photos?query=\(encodedQuery)&per_page=\(count)&orientation=\(orientationParam)&order_by=relevant") else {
            throw ImageSearchError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Client-ID \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageSearchError.networkError
        }
        
        let unsplashResponse = try JSONDecoder().decode(UnsplashResponse.self, from: data)
        
        return unsplashResponse.results.compactMap { photo in
            guard photo.width >= 2400 && photo.height >= 1600 else {
                return nil
            }
            
            return BackgroundImage(
                url: photo.urls.full ?? photo.urls.raw ?? photo.urls.regular,
                downloadUrl: photo.links.download,
                provider: "Unsplash",
                photographer: photo.user.name,
                description: photo.description ?? photo.altDescription,
                width: photo.width,
                height: photo.height
            )
        }
    }
}

class PixabayImageClient: ImageSearchClient {
    private let apiKey: String
    private let baseURL = "https://pixabay.com/api"
    
    init() throws {
        guard let key = ProcessInfo.processInfo.environment["PIXABAY_API_KEY"] else {
            throw ImageSearchError.missingAPIKey("PIXABAY_API_KEY")
        }
        self.apiKey = key
    }
    
    func searchImages(query: String, count: Int, orientation: String? = nil) async throws -> [BackgroundImage] {
        let enhancedQuery = "\(query) high quality professional"
        let orientationParam = orientation == "portrait" ? "vertical" : "horizontal"
        let (minWidth, minHeight) = orientation == "portrait" ? (1000, 2000) : (2000, 1000)
        guard let encodedQuery = enhancedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/?key=\(apiKey)&q=\(encodedQuery)&image_type=photo&orientation=\(orientationParam)&per_page=\(count)&min_width=\(minWidth)&min_height=\(minHeight)&order=popular") else {
            throw ImageSearchError.invalidURL
        }
        
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageSearchError.networkError
        }
        
        let pixabayResponse = try JSONDecoder().decode(PixabayResponse.self, from: data)
        
        return pixabayResponse.hits.compactMap { photo in
            let imageUrl = photo.fullHDURL ?? photo.largeImageURL ?? photo.webformatURL
            guard
                  photo.imageWidth >= 2400 && photo.imageHeight >= 1200,
                  photo.likes >= 10 && photo.downloads >= 50 else {
                return nil
            }
            
            return BackgroundImage(
                url: imageUrl,
                downloadUrl: photo.largeImageURL ?? imageUrl,
                provider: "Pixabay",
                photographer: photo.user,
                description: photo.tags,
                width: photo.imageWidth,
                height: photo.imageHeight
            )
        }
    }
}

// MARK: - Response Models

struct PexelsResponse: Codable {
    let photos: [PexelsPhoto]
}

struct PexelsPhoto: Codable {
    let id: Int
    let width: Int
    let height: Int
    let photographer: String
    let alt: String
    let src: PexelsPhotoSrc
}

struct PexelsPhotoSrc: Codable {
    let original: String?
    let large2x: String?
    let large: String?
}

struct UnsplashResponse: Codable {
    let results: [UnsplashPhoto]
}

struct UnsplashPhoto: Codable {
    let id: String
    let width: Int
    let height: Int
    let description: String?
    let altDescription: String?
    let urls: UnsplashPhotoUrls
    let links: UnsplashPhotoLinks
    let user: UnsplashUser
    
    enum CodingKeys: String, CodingKey {
        case id, width, height, description, urls, links, user
        case altDescription = "alt_description"
    }
}

struct UnsplashPhotoUrls: Codable {
    let raw: String?
    let full: String?
    let regular: String
}

struct UnsplashPhotoLinks: Codable {
    let download: String
}

struct UnsplashUser: Codable {
    let name: String
}

struct PixabayResponse: Codable {
    let hits: [PixabayPhoto]
}

struct PixabayPhoto: Codable {
    let id: Int
    let imageWidth: Int
    let imageHeight: Int
    let user: String
    let tags: String
    let likes: Int
    let downloads: Int
    let fullHDURL: String?
    let largeImageURL: String?
    let webformatURL: String
}

enum ImageSearchError: Error, LocalizedError {
    case invalidURL
    case networkError
    case decodingError
    case missingAPIKey(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for image search"
        case .networkError:
            return "Network error during image search"
        case .decodingError:
            return "Failed to decode image search response"
        case .missingAPIKey(let keyName):
            return "Missing API key: \(keyName)"
        }
    }
}

// MARK: - BackgroundImage Hashable and Equatable
extension BackgroundImage: Hashable, Equatable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(provider)
    }
    
    static func == (lhs: BackgroundImage, rhs: BackgroundImage) -> Bool {
        return lhs.url == rhs.url && lhs.provider == rhs.provider
    }
}