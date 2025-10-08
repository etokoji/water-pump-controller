//
//  PumpLogView.swift
//  water-pump-controller
//
//  Created by 江藤公二 on 2025/10/08.
//

import SwiftUI

struct PumpLogView: View {
    @ObservedObject var mqttClient: MQTTClient
    @State private var showPWMDialog = false
    
    var body: some View {
        NavigationView {
            VStack {
                connectionStatusView
                logListView
            }
            .navigationTitle("ポンプログ")
            .sheet(isPresented: $showPWMDialog) {
                PWMSettingDialog(mqttClient: mqttClient, isPresented: $showPWMDialog)
            }
        }
    }
    
    private var connectionStatusView: some View {
        HStack {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 12, height: 12)
            Text(mqttClient.connectionStatus)
                .font(.caption)
            Spacer()
            
            Button("PWM設定") {
                showPWMDialog = true
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private var logListView: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(mqttClient.logs.enumerated()), id: \.offset) { index, log in
                    Text(log)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary)
                        .id(index)
                }
            }
                    .onChange(of: mqttClient.logs.count) {
                        if !mqttClient.logs.isEmpty {
                            withAnimation {
                                proxy.scrollTo(mqttClient.logs.count - 1, anchor: .bottom)
                            }
                        }
                    }
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

#Preview {
    PumpLogView(mqttClient: MQTTClient())
}