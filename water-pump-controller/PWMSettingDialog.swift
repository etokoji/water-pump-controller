//
//  PWMSettingDialog.swift
//  water-pump-controller
//
//  Created by 江藤公二 on 2025/10/08.
//

import SwiftUI

struct PWMSettingDialog: View {
    @ObservedObject var mqttClient: MQTTClient
    @Binding var isPresented: Bool
    @State private var pwmLength: String = "2500"
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("放水時間設定")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // 接続状態表示
                HStack {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 10, height: 10)
                    Text(mqttClient.connectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("PWM長 (ミリ秒)")
                        .font(.headline)
                    
                    TextField("PWM長を入力", text: $pwmLength)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                    
                    Text("現在の設定: \(pwmLength)ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // プリセット値ボタン
                VStack(alignment: .leading, spacing: 8) {
                    Text("プリセット")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                        ForEach([1000, 2000, 2500, 3000, 4000, 5000], id: \.self) { value in
                            Button("\(value)ms") {
                                pwmLength = "\(value)"
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(pwmLength == "\(value)" ? .white : .primary)
                            .background(pwmLength == "\(value)" ? Color.blue : Color.clear)
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
                
                // 送信ボタン
                Button(action: sendPWMSetting) {
                    HStack {
                        Image(systemName: "paperplane")
                        Text("設定を送信")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(mqttClient.isConnected ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!mqttClient.isConnected)
            }
            .padding()
            .navigationTitle("PWM設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
            }
            .alert("設定送信", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func sendPWMSetting() {
        guard let pwmValue = Int(pwmLength), pwmValue > 0 else {
            alertMessage = "有効な数値を入力してください"
            showAlert = true
            return
        }
        
        mqttClient.publishPWMLength(pwmValue)
        alertMessage = "PWM長 \(pwmValue)ms を送信しました"
        showAlert = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isPresented = false
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
    PWMSettingDialog(mqttClient: MQTTClient(), isPresented: .constant(true))
}