//
//  FileManagerView.swift
//  HamsterApp
//
//  Created by morse on 14/3/2023.
//

import iFilemanager
import Network
import SwiftUI
import UIKit

struct FileManagerView: View {
  let fileServer = FileServer(
    port: 80,
    publicDirectory: RimeEngine.shareURL
  )
  let monitor: NWPathMonitor = .init(requiredInterfaceType: .wifi)

  @State var isBoot: Bool = false
  @State var localIP: String = ""
  @State var wifiEnable: Bool = true

  @EnvironmentObject
  var rimeEngine: RimeEngine

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Color.HamsterBackgroundColor.opacity(0.1).ignoresSafeArea()

        VStack {
          HStack {
            Text("文件快传")
              .font(.system(size: 30, weight: .black))

            Spacer()
          }
          .padding(.horizontal)

          VStack(alignment: .leading) {
            Text("注意: 此功能需要开启WiFi网络访问权限(只需Wifi即可, 无需移动网络权限). 因需使用局域上传个人输入方案.")
              .font(.system(size: 18, weight: .bold, design: .rounded))
            if wifiEnable {
              Group {
                Text("1. 请在与您手机处与同一局域网内的PC浏览器上打开下面的IP地址.")
                Text("")

                Text(" - http://\(localIP)")
                  .padding(.leading, 20)

                Text("")
                Text("2. 将您的个人输入方案上传至文件夹内")
                Text("")
                Text("上传完毕请务必点击主菜单中的\"重新部署\", 否则方案不会生效.")
              }
              .font(.system(size: 18, weight: .bold, design: .rounded))
              .foregroundColor(.primary)
            } else {
              Text("WiFi网络不可用, 请打开WiFi或开启Wifi网络访问权限")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            }
          }
          .padding(.top, 30)
          .padding(.leading, 10)

          LongButton(buttonText: !isBoot ? "启动" : "停止") {
            isBoot.toggle()
            if isBoot {
              fileServer.start()
            } else {
              fileServer.shutdown()
            }
          }
          .padding(.top, 30)
          .disabled(wifiEnable == false)

          Spacer()
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
        .onAppear {
          rimeEngine.shutdownRime()

          let localIPs = UIDevice.current.localIP()
          if localIPs.count == 1 {
            localIP = localIPs[0].1
          }
          monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
              wifiEnable = true
              for (name, ip) in localIPs {
                let name = path.availableInterfaces
                  .map { $0.name }
                  .first { $0 == name }
                if name != nil {
                  localIP = ip
                }
              }
              return
            }
            wifiEnable = false
          }

          let queue = DispatchQueue.global(qos: .background)
          monitor.start(queue: queue)
        }
        .onDisappear {
          rimeEngine.startRime()
          fileServer.shutdown()
          monitor.cancel()
        }
      }
    }
  }
}

extension UIDevice {
  /**
   Returns device ip address. Nil if connected via celluar.
   */
  func localIP() -> [(String, String)] {
    var address: [(String, String)] = []
    var ifaddr: UnsafeMutablePointer<ifaddrs>?

    if getifaddrs(&ifaddr) == 0 {
      var ptr = ifaddr
      while ptr != nil {
        defer { ptr = ptr?.pointee.ifa_next } // memory has been renamed to pointee in swift 3 so changed memory to pointee

        guard let interface = ptr?.pointee else {
          return address
        }
        let addrFamily = interface.ifa_addr.pointee.sa_family
        if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
          guard let ifa_name = interface.ifa_name else {
            return address
          }
          let name = String(cString: ifa_name)

          if name.hasPrefix("en") { // String.fromCString() is deprecated in Swift 3. So use the following code inorder to get the exact IP Address.
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
              interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname,
              socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST
            )
            let addr = String(cString: hostname)
            if !addr.contains("en") {
              address.append((name, addr))
            }
          }
        }
      }
      freeifaddrs(ifaddr)
    }

    return address
  }
}

struct FileManagerView_Previews: PreviewProvider {
  static var previews: some View {
    FileManagerView()
  }
}
