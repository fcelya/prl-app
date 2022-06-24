//
//  InterfaceController.swift
//  test-4 WatchKit Extension
//
//  Created by Library User on 2/15/22.
//

import WatchKit
import Foundation
import HealthKit
import CoreMotion
import UIKit


class InterfaceController: WKInterfaceController, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate{
    
    //Device configuration
    let deviceID = "test_dev2"
    
    // INTERFACE
    @IBOutlet var startStopButton: WKInterfaceButton!
    @IBOutlet var bpmLabel: WKInterfaceLabel!
    @IBOutlet var buttonGroup: WKInterfaceGroup!
    @IBOutlet weak var labelGroup: WKInterfaceGroup!
    var buttonText = "Start"
    
    //FLOW CONTROL
    enum possibleAppStates{
        case welcome
        case activeWorkout
        case activeNotWorkout
        case emergency
        case stopped
    }
    var appState = possibleAppStates.welcome
    var appStateChangeTime: Int64 = 0
    let maxWorkoutTime = 15
    let timeBetweenWorkouts = 30
    
    //NETWORKING
    //Server url
    //let serverUrl: URL = URL(string: "https://ptsv2.com/t/mz9qr-1646956188/post")!
    //let serverUrl: URL = URL(string: "https://ptsv2.com/t/0l8up-1651632300/post")!
    let serverUrl: URL = URL(string: "http://34.200.242.230/post")!
    
    
    //MOVEMENT
    let motion = CMMotionManager()
    let motionRefreshRate = 1
    
    //HEALTH INFO
    // Our workout session
    var session: HKWorkoutSession!
    // Live workout builder
    var builder: HKLiveWorkoutBuilder!
    // Tracking our workout state
    var state: HKWorkoutSessionState = .notStarted
    // Access point for all data managed by HealthKit.
    let healthStore = HKHealthStore()
    //ecg
    var ECG: HKElectrocardiogram?
    
    //CREATE DATA STRUCTURES
    var ecgDict: Dictionary<String, [String: [Any]]> = ["type": ["type": ["ecg"], "device id":[]],
                                                        "data": ["ecg": [],
                                                                 "timestamp": []]]

    var motionDict: Dictionary<String, [String: [Any]]> = ["type": ["type":["motion"], "device id":[]],
                                                          "data": ["accx":[],
                                                                   "accy":[],
                                                                   "accz":[],
                                                                   "gyrx":[],
                                                                   "gyry":[],
                                                                   "gyrz":[],
                                                                   "grvx":[],
                                                                   "grvy":[],
                                                                   "grvz":[],
                                                                   "timestamp":[]]]

    var workoutDict: Dictionary<String, [String: [Any]]> = ["type": ["type": ["health"], "device id":[]],
          "data": ["Heart Rate": [],
                   "Active Energy Burned": [],
                   "Basal Energy Burned": [],
                   "Apple Stand Time": [],
                   "Apple Walking Steadiness": [],
                   "Environmental Audio Exposure": [],
                   "Heart Rate Variability": [],
                   "Oxygen Saturation": [],
                   "Body Temperature": [],
                   "Blood Pressure Systolic": [],
                   "Blood Pressure Dyastolic": [],
                   "Respiratory Rate": [],
                   "Distance Walked": []
                  ]]
    
