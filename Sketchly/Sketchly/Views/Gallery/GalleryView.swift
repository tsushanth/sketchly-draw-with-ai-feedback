//
//  GalleryView.swift
//  Sketchly
//

import SwiftUI
import SwiftData

struct GalleryView: View {
    @Environment(PremiumManager.self) private var premiumManager
    @State private var viewModel = GalleryViewModel()
    @State private var showPaywall = false
    @State private var selectedTab: GalleryTab = .community

    enum GalleryTab: String, CaseIterable {
        case community = "Community"
        case myWork = "My Work"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if premiumManager.isPremium {
                    // Tab selector
                    Picker("Gallery", selection: $selectedTab) {
                        ForEach(GalleryTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if selectedTab == .community {
                        communityFeedView
                    } else {
                        myWorkView
                    }
                } else {
                    premiumGateView
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if premiumManager.isPremium {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {}) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(
                                    LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(premiumManager)
        }
        .onAppear {
            AnalyticsService.shared.logScreenView(screenName: "Gallery", screenClass: "GalleryView")
        }
    }

    // MARK: - Community Feed
    private var communityFeedView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.communityPosts) { post in
                    GalleryPostView(post: post) {
                        viewModel.likePost(post)
                    }
                }
                Spacer(minLength: 100)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: - My Work
    private var myWorkView: some View {
        Group {
            EmptyStateView(
                icon: "photo.on.rectangle.angled",
                title: "No Drawings Yet",
                message: "Complete drawing sessions to see your work here",
                actionTitle: "Start Drawing"
            ) {
                // Navigate to practice
            }
        }
    }

    // MARK: - Premium Gate
    private var premiumGateView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Blurred preview
                ZStack {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.communityPosts.prefix(2)) { post in
                            GalleryPostView(post: post) {}
                        }
                    }
                    .blur(radius: 8)

                    VStack(spacing: 20) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )

                        VStack(spacing: 8) {
                            Text("Community Gallery")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Share your drawings and get inspired by artists around the world")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        Button(action: { showPaywall = true }) {
                            HStack {
                                Image(systemName: "crown.fill")
                                Text("Unlock Gallery")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
}
