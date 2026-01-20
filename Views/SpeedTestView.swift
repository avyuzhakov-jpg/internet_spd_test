import SwiftUI
import MapKit

struct SpeedTestView: View {
    @StateObject private var viewModel = SpeedTestViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) { // Увеличил отступ для лучшего вида на весь экран

                    // MARK: - Test Size
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Test Size")
                            .font(.headline)

                        Picker("Size", selection: $viewModel.selectedSize) {
                            ForEach(TestSize.allCases) { size in
                                Text(size.displayTitle).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(viewModel.isRunning)
                    }

                    // MARK: - Action Button
                    if viewModel.isRunning {
                        Button(role: .destructive) {
                            viewModel.cancelTest()
                        } label: {
                            Text("Cancel Test")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            viewModel.startTest()
                        } label: {
                            Text("Start Test")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    // MARK: - Status
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Status")
                            .font(.headline)

                        HStack(spacing: 12) {
                            if viewModel.isRunning {
                                ProgressView()
                            }
                            // viewModel.phase.rawValue оставлен без изменений
                            Text(viewModel.phase.rawValue)
                        }

                        if viewModel.isRunning {
                            ProgressView(value: viewModel.progress)
                            Text("\(Int(viewModel.progress * 100))%")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if !viewModel.errorMessage.isEmpty {
                            Text(viewModel.errorMessage)
                                .foregroundStyle(.red)
                                .font(.footnote)
                                .textSelection(.enabled)
                        }
                    }

                    // MARK: - Results
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Results")
                            .font(.headline)

                        resultRow(title: "Download", value: formatMbps(viewModel.downloadMbps))
                        resultRow(title: "Upload", value: formatMbps(viewModel.uploadMbps))
                        resultRow(title: "Ping", value: formatMs(viewModel.pingMs))
                        resultRow(title: "Jitter", value: formatMs(viewModel.jitterMs))
                    }

                    // MARK: - Network
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Network")
                            .font(.headline)

                        resultRow(title: "Type", value: viewModel.networkType.displayName)
                        resultRow(title: "Server", value: AppConfig.baseURLString)
                    }

                    // MARK: - Location
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Location")
                            .font(.headline)

                        resultRow(title: "Status", value: viewModel.locationStatus.rawValue)
                        resultRow(title: "Start", value: formattedCoord(viewModel.startCoordinate))
                        resultRow(title: "End", value: formattedCoord(viewModel.endCoordinate))
                    }

                    // MARK: - Map
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Map")
                            .font(.headline)

                        SpeedTestMapView(
                            start: viewModel.startCoordinate,
                            end: viewModel.endCoordinate
                        )
                        .frame(height: 200) // Указал высоту для карты, чтобы она не сжималась
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Speed Test")
            // Убрал принудительный background, теперь используется системный
        }
    }

    // Вспомогательные функции оставлены без изменений (логика)
    private func resultRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 6)
    }

    private func formatMbps(_ value: Double?) -> String {
        guard let v = value else { return "— Mbps" }
        return String(format: "%.2f Mbps", v)
    }

    private func formatMs(_ value: Double?) -> String {
        guard let v = value else { return "— ms" }
        return String(format: "%.2f ms", v)
    }

    private func formattedCoord(_ coord: CLLocationCoordinate2D?) -> String {
        guard let c = coord else { return "—" }
        let lat = Formatters.roundedString(c.latitude, decimals: 3)
        let lon = Formatters.roundedString(c.longitude, decimals: 3)
        return "\(lat), \(lon)"
    }
}
