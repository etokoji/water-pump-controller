//
//  SettingsView.swift
//  water-pump-controller
//
//  Created by 江藤公二 on 2025/10/08.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var mqttClient: MQTTClient
    @State private var brokerHost: String = ""
    @State private var brokerPort: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("MQTT接続設定") {
                    HStack {
                        Text("ブローカーホスト")
                        Spacer()
                        TextField("192.168.1.34", text: $brokerHost)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("ポート番号")
                        Spacer()
                        TextField("1883", text: $brokerPort)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("ユーザー名")
                        Spacer()
                        TextField("etokoji", text: $username)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("パスワード")
                        Spacer()
                        SecureField("パスワード", text: $password)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("接続状態") {
                    HStack {
                        Text("現在の状態")
                        Spacer()
                        Circle()
                            .fill(mqttClient.isConnected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .trailing) {
                            Text(mqttClient.isConnected ? "接続中" : "未接続")
                                .foregroundColor(mqttClient.isConnected ? .green : .red)
                            Text(mqttClient.connectionStatus)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("ブローカー")
                        Spacer()
                        Text("\(mqttClient.brokerHost):\(mqttClient.brokerPort)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("ユーザー")
                        Spacer()
                        Text(mqttClient.username)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("操作") {
                    Button(action: saveSettings) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("設定を保存")
                        }
                    }
                    
                    Button(action: reconnect) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("再接続")
                        }
                    }
                    
                    Button(action: clearLogs) {
                        HStack {
                            Image(systemName: "trash")
                            Text("ログをクリア")
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("情報") {
                    HStack {
                        Text("アプリバージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("ログエントリ数")
                        Spacer()
                        Text("\(mqttClient.logs.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .onAppear {
                loadCurrentSettings()
            }
            .alert("設定", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadCurrentSettings() {
        brokerHost = mqttClient.brokerHost
        brokerPort = "\(mqttClient.brokerPort)"
        username = mqttClient.username
        password = mqttClient.password
    }
    
    private func saveSettings() {
        guard !brokerHost.isEmpty else {
            alertMessage = "ブローカーホストを入力してください"
            showAlert = true
            return
        }
        
        guard let port = UInt16(brokerPort), port > 0 else {
            alertMessage = "有効なポート番号を入力してください"
            showAlert = true
            return
        }
        
        mqttClient.updateSettings(host: brokerHost, port: port, username: username, password: password)
        
        alertMessage = "設定を保存しました。再接続してください。"
        showAlert = true
    }
    
    private func reconnect() {
        mqttClient.disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            mqttClient.connect()
        }
        
        alertMessage = "再接続を開始しました"
        showAlert = true
    }
    
    private func clearLogs() {
        mqttClient.logs.removeAll()
        alertMessage = "ログをクリアしました"
        showAlert = true
    }
}

#Preview {
    SettingsView(mqttClient: MQTTClient())
}