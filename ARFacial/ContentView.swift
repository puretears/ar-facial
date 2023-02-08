//
//  ContentView.swift
//  ARFacial
//
//  Created by Mars on 2023/2/8.
//

import SwiftUI
import RealityKit
import ARKit

struct ContentView : View {
  @State var propId: Int = 0
  
  var body: some View {
    ZStack(alignment: .bottom) {
      ARViewContainer(propId: $propId).edgesIgnoringSafeArea(.all)
      
      buildButtons()
    }
  }
  
  func buildButtons() -> some View {
    HStack {
      Spacer()
      
      Button(action: {
        self.propId = self.propId <= 0 ? 0 : self.propId - 1
      }, label: {
        Image(systemName: "arrowtriangle.left.fill")
          .resizable()
          .frame(width: 20, height: 20)
          .foregroundColor(.white)
      })
      
      Spacer()
      
      Button(action: {
        takeSnapshot()
        print("Saved to Photos")
      }, label: {
        ZStack {
          Circle()
            .stroke(Color.white, lineWidth: 2)
            .frame(width: 60, height: 60)
            .foregroundColor(.white)
          
          Circle()
            .foregroundColor(.white)
            .frame(width: 52, height: 52)
        }
      })
      
      Spacer()
      
      Button(action: {
        self.propId = self.propId >= 3 ? 3 : self.propId + 1
      }, label: {
        Image(systemName: "arrowtriangle.right.fill")
          .resizable()
          .frame(width: 20, height: 20)
          .foregroundColor(.white)
      })
      
      Spacer()
    }
  }
  
  
  func takeSnapshot() {
    arView.snapshot(saveToHDR: false) { image in
      let compressedImage = UIImage(data: (image?.pngData())!)
      UIImageWriteToSavedPhotosAlbum(compressedImage!, nil, nil, nil)
    }
  }
}

var arView: ARView!
var robot: Experience.Robot!

struct ARViewContainer: UIViewRepresentable {
  @Binding var propId: Int
    
  func makeUIView(context: Context) -> ARView {
    arView = ARView(frame: .zero)
    arView.session.delegate = context.coordinator
    
    return arView
  }
  
  func updateUIView(_ uiView: ARView, context: Context) {
    uiView.scene.anchors.removeAll()
    robot = nil
    
    let arConfig = ARFaceTrackingConfiguration()
    uiView.session.run(arConfig, options: [.resetTracking, .removeExistingAnchors])
    
    switch (propId) {
    case 0: // Eyes
      let arAnchor = try! Experience.loadEyes()
      uiView.scene.anchors.append(arAnchor)
      break
    case 1: // Glasses
      let arAnchor = try! Experience.loadGlasses()
      uiView.scene.anchors.append(arAnchor)
      break
    case 2: // Mustache
      let arAnchor = try! Experience.loadMustache()
      uiView.scene.anchors.append(arAnchor)
      break
    case 3: // Mustache
      robot = try! Experience.loadRobot()
      uiView.scene.anchors.append(robot)
      break
    default:
      break
    }
  }
  
  func makeCoordinator() -> ARDelegate {
    ARDelegate(self)
  }
}

class ARDelegate: NSObject, ARSessionDelegate {
  var arViewContainer: ARViewContainer
  var isLasersDone = true
  
  init(_ container: ARViewContainer) {
    self.arViewContainer = container
    super.init()
  }
  
  func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    guard robot != nil else { return }
    
    var faceAnchor: ARFaceAnchor?
    
    for anchor in anchors {
      if let a = anchor as? ARFaceAnchor {
        faceAnchor = a
      }
    }
    
    let blendShapes = faceAnchor?.blendShapes
    
    let eyeBlinkLeft = blendShapes?[.eyeBlinkLeft]?.floatValue
    let eyeBlinkRight = blendShapes?[.eyeBlinkRight]?.floatValue
    
    let browInnerUp = blendShapes?[.browInnerUp]?.floatValue
    let browLeft = blendShapes?[.browDownLeft]?.floatValue
    let browRight = blendShapes?[.browDownRight]?.floatValue
    
    let jawOpen = blendShapes?[.jawOpen]?.floatValue
    
    robot.robotEyeLidL?.orientation = simd_mul(
      // 2
      simd_quatf(
        angle: Deg2Rad(-120 + (90 * eyeBlinkLeft!)),
        axis: [1, 0, 0]
      ),
      // 3
      simd_quatf(
        angle: Deg2Rad((90 * browLeft!) - (30 * browInnerUp!)),
        axis: [0, 0, 1]
      )
    )
    // 4
    robot.robotEyeLidR?.orientation = simd_mul(
      simd_quatf(
        angle: Deg2Rad(-120 + (90 * eyeBlinkRight!)),
        axis: [1, 0, 0]
      ),
      
      simd_quatf(
        angle: Deg2Rad((-90 * browRight!) - (-30 * browInnerUp!)),
        axis: [0, 0, 1]
      )
    )
    
    robot.robotJaw?.orientation = simd_quatf(
      angle: Deg2Rad(-100 + (60 * jawOpen!)), axis: [1, 0, 0]
    )
    
    if isLasersDone && jawOpen! > 0.8 {
      isLasersDone = false
      
      robot.notifications.fireLasers.post()
      
      robot.actions.lasersDone.onAction = { _ in
        self.isLasersDone = true
      }
    }
  }
  
  func Deg2Rad(_ value: Float) -> Float {
    return value * .pi / 180
  }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
#endif
