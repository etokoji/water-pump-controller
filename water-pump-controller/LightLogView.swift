//
//  LightLogView.swift
//  water-pump-controller
//
//  Created by 江藤公二 on 2025/10/08.
//

import SwiftUI

struct LightLogView: View {
    @ObservedObject var mqttClient: MQTTClient
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 接続状態表示
                HStack {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 12, height: 12)
                    Text(mqttClient.connectionStatus)
                        .font(.caption)
                    Spacer()
                }
                .padding()
                
                // 現在の照度表示
                VStack(spacing: 10) {
                    Text("現在の照度")
                        .font(.headline)
                    
                    Text("\(String(format: "%.2f", mqttClient.currentLightLevel)) lux")
                        .font(.system(.largeTitle, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // 照度レベルインジケーター
                    ProgressView(value: min(mqttClient.currentLightLevel / 60000, 1.0))
                        .progressViewStyle(LinearProgressViewStyle(tint: lightLevelColor))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                    
                    Text(mqttClient.currentLightDescription.isEmpty ? lightLevelDescription : mqttClient.currentLightDescription)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 統計情報
                HStack(spacing: 20) {
                    StatCard(title: "最大値", value: "\(String(format: "%.1f", mqttClient.maxLightLevel))", unit: "lux", color: .orange)
                    StatCard(title: "最小値", value: "\(String(format: "%.1f", mqttClient.minLightLevel == Double.infinity ? 0 : mqttClient.minLightLevel))", unit: "lux", color: .blue)
                    StatCard(title: "平均値", value: "\(String(format: "%.1f", mqttClient.averageLightLevel))", unit: "lux", color: .green)
                }
                .padding(.horizontal)
                
                // ログ表示
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(mqttClient.lightLogs.enumerated()), id: \.offset) { index, log in
                            Text(log)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.primary)
                                .id(index)
                        }
                    }
                    .onChange(of: mqttClient.lightLogs.count) {
                        if !mqttClient.lightLogs.isEmpty {
                            withAnimation {
                                proxy.scrollTo(mqttClient.lightLogs.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .navigationTitle("照度ログ")
        }
    }
    
    private var lightLevelColor: Color {
        switch mqttClient.currentLightLevel {
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
    
    private var lightLevelDescription: String {
        switch mqttClient.currentLightLevel {
        case 0...1:
            return "Very Dark"
        case 1.01...100:
            return "Dark"
        case 100.01...500:
            return "Indoor"
        case 500.01...1000:
            return "Bright Indoor"
        case 1000.01...2000:
            return "Very Bright Indoor"
        case 2000.01...10000:
            return "Daylight (Overcast)"
        case 10000.01...25000:
            return "Bright Sunlight"
        case 25000.01...50000:
            return "Very Bright Sunlight"
        default:
            return "Extremely Bright Sunlight"
        }
    }
    
    private var connectionStatusColor: Color {
        if mqttClient.isConnected {
            return .green
        } else if mqttClient.connectionStatus.contains("接続中") {
            return .orange
        } else if mqttClient.connectionStatus.contains("失敗") || mqttClient.connectionStatus.contains("キャンセル") {
            return .red
        } else {
            return .gray
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    LightLogView(mqttClient: MQTTClient())
}