//
//  BrightnessHistoryView.swift
//  water-pump-controller
//
//  Created by 江藤公二 on 2025/10/26.
//

import SwiftUI
import Charts

struct BrightnessData: Identifiable {
    let id: String
    let brightness: Double
    let timestamp: Date
}

struct BrightnessAPIResponse: Codable {
    let status: String
    let count: Int
    let timeRange: TimeRange?
    let data: [BrightnessRecord]
    
    enum CodingKeys: String, CodingKey {
        case status, count
        case timeRange = "time_range"
        case data
    }
    
    struct TimeRange: Codable {
        let start: String
        let end: String
        let minutes: Int
    }
    
    struct BrightnessRecord: Codable {
        let id: String
        let topic: String
        let brightness: Double
        let timestamp: String
        let receivedAt: String
        
        enum CodingKeys: String, CodingKey {
            case id, topic, brightness, timestamp
            case receivedAt = "received_at"
        }
    }
}

class BrightnessAPIClient: ObservableObject {
    @Published var brightnessData: [BrightnessData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL: String
    
    init(baseURL: String = "http://192.168.1.34:4567") {
        self.baseURL = baseURL
    }
    
    func fetchBrightnessHistory(minutes: Int = 360) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/brightness/\(minutes)") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let apiResponse = try decoder.decode(BrightnessAPIResponse.self, from: data)
                    
                    let formatter = ISO8601DateFormatter()
                    
                    self?.brightnessData = apiResponse.data.compactMap { record in
                        guard let date = formatter.date(from: record.timestamp) else {
                            return nil
                        }
                        return BrightnessData(
                            id: record.id,
                            brightness: record.brightness,
                            timestamp: date
                        )
                    }.sorted { $0.timestamp < $1.timestamp }
                    
                } catch {
                    self?.errorMessage = "Parse error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

struct BrightnessHistoryView: View {
    @StateObject private var apiClient = BrightnessAPIClient()
    @State private var selectedMinutes: Int = 360
    @State private var showingTimePicker = false
    
    let timeOptions = [
        (minutes: 60, label: "1時間"),
        (minutes: 180, label: "3時間"),
        (minutes: 360, label: "6時間"),
        (minutes: 720, label: "12時間"),
        (minutes: 1440, label: "24時間")
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                if apiClient.isLoading {
                    ProgressView("読み込み中...")
                        .padding()
                } else if let errorMessage = apiClient.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("再試行") {
                            apiClient.fetchBrightnessHistory(minutes: selectedMinutes)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if apiClient.brightnessData.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("データがありません")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 時間範囲選択
                            timeRangeSelector
                            
                            // 統計情報
                            statsSection
                            
                            // グラフ
                            chartSection
                            
                            // データリスト
                            dataListSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("照度履歴")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        apiClient.fetchBrightnessHistory(minutes: selectedMinutes)
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(apiClient.isLoading)
                }
            }
            .onAppear {
                apiClient.fetchBrightnessHistory(minutes: selectedMinutes)
            }
            .sheet(isPresented: $showingTimePicker) {
                timePickerSheet
            }
        }
    }
    
    private var timeRangeSelector: some View {
        HStack {
            Text("期間:")
                .font(.headline)
            
            Spacer()
            
            Menu {
                ForEach(timeOptions, id: \.minutes) { option in
                    Button(action: {
                        selectedMinutes = option.minutes
                        apiClient.fetchBrightnessHistory(minutes: option.minutes)
                    }) {
                        HStack {
                            Text(option.label)
                            if selectedMinutes == option.minutes {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(timeOptions.first(where: { $0.minutes == selectedMinutes })?.label ?? "6時間")
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "最大値",
                value: String(format: "%.0f", apiClient.brightnessData.map(\.brightness).max() ?? 0),
                unit: "lux",
                color: .orange
            )
            StatCard(
                title: "最小値",
                value: String(format: "%.0f", apiClient.brightnessData.map(\.brightness).min() ?? 0),
                unit: "lux",
                color: .blue
            )
            StatCard(
                title: "平均値",
                value: String(format: "%.0f", apiClient.brightnessData.isEmpty ? 0 : apiClient.brightnessData.map(\.brightness).reduce(0, +) / Double(apiClient.brightnessData.count)),
                unit: "lux",
                color: .green
            )
        }
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("照度推移")
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(apiClient.brightnessData) { data in
                    LineMark(
                        x: .value("時刻", data.timestamp),
                        y: .value("照度", data.brightness)
                    )
                    .foregroundStyle(.blue)
                    
                    AreaMark(
                        x: .value("時刻", data.timestamp),
                        y: .value("照度", data.brightness)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                }
            }
            .frame(height: 300)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Text("データ数: \(apiClient.brightnessData.count)件")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
    
    private var dataListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("データ一覧")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(apiClient.brightnessData.reversed()) { data in
                    HStack {
                        Text(formatTimestamp(data.timestamp))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f", data.brightness))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(brightnessColor(data.brightness))
                        
                        Text("lux")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemBackground))
                    
                    if data.id != apiClient.brightnessData.first?.id {
                        Divider()
                    }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var timePickerSheet: some View {
        NavigationView {
            List {
                ForEach(timeOptions, id: \.minutes) { option in
                    Button(action: {
                        selectedMinutes = option.minutes
                        showingTimePicker = false
                        apiClient.fetchBrightnessHistory(minutes: option.minutes)
                    }) {
                        HStack {
                            Text(option.label)
                            Spacer()
                            if selectedMinutes == option.minutes {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("期間選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        showingTimePicker = false
                    }
                }
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func brightnessColor(_ brightness: Double) -> Color {
        switch brightness {
        case 0...1:
            return .black
        case 1.01...100:
            return .purple
        case 100.01...500:
            return .blue
        case 500.01...1000:
            return .cyan
        case 1000.01...2000:
            return .green
        case 2000.01...10000:
            return .yellow
        case 10000.01...25000:
            return .orange
        case 25000.01...50000:
            return .red
        default:
            return .pink
        }
    }
}

#Preview {
    BrightnessHistoryView()
}
