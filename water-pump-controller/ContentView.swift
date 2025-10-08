//
//  ContentView.swift
//  water-pump-controller
//
//  Created by 江藤公二 on 2025/10/08.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var mqttClient = MQTTClient()
    
    var body: some View {
        TabView {
            PumpLogView(mqttClient: mqttClient)
                .tabItem {
                    Image(systemName: "drop.fill")
                    Text("ポンプログ")
                }
            
            SettingsView(mqttClient: mqttClient)
                .tabItem {
                    Image(systemName: "gear")
                    Text("設定")
                }
            
            LightLogView(mqttClient: mqttClient)
                .tabItem {
                    Image(systemName: "sun.max")
                    Text("照度ログ")
                }
        }
        .onAppear {
            mqttClient.connect()
        }
    }
}

#Preview {
    ContentView()
}