    override func awake(withContext context: Any?) {
        // Configure interface objects here.
        super.awake(withContext: context)
        
        // var healthDataCollected = false
        // TODO: Add condition that workout stops when all data has been collected
        startMotionCollection()
        //Check for motion data
        Timer.scheduledTimer(withTimeInterval: TimeInterval(motionRefreshRate), repeats: true){_ in
            if self.appState == possibleAppStates.activeWorkout{
                if let data = self.motion.deviceMotion{
                    print("[Motion] x: \(data.userAcceleration.x)) y: \(data.userAcceleration.y) z: \(data.userAcceleration.z)")
                    self.motionDict["data"]!["accx"]!.append(data.userAcceleration.x)
                    self.motionDict["data"]!["accy"]!.append(data.userAcceleration.y)
                    self.motionDict["data"]!["accz"]!.append(data.userAcceleration.z)
                    self.motionDict["data"]!["gyrx"]!.append(data.rotationRate.x)
                    self.motionDict["data"]!["gyry"]!.append(data.rotationRate.y)
                    self.motionDict["data"]!["gyrz"]!.append(data.rotationRate.z)
                    self.motionDict["data"]!["grvx"]!.append(data.gravity.x)
                    self.motionDict["data"]!["grvy"]!.append(data.gravity.y)
                    self.motionDict["data"]!["grvz"]!.append(data.gravity.z)
                    self.motionDict["data"]!["timestamp"]!.append(Int64(NSDate().timeIntervalSince1970))
                }else{
                    print("[Motion]: No motion data available")
                }
            }
            
            //Check If workout should be stopped or activated
            switch self.appState{
            case .activeWorkout:
                if Int64(NSDate().timeIntervalSince1970) - self.appStateChangeTime > self.maxWorkoutTime{
                    self.bpmLabel!.setText("---")
                    DispatchQueue.main.async() {
                        self.sendAndSave()
                    }
                    self.stopWorkout()
                }
            case .activeNotWorkout:
                if Int64(NSDate().timeIntervalSince1970) - self.appStateChangeTime > self.timeBetweenWorkouts{
                    self.startWorkout()
                }
            default:
                break
            }
        }
    }
    
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        
        labelGroup.setRelativeHeight(0,withAdjustment: 0)
        buttonGroup.setRelativeHeight(1,withAdjustment: 0)
        
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .appleStandTime)!,
            HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)!,
            HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.electrocardiogramType()
        ]
        //have to add correlationtype.bloodpressure, categorytype.irregularheartrythm,
        //categorytype.highheartrateevent, categorytype.lowheartrateevent, electrocardiogramtype
        //Apparently bloodpressure is propietary to Apple and not allowed to be read. (NSException*) "Authorization
        // to read the following types is disallowed: HKCorrelationTypeIdentifierBloodPressure
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in if !success {
                fatalError("Error requesting authorization from health store: \(String(describing: error)))")
            }
        }
        self.workoutDict["type"]!["device id"]!.append(deviceID)
        self.motionDict["type"]!["device id"]!.append(deviceID)
        self.ecgDict["type"]!["device id"]!.append(deviceID)
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }
    
    func startMotionCollection(){
        //Start recollecting motion data
        let queue = OperationQueue()
        queue.name = "motionqueue"
        queue.maxConcurrentOperationCount = 1
        motion.deviceMotionUpdateInterval = 0.2
        motion.startDeviceMotionUpdates(to: queue) { (data: CMDeviceMotion?, error: Error?) in
            if error != nil {
                            print("Encountered error: \(error!)")
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
            didChangeTo toState: HKWorkoutSessionState,
                   from fromState: HKWorkoutSessionState,
                        date: Date){
        print("[workoutSession] Changed State: from \(fromState.rawValue) to \(toState.rawValue)")
    }
    
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("[workoutSession] Encountered an error: \(error)")
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        
        var HRstringValue: String = "0"
        var AEBstringValue: String = "0"
        var BEBstringValue: String = "0"
        var DWstringValue: String = "0"
        var ASTstringValue: String = "0"
        var AWSstringValue: String = "0"
        var EAEstringValue: String = "0"
        var HRVstringValue: String = "0"
        var OSstringValue: String = "0"
        var BTstringValue: String = "0"
        var BPSstringValue: String = "0"
        var BPDstringValue: String = "0"
        var RRstringValue: String = "0"
        let rateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let energyUnit = HKUnit.largeCalorie()
        let distanceUnit = HKUnit.meter()
        let timeUnit = HKUnit.second()
        let percentUnit = HKUnit.percent()
        let soundUnit = HKUnit.decibelAWeightedSoundPressureLevel()
        let temperatureUnit = HKUnit.degreeCelsius()
        let pressureUnit = HKUnit.pascal()
        
        
        
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else {
                return // Nothing to do.
            }
            
            // Calculate statistics for the type.
            switch quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: rateUnit)
                    HRstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Heart Rate"]!.append(Double(round(1 * value!) / 1))
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: energyUnit)
                    AEBstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Active Energy Burned"]!.append(Double(round(1 * value!) / 1))
                case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: distanceUnit)
                    DWstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Basal Energy Burned"]!.append(Double(round(1 * value!) / 1))
                case HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: energyUnit)
                    BEBstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Distance Walked"]!.append(Double(round(1 * value!) / 1))
                case HKQuantityType.quantityType(forIdentifier: .appleStandTime):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: timeUnit)
                    ASTstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Apple Stand Time"]!.append(Double(round(1 * value!) / 1))
                case HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: percentUnit)
                    AWSstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Apple Walking Steadiness"]!.append(Double(round(1 * value!) / 1))
                case HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: soundUnit)
                    EAEstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Environmental Audio Exposure"]!.append(Double(round(1 * value!) / 1))
                case HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: timeUnit)
                    HRVstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Heart Rate Variability"]!.append(Double(round(1 * value!) / 1))
                case HKQuantityType.quantityType(forIdentifier: .oxygenSaturation):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: percentUnit)
                    OSstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Oxygen Saturation"]!.append(Double(round(1 * value!) / 1))
                case HKQuantityType.quantityType(forIdentifier: .bodyTemperature):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: temperatureUnit)
                    BTstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Body Temperature"]!.append(Double(round(1 * value!) / 1))
                case HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: pressureUnit)
                    BPSstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Blood Pressure Systolic"]!.append(Double(round(1 * value!) / 1))
                case HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: pressureUnit)
                    BPDstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Blood Pressure Dyastolic"]!.append(Double(round(1 * value!) / 1))
                case HKQuantityType.quantityType(forIdentifier: .respiratoryRate):
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: rateUnit)
                    RRstringValue = String(Int(Double(round(1 * value!) / 1)))
                    workoutDict["data"]!["Respiratory Rate"]!.append(Double(round(1 * value!) / 1))
                default:
                    return
            }
        }
        DispatchQueue.main.async() { [self] in
            if HRstringValue != "0" {
                self.bpmLabel.setText(HRstringValue)
            }
            print("[workoutBuilder] Heart Rate: \(String(describing: HRstringValue))")
            print("[workoutBuilder] Active Energy Burned: \(String(describing: AEBstringValue))")
            print("[workoutBuilder] Basal Energy Burned: \(String(describing: BEBstringValue))")
            print("[workoutBuilder] Distance Walked: \(String(describing: DWstringValue))")
            print("[workoutBuilder] Apple Stand Time: \(String(describing: ASTstringValue))")
            print("[workoutBuilder] Apple Walking Steadiness: \(String(describing: AWSstringValue))")
            print("[workoutBuilder] Environmental Audio Exposure: \(String(describing: EAEstringValue))")
            print("[workoutBuilder] Heart Rate Variability: \(String(describing: HRVstringValue))")
            print("[workoutBuilder] Oxygen Saturation: \(String(describing: OSstringValue))")
            print("[workoutBuilder] Body Temperature: \(String(describing: BTstringValue))")
            print("[workoutBuilder] Blood Pressure Systolic: \(String(describing: BPSstringValue))")
            print("[workoutBuilder] Blood Pressure Dyastolic: \(String(describing: BPDstringValue))")
            print("[workoutBuilder] Respiratory Rate: \(String(describing: RRstringValue))")
        }
    }
        
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Retreive the workout event.
        guard let workoutEventType = workoutBuilder.workoutEvents.last?.type else { return }
        print("[workoutBuilderDidCollectEvent] Workout Builder changed event: \(workoutEventType.rawValue)")
    }
    
    func initWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .crossTraining
        configuration.locationType = .outdoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session.associatedWorkoutBuilder()
        } catch {
            fatalError("Unable to create the workout session!")
        }
        
        // Setup session and builder.
        session.delegate = self
        builder.delegate = self
        
        /// Set the workout builder's data source.
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                     workoutConfiguration: configuration)
    }
    
    
    func startWorkout() {
        // Initialize our workout
        initWorkout()
        print("[Workout Started]")
        
        // Start the workout session and begin data collection
        session.startActivity(with: Date())
        builder.beginCollection(withStart: Date()) { (succ, error) in
            if !succ {
                fatalError("Error beginning collection from builder: \(String(describing: error)))")
            }
        }
        state = HKWorkoutSessionState.running
        appState = possibleAppStates.activeWorkout
        appStateChangeTime = Int64(NSDate().timeIntervalSince1970)
        
    }
    
    
    func stopWorkout() {
            // Stop the workout session
        if session != nil{
            session.end()
            builder.endCollection(withEnd: Date()) { (success, error) in
                self.builder.finishWorkout { (workout, error) in
                    DispatchQueue.main.async() {
                        self.session = nil
                        self.builder = nil
                    }
                }
            }
            print("[Workout Stopped]")
            state = HKWorkoutSessionState.stopped
            appState = possibleAppStates.activeNotWorkout
            appStateChangeTime = Int64(NSDate().timeIntervalSince1970)
            }
        }
    @IBAction func buttonPressed() {
        
        switch appState {
        case .welcome:
            labelGroup.setRelativeHeight(0.5,withAdjustment: 0)
            buttonGroup.setRelativeHeight(0.5,withAdjustment: 0)
            startWorkout()
            getSendECG()
            appState = possibleAppStates.activeWorkout
            startStopButton!.setTitle("Exit")
        case .activeWorkout:
            stopWorkout()
            appState = possibleAppStates.welcome
            DispatchQueue.main.async() {
                self.sendAndSave()
            }
            bpmLabel!.setText("---")
            startStopButton!.setTitle("Start")
            labelGroup.setRelativeHeight(0,withAdjustment: 0)
            buttonGroup.setRelativeHeight(1,withAdjustment: 0)
        case .activeNotWorkout:
            appState = possibleAppStates.welcome
            startStopButton!.setTitle("Start")
            labelGroup.setRelativeHeight(0,withAdjustment: 0)
            buttonGroup.setRelativeHeight(1,withAdjustment: 0)
        case .emergency:
            break
        case .stopped:
            break
        }
    }
}


