import SwiftUI
import UIKit

struct FontListView: View {
    @State private var fontFamilies: [String] = []
    @State private var selectedFontFamily: String = ""
    @State private var searchText: String = ""
    
    var filteredFontFamilies: [String] {
        if searchText.isEmpty {
            return fontFamilies
        } else {
            return fontFamilies.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                FontSearchBar(text: $searchText)
                
                List {
                    ForEach(filteredFontFamilies, id: \.self) { fontFamily in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(fontFamily)
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            // Show available font names in this family
                            let fontNames = UIFont.fontNames(forFamilyName: fontFamily)
                            ForEach(fontNames, id: \.self) { fontName in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(fontName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("The quick brown fox jumps over the lazy dog")
                                        .font(.custom(fontName, size: 16))
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("iOS Fonts")
            .onAppear {
                loadFontFamilies()
            }
        }
    }
    
    private func loadFontFamilies() {
        fontFamilies = UIFont.familyNames.sorted()
    }
}

struct FontSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search fonts...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
    }
}

// Helper view to show all font weights for system fonts
struct SystemFontWeightView: View {
    let fontWeights: [(String, Font.Weight)] = [
        ("Ultra Light", .ultraLight),
        ("Thin", .thin),
        ("Light", .light),
        ("Regular", .regular),
        ("Medium", .medium),
        ("Semibold", .semibold),
        ("Bold", .bold),
        ("Heavy", .heavy),
        ("Black", .black)
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(fontWeights, id: \.0) { weightName, weight in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(weightName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("The quick brown fox jumps over the lazy dog")
                            .font(.system(size: 16, weight: weight))
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("System Font Weights")
        }
    }
}

#Preview {
    FontListView()
}

#Preview("System Font Weights") {
    SystemFontWeightView()
}