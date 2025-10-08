//
//  MQTTClient.swift
//  water-pump-controller
//
//  Created by 江藤公二 on 2025/10/08.
//

import Foundation
import Network
import Combine
import UIKit

class MQTTClient: ObservableObject {
    @Published var isConnected = false
    @Published var logs: [String] = []
    @Published var lightLogs: [String] = []
    @Published var currentLightLevel: Double = 0.0
    @Published var currentLightDescription: String = ""
    @Published var maxLightLevel: Double = 0.0
    @Published var minLightLevel: Double = Double.infinity
    @Published var averageLightLevel: Double = 0.0
    @Published var connectionStatus: String = "未接続"
    
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "mqtt.client.queue")
    private var reconnectTimer: Timer?
    private var connectionAttempts = 0
    private let maxReconnectAttempts = 5
    
    // MQTT設定
    var brokerHost: String = "192.168.1.34"
    var brokerPort: UInt16 = 1883
    var username: String = "etokoji"
    var password: String = ""
    
    init() {
        // UserDefaultsから設定を読み込み
        self.brokerHost = UserDefaults.standard.string(forKey: "mqtt_broker_host") ?? "192.168.1.34"
        self.brokerPort = UInt16(UserDefaults.standard.integer(forKey: "mqtt_broker_port")) == 0 ? 1883 : UInt16(UserDefaults.standard.integer(forKey: "mqtt_broker_port"))
        self.username = UserDefaults.standard.string(forKey: "mqtt_username") ?? "etokoji"
        self.password = UserDefaults.standard.string(forKey: "mqtt_password") ?? ""
        
        print("MQTT settings loaded from UserDefaults:")
        print("- Host: \(self.brokerHost)")
        print("- Port: \(self.brokerPort)")
        print("- Username: \(self.username)")
        print("- Password: \(self.password.isEmpty ? "not set" : "[\(self.password.count) characters]")")
    }
    
    // 設定画面からMQTT設定が更新された時に使用
    func updateSettings(host: String, port: UInt16, username: String, password: String) {
        self.brokerHost = host
        self.brokerPort = port
        self.username = username
        self.password = password
        
        // UserDefaultsに保存
        UserDefaults.standard.set(host, forKey: "mqtt_broker_host")
        UserDefaults.standard.set(Int(port), forKey: "mqtt_broker_port")
        UserDefaults.standard.set(username, forKey: "mqtt_username")
        UserDefaults.standard.set(password, forKey: "mqtt_password")
        
        print("MQTT settings updated and saved to UserDefaults:")
        print("- Host: \(host)")
        print("- Port: \(port)")
        print("- Username: \(username)")
        print("- Password: \(password.isEmpty ? "not set" : "[\(password.count) characters]")")
    }
    
    // 後方互換性のためにupdatePasswordメソッドを保持
    func updatePassword(_ newPassword: String) {
        self.password = newPassword
        UserDefaults.standard.set(newPassword, forKey: "mqtt_password")
        print("MQTT Password updated: \(newPassword.isEmpty ? "empty" : "[\(newPassword.count) characters]")")
    }
    
    func connect() {
        connectionAttempts += 1
        
        DispatchQueue.main.async {
            self.connectionStatus = "接続中... (\(self.connectionAttempts)/\(self.maxReconnectAttempts))"
        }
        
        let host = NWEndpoint.Host(brokerHost)
        let port = NWEndpoint.Port(rawValue: brokerPort)!
        
        // TCPパラメータを設定
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 10  // 10秒タイムアウト
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 30
        
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        parameters.allowLocalEndpointReuse = true
        
        connection = NWConnection(host: host, port: port, using: parameters)
        
        connection?.stateUpdateHandler = { state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("MQTT connected successfully")
                    self.isConnected = true
                    self.connectionStatus = "接続成功"
                    self.connectionAttempts = 0  // リセット
                    self.sendConnectPacket()
                case .failed(let error):
                    print("Connection failed: \(error)")
                    self.isConnected = false
                    self.connectionStatus = "接続失敗: \(error.localizedDescription)"
                    self.scheduleReconnect()
                case .cancelled:
                    print("Connection cancelled")
                    self.isConnected = false
                    self.connectionStatus = "接続キャンセル"
                case .waiting(let error):
                    print("Connection waiting: \(error)")
                    self.connectionStatus = "待機中: \(error.localizedDescription)"
                case .preparing:
                    self.connectionStatus = "接続準備中"
                case .setup:
                    self.connectionStatus = "セットアップ中"
                @unknown default:
                    self.connectionStatus = "不明な状態"
                }
            }
        }
        
        connection?.start(queue: queue)
    }
    
    func disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        connection?.cancel()
        isConnected = false
        connectionStatus = "切断"
        connectionAttempts = 0
    }
    
    private func scheduleReconnect() {
        guard connectionAttempts < maxReconnectAttempts else {
            DispatchQueue.main.async {
                self.connectionStatus = "接続上限回数に達しました"
            }
            return
        }
        
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            print("Attempting to reconnect...")
            self.connect()
        }
    }
    
    private func sendConnectPacket() {
        // 簡単なMQTT CONNECT パケットの実装
        // 実際の実装ではより詳細なMQTTプロトコルの実装が必要
        var packet = Data()
        
        // Fixed header
        packet.append(0x10) // CONNECT
        packet.append(0x00) // Remaining length (仮)
        
        // Variable header
        let protocolName = "MQTT"
        packet.append(UInt8(protocolName.count >> 8))
        packet.append(UInt8(protocolName.count & 0xFF))
        packet.append(protocolName.data(using: .utf8)!)
        packet.append(0x04) // Protocol level
        
        // Connect flags
        var connectFlags: UInt8 = 0x02 // Clean session
        if !username.isEmpty {
            connectFlags |= 0x80 // Username flag
        }
        if !password.isEmpty {
            connectFlags |= 0x40 // Password flag
        }
        packet.append(connectFlags)
        
        // Keep alive
        packet.append(0x00)
        packet.append(0x3C) // 60 seconds
        
        // Payload - 固有のClient IDを生成
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let clientId = "WaterPump-\(deviceId.prefix(8))"
        print("MQTT Client ID: \(clientId)")
        print("MQTT Username: \(username)")
        print("MQTT Password length: \(password.count) characters")
        print("MQTT Password empty: \(password.isEmpty)")
        print("MQTT Connection flags: 0b\(String(connectFlags, radix: 2).padding(toLength: 8, withPad: "0", startingAt: 0))")
        
        packet.append(UInt8(clientId.count >> 8))
        packet.append(UInt8(clientId.count & 0xFF))
        if let clientIdData = clientId.data(using: .utf8) {
            packet.append(clientIdData)
        }
        
        if !username.isEmpty {
            packet.append(UInt8(username.count >> 8))
            packet.append(UInt8(username.count & 0xFF))
            packet.append(username.data(using: .utf8)!)
        }
        
        if !password.isEmpty {
            packet.append(UInt8(password.count >> 8))
            packet.append(UInt8(password.count & 0xFF))
            packet.append(password.data(using: .utf8)!)
        }
        
        // Update remaining length
        let remainingLength = packet.count - 2
        packet[1] = UInt8(remainingLength)
        
        connection?.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                print("MQTT CONNECT send error: \(error)")
            } else {
                print("MQTT CONNECT packet sent successfully")
                // CONNACKを待つ
                self.waitForConnAck()
            }
        })
    }
    
    private func waitForConnAck() {
        // CONNACKメッセージを受信してからサブスクライブする
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4) { data, _, isComplete, error in
            if let data = data, data.count >= 2 {
                let messageType = data[0] >> 4
                if messageType == 2 { // CONNACK
                    let returnCode = data[3]
                    if returnCode == 0 {
                        print("MQTT CONNACK received - Connection accepted")
                        self.subscribeToLogs()
                    } else {
                        let errorMessage = self.getMQTTConnackError(returnCode)
                        print("MQTT CONNACK received - Connection refused: \(returnCode) (\(errorMessage))")
                        DispatchQueue.main.async {
                            self.connectionStatus = "認証失敗: \(errorMessage)"
                        }
                    }
                } else {
                    print("Unexpected MQTT message type: \(messageType)")
                }
            } else if let error = error {
                print("CONNACK receive error: \(error)")
            }
        }
    }
    
    private func subscribeToLogs() {
        print("Starting MQTT subscriptions...")
        // MQTT SUBSCRIBE パケットを送信
        subscribeToTopic("esp_log/#")
        subscribeToTopic("env/#")
    }
    
    private func subscribeToTopic(_ topic: String) {
        var packet = Data()
        
        // Fixed header
        packet.append(0x82) // SUBSCRIBE
        
        let topicData = topic.data(using: .utf8)!
        let remainingLength = 2 + 2 + topicData.count + 1 // packet id + topic length + topic + QoS
        packet.append(UInt8(remainingLength))
        
        // Variable header
        packet.append(0x00) // Packet ID (MSB)
        packet.append(0x01) // Packet ID (LSB)
        
        // Payload
        packet.append(UInt8(topicData.count >> 8))
        packet.append(UInt8(topicData.count & 0xFF))
        packet.append(topicData)
        packet.append(0x00) // QoS 0
        
        connection?.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                print("Subscribe error: \(error)")
            }
        })
        
        // メッセージの受信を開始
        receiveMessages()
    }
    
    private func receiveMessages() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self.processReceivedData(data)
            }
            
            if !isComplete && error == nil {
                self.receiveMessages() // 継続して受信
            }
        }
    }
    
    private func processReceivedData(_ data: Data) {
        // 簡単なMQTTメッセージの解析
        // 実際の実装ではより詳細なプロトコル解析が必要
        if data.count > 4 {
            let messageType = data[0] >> 4
            if messageType == 3 { // PUBLISH
                // メッセージの内容を抽出
                let topicLengthMSB = data[2]
                let topicLengthLSB = data[3]
                let topicLength = (Int(topicLengthMSB) << 8) + Int(topicLengthLSB)
                
                if data.count > 4 + topicLength {
                    let topicData = data.subdata(in: 4..<4+topicLength)
                    let topic = String(data: topicData, encoding: .utf8) ?? ""
                    
                    let messageData = data.subdata(in: 4+topicLength..<data.count)
                    let message = String(data: messageData, encoding: .utf8) ?? ""
                    
                    DispatchQueue.main.async {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        formatter.timeZone = TimeZone.current  // ローカル時間を使用
                        let timestamp = formatter.string(from: Date())
                        
                        if topic.hasPrefix("env/") && topic.contains("brightness") {
                            // 照度データの処理
                            self.processEnvironmentData(topic: topic, message: message, timestamp: timestamp)
                        } else {
                            // ポンプログの処理
                            let logEntry = "[\(timestamp)] \(topic) \(message)"
                            self.logs.append(logEntry)
                            
                            // 最新の50エントリのみ保持
                            if self.logs.count > 50 {
                                self.logs.removeFirst()
                            }
                        }
                    }
                }
            }
        }
    }
    
    func publishPWMLength(_ length: Int) {
        let topic = "esp_cfg/1"
        let message = "{ \"PWM_length\":\(length)}"
        publishMessage(topic: topic, message: message, retain: true)
    }
    
    private func processEnvironmentData(topic: String, message: String, timestamp: String) {
        // JSONデータをパース
        if let data = message.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let brightness = json["brightness"] as? Double,
                       let description = json["description"] as? String {
                        
                        // 照度データを更新
                        currentLightLevel = brightness
                        currentLightDescription = description
                        maxLightLevel = max(maxLightLevel, brightness)
                        minLightLevel = min(minLightLevel, brightness)
                        
                        // 平均値の計算
                        updateAverageLightLevel()
                        
                        // ログエントリを作成
                        let logEntry = "[\(timestamp)] \(topic) { \"brightness\": \(String(format: "%.2f", brightness)), \"description\": \"\(description)\" }"
                        lightLogs.append(logEntry)
                        
                        // 最新の50エントリのみ保持
                        if lightLogs.count > 50 {
                            lightLogs.removeFirst()
                        }
                    }
                }
            } catch {
                print("JSON parse error: \(error)")
            }
        }
    }
    
    private func updateAverageLightLevel() {
        // ログから照度値を抽出して平均値を計算
        let brightnessList = lightLogs.compactMap { log -> Double? in
            if let range = log.range(of: "\"brightness\": "),
               let endRange = log.range(of: ",", range: range) {
                let startIndex = range.upperBound
                let endIndex = endRange.lowerBound
                let brightnessString = String(log[startIndex..<endIndex])
                return Double(brightnessString)
            }
            return nil
        }
        
        if !brightnessList.isEmpty {
            averageLightLevel = brightnessList.reduce(0, +) / Double(brightnessList.count)
        }
    }
    
    private func publishMessage(topic: String, message: String, retain: Bool = false) {
        guard let topicData = topic.data(using: .utf8),
              let messageData = message.data(using: .utf8) else { return }
        
        var packet = Data()
        
        // Fixed header
        var flags: UInt8 = 0x30 // PUBLISH
        if retain {
            flags |= 0x01 // Retain flag
        }
        packet.append(flags)
        
        let remainingLength = 2 + topicData.count + messageData.count
        packet.append(UInt8(remainingLength))
        
        // Variable header
        packet.append(UInt8(topicData.count >> 8))
        packet.append(UInt8(topicData.count & 0xFF))
        packet.append(topicData)
        
        // Payload
        packet.append(messageData)
        
        connection?.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                print("Publish error: \(error)")
            }
        })
    }
    
    private func getMQTTConnackError(_ returnCode: UInt8) -> String {
        switch returnCode {
        case 0: return "接続成功"
        case 1: return "プロトコルバージョン不正"
        case 2: return "クライアントID不正"
        case 3: return "サーバー不利用"
        case 4: return "ユーザー名またはパスワード不正"
        case 5: return "認証拒否"
        default: return "不明なエラー(\(returnCode))"
        }
    }
}
