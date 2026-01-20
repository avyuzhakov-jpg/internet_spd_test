import SwiftUI
import MapKit

struct SpeedTestView: View {
    @StateObject private var viewModel = SpeedTestViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Блок выбора размера теста
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Configuration")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        
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
                        .padding(16)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Основная кнопка действия
                    actionButton

                    // Секция статуса и результатов
                    VStack(alignment: .leading, spacing: 12) {
                        headerText("Live Status & Results")
                        
                        VStack(spacing: 16) {
                            // Статус
                            HStack {
                                Label(viewModel.phase.rawValue, systemImage: viewModel.isRunning ? "antenna.radiowaves.left.and.right" : "info.circle")
                                    .fontWeight(.medium)
                                Spacer()
                                if viewModel.isRunning {
                                    ProgressView()
                                }
                            }
                            
                            if viewModel.isRunning {
                                ProgressView(value: viewModel.progress)
                                    .tint(.blue)
                            }
                            
                            Divider()
                            
                            // Результаты (Сеткой)
                            HStack(alignment: .top) {
                                resultValue(title: "Download", value: formatMbps(viewModel.downloadMbps), icon: "arrow.down.circle.fill", color: .blue)
                                Spacer()
                                resultValue(title: "Upload", value: formatMbps(viewModel.uploadMbps), icon: "arrow.up.circle.fill", color: .green)
                            }
                            
                            HStack {
                                resultRow(title: "Ping", value: formatMs(viewModel.pingMs))
                                Divider().frame(height: 14)
                                resultRow(title: "Jitter", value: formatMs(viewModel.jitterMs))
                            }
                        }
                        .padding(16)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Сеть и Геолокация
                    VStack(alignment: .leading, spacing: 12) {
                        headerText("Connection Details")
                        
                        VStack(spacing: 12) {
                            resultRow(title: "Network Type", value: viewModel.networkType.displayName)
                            resultRow(title: "Server", value: AppConfig.baseURLString)
                            Divider()
                            resultRow(title: "Location Status", value: viewModel.locationStatus.rawValue)
                        }
                        .padding(16)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Карта
                    VStack(alignment: .leading, spacing: 12) {
                        headerText("Map Coverage")
                        
                        SpeedTestMapView(
                            start: viewModel.startCoordinate,
                            end: viewModel.endCoordinate
                        )
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1), lineWidth: 1))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground)) // Светло-серый системный фон
            .navigationTitle("Speed Test")
        }
    }

    // MARK: - Вспомогательные компоненты UI

    private var actionButton: some View {
        Button {
            viewModel.isRunning ? viewModel.cancelTest() : viewModel.startTest()
        } label: {
            Text(viewModel.isRunning ? "Cancel Test" : "Start Test")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(viewModel.isRunning ? .red : .blue)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: (viewModel.isRunning ? Color.red : Color.blue).opacity(0.3), radius: 10, y: 5)
    }

    private func headerText(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private func resultValue(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
        }
    }

    private func resultRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // Логика форматирования (без изменений)
    private func formatMbps(_ value: Double?) -> String {
        guard let v = value else { return "0.00" }
        return String(format: "%.2f", v)
    }

    private func formatMs(_ value: Double?) -> String {
        guard let v = value else { return "— ms" }
        return String(format: "%.0f ms", v)
    }
}
