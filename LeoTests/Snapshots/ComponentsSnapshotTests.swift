@testable import Leo
import SnapshotTesting
import SwiftUI
import Testing

extension ViewSnapshots {
    @MainActor
    struct ComponentsSnapshotTests {
        /// Every shared component in its states, on the Broadsheet ground.
        private var components: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Kicker("Now writing", color: .leoAccent700)
                    ProgressDots(
                        states: [.done, .current, .failed, .currentCorrect, .currentMissed, .upcoming],
                        currentIndex: 1,
                    )
                    ProgressDots(states: Array(repeating: .upcoming, count: 6), currentIndex: nil, size: .large)
                    FlowLayout {
                        TopicChip(name: "Volcanoes", isOn: .constant(true))
                        TopicChip(name: "Pirates and treasure", isOn: .constant(false))
                        CustomTopicChip(name: "Chess", onRemove: {})
                        CustomTopicChip(name: "Origami", onRemove: nil)
                    }
                    VStack(spacing: 8) {
                        AnswerRow(marker: "A", text: "To measure how much snow falls", state: .idle)
                        AnswerRow(marker: "B", text: "To feel small shakes", state: .correct)
                        AnswerRow(marker: "C", text: "To find the best path", state: .incorrect, note: "Your answer")
                        AnswerRow(marker: "D", text: "To keep the magma from moving", state: .dimmed)
                    }
                    AgeRow(label: "9 to 11", description: "Everyday words · 80–120 words", isSelected: true) {}
                    AgeRow(label: "12 to 14", description: "Some new vocabulary · 100–150 words", isSelected: false) {}
                    SkeletonLines()
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(verbatim: "The Sleeping Mountain")
                            .layoutPriority(1)
                        DottedLeader()
                            .frame(minWidth: 20)
                        Text(verbatim: "Correct")
                    }
                    .leoTextStyle(.body)
                    Text(verbatim: "Explanations are set in the true italic.")
                        .leoTextStyle(.explanation)
                    Button("Start") {}
                        .buttonStyle(.leo(.primary))
                    Button("Continue") {}
                        .buttonStyle(.leo(.primary))
                        .disabled(true)
                    HStack {
                        Button("Add") {}
                            .buttonStyle(.leo(.secondary))
                        Button("Try a different topic") {}
                            .buttonStyle(.leo(.ghost))
                    }
                }
                .foregroundStyle(Color.leoInk)
                .leoReadableWidth()
            }
            .leoScreenBackground()
        }

        @Test func gallery() {
            assertViewSnapshot(of: components, named: "gallery", height: 1300)
        }
    }
}
