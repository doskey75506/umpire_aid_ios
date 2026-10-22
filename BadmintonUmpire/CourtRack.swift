import SwiftUI
import ScoringCore

/// Two court slots for one team with drag-a-player-onto-the-other-to-swap.
///
/// Custom `DragGesture` instead of `.draggable`/`.dropDestination`: the system
/// drop session is unreliable inside Form/List rows (requirement: "拖过去放手，
/// 原来站位不会变"). Hit-testing compares the drag-end location against the
/// rack's own coordinate space (two equal slots along `axis`).
struct DraggableCourtRack: View {
    /// Court slots parallel to the team's names.
    let courts: [CourtSide]
    /// Visual order of the two slots (first = top / leading).
    let slotOrder: [CourtSide]
    let axis: Axis
    /// Player index -> card view.
    let card: (Int) -> AnyView
    let onSwap: () -> Void

    @State private var draggingPlayer: Int?
    @State private var dragOffset: CGSize = .zero

    private let spaceName = "court-rack"

    var body: some View {
        GeometryReader { geo in
            rackContent(rackSize: geo.size)
                .coordinateSpace(name: spaceName)
        }
    }

    @ViewBuilder
    private func rackContent(rackSize: CGSize) -> some View {
        if axis == .horizontal {
            HStack(spacing: 12) { slots(rackSize: rackSize) }
        } else {
            VStack(spacing: 8) { slots(rackSize: rackSize) }
        }
    }

    @ViewBuilder
    private func slots(rackSize: CGSize) -> some View {
        ForEach(Array(slotOrder.enumerated()), id: \.offset) { slotIndex, court in
            if let playerIndex = courts.firstIndex(of: court) {
                card(playerIndex)
                    .opacity(draggingPlayer == playerIndex ? 0.35 : 1)
                    .offset(draggingPlayer == playerIndex ? dragOffset : .zero)
                    .zIndex(draggingPlayer == playerIndex ? 1 : 0)
                    .onTapGesture {} // consume taps: scoring only via empty panel area
                    .gesture(
                        DragGesture(minimumDistance: 6, coordinateSpace: .named(spaceName))
                            .onChanged { value in
                                draggingPlayer = playerIndex
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                defer {
                                    draggingPlayer = nil
                                    dragOffset = .zero
                                }
                                let extent: Int
                                if axis == .horizontal {
                                    extent = value.location.x < rackSize.width / 2 ? 0 : 1
                                } else {
                                    extent = value.location.y < rackSize.height / 2 ? 0 : 1
                                }
                                guard extent >= 0, extent < slotOrder.count else { return }
                                if slotOrder[extent] != court {
                                    onSwap()
                                }
                            }
                    )
            }
        }
    }
}