class InterfaceControllerWarning: WKInterfaceController{
    
    enum possibleAppStates{
        case welcome
        case activeWorkout
        case activeNotWorkout
        case emergency
        case stopped
    }
    
    override func awake(withContext context: Any?) {
        // Configure interface objects here.
        super.awake(withContext: context)
    }
    
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }
    
    @IBAction func descansarButton() {
        pushController(withName: "main", context: nil)
    }
    
    @IBAction func seguirButton() {
        pushController(withName: "main", context: nil)
    }

}


class InterfaceControllerAlert: WKInterfaceController{

    enum possibleAppStates{
        case welcome
        case activeWorkout
        case activeNotWorkout
        case emergency
        case stopped
    }

    override func awake(withContext context: Any?) {
        // Configure interface objects here.
        super.awake(withContext: context)
    }


    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }

    @IBAction func ayudaButton() {
        pushController(withName: "caida", context: nil)
    }

    @IBAction func bienButton() {
        pushController(withName: "main", context: nil)
    }
}

class InterfaceControllerAvisando: WKInterfaceController{
    
    enum possibleAppStates{
        case welcome
        case activeWorkout
        case activeNotWorkout
        case emergency
        case stopped
    }
    
    func awake(withContext context: Dictionary<String,Any>?) {
        // Configure interface objects here.
        super.awake(withContext: context)
    }
    
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }
    let context = ["state":possibleAppStates.emergency,"buttonText":"XX"] as [String : Any]
    @IBAction func arregladoButton() {
        pushController(withName: "main", context:context)
    }
}

