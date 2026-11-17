//
//  ListenModeModifier.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-17.
//

import OSLog
import SwiftUI

struct ListenModeModifier: ViewModifier {

    // MARK: Properties

    /// Mirrors tab bar minimization; provided by the owner of `tabViewBottomAccessory`,
    /// since `tabViewBottomAccessoryPlacement` is only set inside the accessory's content
    let isTabBarExpanded: Bool

    // MARK: Properties (Private)

    /// Is the Listen Mode sheet showing?
    @State private var isListenModeSheetPresented = false

    // MARK: Properties (Private, Environment)

    /// Read appEnvironment.readerStore environment value from current view environment
    ///
    /// Don't need "\." here because this is a type-based lookup for an observable instance
    /// placed into the environment: .environment(readerStore))
    @Environment(ReaderStore.self) private var readerStore: ReaderStore

    /// for sheet close button / dismiss after selection
    @Environment(\.dismiss) private var dismissListenModeSheet

    // MARK: Properties (Private, Constants)

    private static let logger = Logger(subsystem: "SwiftBible", category: "ListenModeModifier")

    // MARK: Functions (Implementations)

    /// Apply left/right overlays to the parent view
    func body(content: Content) -> some View {
        // TODO: Listen Mode
        // Similar to accessibility feature "Speak Selection"
        // Auto-scroll and realtime word/line highlight
        // Show small sheet w/ play/pause, pacing, auto-advance chapter, voice
        // Allow disabling in Settings > Reader > Show Listen Mode

        content
            .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: nil) {
                if readerStore.loadState == .loaded {
                    Button {
                        isListenModeSheetPresented = true
                    } label: {
                        Image(systemName: "waveform")
                            .frame(width: 24, height: 24)
                            .imageScale(.large)
                            .foregroundStyle(Color.primary)
                            .padding(10)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .safeAreaPadding(.trailing, 20)
                    .safeAreaPadding(.bottom, 8)
                    .opacity(isTabBarExpanded ? 1 : 0)
                    .allowsHitTesting(isTabBarExpanded)
                    .accessibilityHidden(!isTabBarExpanded)
                    .animation(
                        isTabBarExpanded
                        ? .bouncy(duration: 0.3)
                        : .bouncy(duration: 0.4), // slightly longer on collapse
                        value: isTabBarExpanded
                    )
                }
            }
            .sheet(isPresented: $isListenModeSheetPresented, content: {
                NavigationStack {
        //                            Button {
        //
        //                            } label: {
        //                                Label("Play", systemImage: "play.fill")
        //                                    .labelStyle(.iconOnly)
        //                                    .frame(width: 80, height: 80)
        //                                    .foregroundStyle(Color.primary)
        ////                                    .imageScale(.large)
        //                                    .font(.system(size: 32))
        //                            }
        //                                .buttonStyle(.automatic)
        //                                .glassEffect(.clear.interactive(), in: .circle)
        //                                .frame(width: 80, height: 80)

                    ContentUnavailableView(
                        "Listen",
                        systemImage: "waveform",
                        description: Text("Coming soon.")
                    )
                        .navigationTitle("") // "Listen"
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(role: .close) {
                                    isListenModeSheetPresented = false
                                }
                            }
                        }
                }
                .presentationDetents([.fraction(0.35)])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
            })
    }
}

extension View {
    func listenModeButton(isTabBarExpanded: Bool) -> some View {
        modifier(ListenModeModifier(isTabBarExpanded: isTabBarExpanded))
    }
}
