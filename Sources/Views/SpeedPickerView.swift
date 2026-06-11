import SwiftUI

struct SpeedPickerView: View {
    @Bindable var model: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    private let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    var body: some View {
        List {
            ForEach(speeds, id: \.self) { speed in
                Button {
                    model.setSpeed(speed)
                    Haptics.tap()
                    dismiss()
                } label: {
                    HStack {
                        Text(speed == 1.0 ? "Normal" : "\(speed, specifier: "%.2g")x")
                            .font(.caption)
                        Spacer()
                        if model.currentSpeed == speed {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("Speed")
        .brandBackdrop()
    }
}