class InterfaceControllerDescansando: WKInterfaceController{
    
    enum possibleAppStates{
        case welcome
        case activeWorkout
        case activeNotWorkout
        case emergency
        case stopped
    }
    
    func awake(withContext context: Dictionary<String,Any>?) {
        // Configure interface objects here.
        super.awake(withContext: context)
    }
    
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }
    @IBAction func arregladoButton() {
        pushController(withName: "main", context:nil)
    }
}



//class InterfaceControllerAlert: WKInterfaceController, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate{
//    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
//        <#code#>
//    }
//
//    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
//        <#code#>
//    }
//
//    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
//        <#code#>
//    }
//
//    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
//        <#code#>
//    }
//
//
//    //Device configuration
//    let deviceID = "test_dev2"
//
//    //FLOW CONTROL
//    enum possibleAppStates{
//        case welcome
//        case activeWorkout
//        case activeNotWorkout
//        case emergency
//        case stopped
//    }
//    var appState = possibleAppStates.activeWorkout
//
//
//    //NETWORKING
//    //Server url
//    //let serverUrl: URL = URL(string: "https://ptsv2.com/t/mz9qr-1646956188/post")!
//    //let serverUrl: URL = URL(string: "https://ptsv2.com/t/0l8up-1651632300/post")!
//    let serverUrl: URL = URL(string: "http://34.200.242.230/post")!
//    let sendRate = 15
//
//    //MOVEMENT
//    let motion = CMMotionManager()
//    let motionRefreshRate = 1
//
//    //HEALTH INFO
//    // Our workout session
//    var session: HKWorkoutSession!
//    // Live workout builder
//    var builder: HKLiveWorkoutBuilder!
//    // Tracking our workout state
//    var state: HKWorkoutSessionState = .running
//    // Access point for all data managed by HealthKit.
//    let healthStore = HKHealthStore()
//    //ecg
//    var ECG: HKElectrocardiogram?
//
//    //CREATE DATA STRUCTURES
//
//    var motionDict: Dictionary<String, [String: [Any]]> = ["type": ["type":["motion"], "device id":[]],
//                                                          "data": ["accx":[],
//                                                                   "accy":[],
//                                                                   "accz":[],
//                                                                   "gyrx":[],
//                                                                   "gyry":[],
//                                                                   "gyrz":[],
//                                                                   "grvx":[],
//                                                                   "grvy":[],
//                                                                   "grvz":[],
//                                                                   "timestamp":[]]]
//
//    var workoutDict: Dictionary<String, [String: [Any]]> = ["type": ["type": ["health"], "device id":[]],
//          "data": ["Heart Rate": [],
//                   "Active Energy Burned": [],
//                   "Basal Energy Burned": [],
//                   "Apple Stand Time": [],
//                   "Apple Walking Steadiness": [],
//                   "Environmental Audio Exposure": [],
//                   "Heart Rate Variability": [],
//                   "Oxygen Saturation": [],
//                   "Body Temperature": [],
//                   "Blood Pressure Systolic": [],
//                   "Blood Pressure Dyastolic": [],
//                   "Respiratory Rate": [],
//                   "Distance Walked": []
//                  ]]
//
//    override func awake(withContext context: Any?) {
//        // Configure interface objects here.
//        super.awake(withContext: context)
//
//        // var healthDataCollected = false
//        // TODO: Add condition that workout stops when all data has been collected
//        startMotionCollection()
//        startWorkout()
//        //Check for motion data
//        Timer.scheduledTimer(withTimeInterval: TimeInterval(motionRefreshRate), repeats: true){_ in
//            if self.appState == possibleAppStates.activeWorkout{
//                if let data = self.motion.deviceMotion{
//                    print("[Motion] x: \(data.userAcceleration.x)) y: \(data.userAcceleration.y) z: \(data.userAcceleration.z)")
//                    self.motionDict["data"]!["accx"]!.append(data.userAcceleration.x)
//                    self.motionDict["data"]!["accy"]!.append(data.userAcceleration.y)
//                    self.motionDict["data"]!["accz"]!.append(data.userAcceleration.z)
//                    self.motionDict["data"]!["gyrx"]!.append(data.rotationRate.x)
//                    self.motionDict["data"]!["gyry"]!.append(data.rotationRate.y)
//                    self.motionDict["data"]!["gyrz"]!.append(data.rotationRate.z)
//                    self.motionDict["data"]!["grvx"]!.append(data.gravity.x)
//                    self.motionDict["data"]!["grvy"]!.append(data.gravity.y)
//                    self.motionDict["data"]!["grvz"]!.append(data.gravity.z)
//                    self.motionDict["data"]!["timestamp"]!.append(Int64(NSDate().timeIntervalSince1970))
//                }else{
//                    print("[Motion]: No motion data available")
//                }
//            }
//        }
//
//        Timer.scheduledTimer(withTimeInterval: TimeInterval(sendRate), repeats: true){_ in
//            if self.appState == possibleAppStates.activeWorkout{
//                sendAndSave()
//
//    }
//
//
//    override func willActivate() {
//        // This method is called when watch view controller is about to be visible to user
//        self.workoutDict["type"]!["device id"]!.append(deviceID)
//        self.motionDict["type"]!["device id"]!.append(deviceID)
//    }
//
//    override func didDeactivate() {
//        // This method is called when watch view controller is no longer visible
//    }
//
//    func startMotionCollection(){
//        //Start recollecting motion data
//        let queue = OperationQueue()
//        queue.name = "motionqueue"
//        queue.maxConcurrentOperationCount = 1
//        motion.deviceMotionUpdateInterval = 0.2
//        motion.startDeviceMotionUpdates(to: queue) { (data: CMDeviceMotion?, error: Error?) in
//            if error != nil {
//                            print("Encountered error: \(error!)")
//            }
//        }
//    }
//
//    func workoutSession(_ workoutSession: HKWorkoutSession,
//            didChangeTo toState: HKWorkoutSessionState,
//                   from fromState: HKWorkoutSessionState,
//                        date: Date){
//        print("[workoutSession] Changed State: from \(fromState.rawValue) to \(toState.rawValue)")
//    }
//
//
//    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
//        print("[workoutSession] Encountered an error: \(error)")
//    }
//
//    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
//
//        var HRstringValue: String = "0"
//        var AEBstringValue: String = "0"
//        var BEBstringValue: String = "0"
//        var DWstringValue: String = "0"
//        var ASTstringValue: String = "0"
//        var AWSstringValue: String = "0"
//        var EAEstringValue: String = "0"
//        var HRVstringValue: String = "0"
//        var OSstringValue: String = "0"
//        var BTstringValue: String = "0"
//        var BPSstringValue: String = "0"
//        var BPDstringValue: String = "0"
//        var RRstringValue: String = "0"
//        let rateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
//        let energyUnit = HKUnit.largeCalorie()
//        let distanceUnit = HKUnit.meter()
//        let timeUnit = HKUnit.second()
//        let percentUnit = HKUnit.percent()
//        let soundUnit = HKUnit.decibelAWeightedSoundPressureLevel()
//        let temperatureUnit = HKUnit.degreeCelsius()
//        let pressureUnit = HKUnit.pascal()
//
//
//
//        for type in collectedTypes {
//            guard let quantityType = type as? HKQuantityType else {
//                return // Nothing to do.
//            }
//
//            // Calculate statistics for the type.
//            switch quantityType {
//                case HKQuantityType.quantityType(forIdentifier: .heartRate):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: rateUnit)
//                    HRstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Heart Rate"]!.append(Double(round(1 * value!) / 1))
//                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: energyUnit)
//                    AEBstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Active Energy Burned"]!.append(Double(round(1 * value!) / 1))
//                case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: distanceUnit)
//                    DWstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Basal Energy Burned"]!.append(Double(round(1 * value!) / 1))
//                case HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: energyUnit)
//                    BEBstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Distance Walked"]!.append(Double(round(1 * value!) / 1))
//                case HKQuantityType.quantityType(forIdentifier: .appleStandTime):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: timeUnit)
//                    ASTstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Apple Stand Time"]!.append(Double(round(1 * value!) / 1))
//                case HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: percentUnit)
//                    AWSstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Apple Walking Steadiness"]!.append(Double(round(1 * value!) / 1))
//                case HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: soundUnit)
//                    EAEstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Environmental Audio Exposure"]!.append(Double(round(1 * value!) / 1))
//                case HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: timeUnit)
//                    HRVstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Heart Rate Variability"]!.append(Double(round(1 * value!) / 1))
//                case HKQuantityType.quantityType(forIdentifier: .oxygenSaturation):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: percentUnit)
//                    OSstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Oxygen Saturation"]!.append(Double(round(1 * value!) / 1))
//                case HKQuantityType.quantityType(forIdentifier: .bodyTemperature):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: temperatureUnit)
//                    BTstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Body Temperature"]!.append(Double(round(1 * value!) / 1))
//                case HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: pressureUnit)
//                    BPSstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Blood Pressure Systolic"]!.append(Double(round(1 * value!) / 1))
//                case HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: pressureUnit)
//                    BPDstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Blood Pressure Dyastolic"]!.append(Double(round(1 * value!) / 1))
//                case HKQuantityType.quantityType(forIdentifier: .respiratoryRate):
//                    let statistics = workoutBuilder.statistics(for: quantityType)
//                    let value = statistics!.mostRecentQuantity()?.doubleValue(for: rateUnit)
//                    RRstringValue = String(Int(Double(round(1 * value!) / 1)))
//                    workoutDict["data"]!["Respiratory Rate"]!.append(Double(round(1 * value!) / 1))
//                default:
//                    return
//            }
//        }
//        DispatchQueue.main.async() {
//            print("[workoutBuilder] Heart Rate: \(String(describing: HRstringValue))")
//            print("[workoutBuilder] Active Energy Burned: \(String(describing: AEBstringValue))")
//            print("[workoutBuilder] Basal Energy Burned: \(String(describing: BEBstringValue))")
//            print("[workoutBuilder] Distance Walked: \(String(describing: DWstringValue))")
//            print("[workoutBuilder] Apple Stand Time: \(String(describing: ASTstringValue))")
//            print("[workoutBuilder] Apple Walking Steadiness: \(String(describing: AWSstringValue))")
//            print("[workoutBuilder] Environmental Audio Exposure: \(String(describing: EAEstringValue))")
//            print("[workoutBuilder] Heart Rate Variability: \(String(describing: HRVstringValue))")
//            print("[workoutBuilder] Oxygen Saturation: \(String(describing: OSstringValue))")
//            print("[workoutBuilder] Body Temperature: \(String(describing: BTstringValue))")
//            print("[workoutBuilder] Blood Pressure Systolic: \(String(describing: BPSstringValue))")
//            print("[workoutBuilder] Blood Pressure Dyastolic: \(String(describing: BPDstringValue))")
//            print("[workoutBuilder] Respiratory Rate: \(String(describing: RRstringValue))")
//        }
//    }
//
//
//    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
//        // Retreive the workout event.
//        guard let workoutEventType = workoutBuilder.workoutEvents.last?.type else { return }
//        print("[workoutBuilderDidCollectEvent] Workout Builder changed event: \(workoutEventType.rawValue)")
//    }
//
//    func initWorkout() {
//        let configuration = HKWorkoutConfiguration()
//        configuration.activityType = .crossTraining
//        configuration.locationType = .outdoor
//
//        do {
//            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
//            builder = session.associatedWorkoutBuilder()
//        } catch {
//            fatalError("Unable to create the workout session!")
//        }
//
//        // Setup session and builder.
//        session.delegate = self
//        builder.delegate = self
//
//        /// Set the workout builder's data source.
//        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
//                                                     workoutConfiguration: configuration)
//    }
//
//
//    func startWorkout() {
//        // Initialize our workout
//        initWorkout()
//        print("[Workout Started]")
//
//        // Start the workout session and begin data collection
//        session.startActivity(with: Date())
//        builder.beginCollection(withStart: Date()) { (succ, error) in
//            if !succ {
//                fatalError("Error beginning collection from builder: \(String(describing: error)))")
//            }
//        }
//        state = HKWorkoutSessionState.running
//        appState = possibleAppStates.activeWorkout
//
//    }
//
//
//    func stopWorkout() {
//            // Stop the workout session
//        if session != nil{
//            session.end()
//            builder.endCollection(withEnd: Date()) { (success, error) in
//                self.builder.finishWorkout { (workout, error) in
//                    DispatchQueue.main.async() {
//                        self.session = nil
//                        self.builder = nil
//                    }
//                }
//            }
//            print("[Workout Stopped]")
//            state = HKWorkoutSessionState.stopped
//            appState = possibleAppStates.activeNotWorkout
//            }
//        }
//}
