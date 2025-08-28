import SwiftUI

public struct ProxySettingsView: View {
    @ObservedObject private var proxySettings = ProxySettingsManager.shared
    @State private var showingTestAlert = false
    @State private var testResultMessage = ""
    @State private var testResultIsSuccess = false
    @State private var isTesting = false
    @State private var portString: String = ""
    
    public init() {}
    
    public var body: some View {
        Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 20) {
            GridRow {
                Text("settings.proxy.enable.label".localized())
                    .gridColumnAlignment(.trailing)
                Toggle("", isOn: $proxySettings.isProxyEnabled)
                    .labelsHidden()
                    .gridColumnAlignment(.leading)
            }
            
            GridRow {
                Text("settings.proxy.type.label".localized())
                
                Picker("", selection: $proxySettings.proxyType) {
                    ForEach(ProxyType.allCases, id: \.self) { type in
                        Text(type.localizedName).tag(type)
                    }
                }
                .frame(width: 300)
                .if(ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26) { view in
                    view.fixedSize()
                }
                .labelsHidden()
                .disabled(!proxySettings.isProxyEnabled)
            }
            
            GridRow {
                Text("settings.proxy.host.label".localized())
                    
                TextField("settings.proxy.host.placeholder".localized(), text: $proxySettings.proxyHost)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 300)
                    .disabled(!proxySettings.isProxyEnabled)
            }
            
            GridRow {
                Text("settings.proxy.port.label".localized())
                
                TextField("settings.proxy.port.placeholder".localized(), text: $portString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 300)
                    .disabled(!proxySettings.isProxyEnabled)
                    .onChange(of: portString) { _, newValue in
                        // 只允许数字输入，并限制在1-65535范围内
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            portString = filtered
                        }
                        if let port = Int(filtered), port >= 1 && port <= 65535 {
                            proxySettings.proxyPort = port
                        }
                    }
                    .onAppear {
                        portString = String(proxySettings.proxyPort)
                    }
            }
            
            GridRow {
                Button("settings.proxy.test.button".localized()) {
                    testProxyConnection()
                }
                .disabled(!proxySettings.isProxyEnabled || !proxySettings.configuration.isValid || isTesting)
                .gridCellColumns(2)
                
                if isTesting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.leading, 8)
                }
            }
        }
        .alert("settings.proxy.test.title".localized(), isPresented: $showingTestAlert) {
            Button("common.ok".localized()) { }
        } message: {
            Text(testResultMessage)
        }
    }
    
    private func testProxyConnection() {
        isTesting = true
        testResultMessage = ""
        
        proxySettings.testProxyConnection { result in
            DispatchQueue.main.async {
                self.isTesting = false
                switch result {
                case .success:
                    self.testResultMessage = "settings.proxy.test.success".localized()
                    self.testResultIsSuccess = true
                case .failure(let error):
                    var errorMsg = "settings.proxy.test.failure".localized()
                    
                    // 提供更详细的错误信息
                    if let globalError = error as? GlobalError {
                        errorMsg += ": \(globalError.localizedDescription)"
                    } else if let urlError = error as? URLError {
                        switch urlError.code {
                        case .timedOut:
                            errorMsg += ": " + "settings.proxy.error.timeout".localized()
                        case .cannotConnectToHost:
                            errorMsg += ": " + "settings.proxy.error.cannot_connect".localized()
                        case .notConnectedToInternet:
                            errorMsg += ": " + "settings.proxy.error.network_unavailable".localized()
                        case .badServerResponse:
                            errorMsg += ": " + "settings.proxy.error.bad_response".localized()
                        default:
                            errorMsg += ": \(urlError.localizedDescription)"
                        }
                    } else {
                        errorMsg += ": \(error.localizedDescription)"
                    }
                    
                    self.testResultMessage = errorMsg
                    self.testResultIsSuccess = false
                }
                self.showingTestAlert = true
            }
        }
    }
}

#Preview {
    ProxySettingsView()
}
