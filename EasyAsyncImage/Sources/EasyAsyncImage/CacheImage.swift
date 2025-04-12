//
//  CacheImage.swift
//  Paathshala
//
//  Created by suraj_kumar on 12/04/25.
//

import SwiftUI

public class ImageCache {
    @MainActor static let shared = NSCache<NSString, UIImage>()
}

@available(iOS 13.0, *)
public struct ReliableAsyncImage: View {
    public let urlString: String
        public let width: CGFloat
        public let height: CGFloat
        public let cornerRadius: CGFloat

    public init(urlString: String, width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 8) {
        self.urlString = urlString
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    @State private var image: UIImage?
    @State private var loading = true

    public var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if loading {
                if #available(iOS 14.0, *) {
                    ProgressView()
                } else {
                    // Fallback on earlier versions
                }
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .cornerRadius(cornerRadius)
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = URL(string: urlString) else {
            self.loading = false
            return
        }

        // Check if image is already cached
        let cacheKey = NSString(string: urlString)
        if let cachedImage = ImageCache.shared.object(forKey: cacheKey) {
            self.image = cachedImage
            self.loading = false
            print("Loaded image from cache")
            return
        }

        print("Downloading image from: \(url)")

        // Clear the cache and cookies before each request
        URLCache.shared.removeAllCachedResponses()
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        // Use ephemeral session to avoid persistent cache/cookies
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.loading = false

                if let response = response as? HTTPURLResponse {
                    print("Image HTTP Status: \(response.statusCode)")
                }

                if let data = data, let uiImage = UIImage(data: data) {
                    // Cache the image for future use
                    ImageCache.shared.setObject(uiImage, forKey: cacheKey)
                    self.image = uiImage
                } else {
                    print("Image load failed:", error?.localizedDescription ?? "Unknown error")
                }
            }
        }.resume()
    }
}
