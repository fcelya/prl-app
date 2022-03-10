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
    
    @IBOutlet var startStopButton: WKInterfaceButton!
    @IBOutlet var bpmLabel: WKInterfaceLabel!
    @IBOutlet var buttonGroup: WKInterfaceGroup!
    @IBOutlet weak var labelGroup: WKInterfaceGroup!
    
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
    let maxWorkoutTime = 30
    let timeBetweenWorkouts = 60
    
    //NETWORKING
    //Server url
    let serverUrl: URL = URL(string: "https://ptsv2.com/t/uf53u-1645038057/post")!
    
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
    var ecgDict: Dictionary<String, [String: [Any]]> = ["type": ["type": ["ecg"]],
                                                        "data": ["ecg": [],
                                                                 "timestamp": []]]

    var motionDict: Dictionary<String, [String: [Any]]> = ["type": ["type":["motion"]],
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

    var workoutDict: Dictionary<String, [String: [Any]]> = ["type": ["type": ["workout"]],
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
                                                                       "Distance Walked": []]]

    override func awake(withContext context: Any?) {
        // Configure interface objects here.
        super.awake(withContext: context)
        
        var healthDataCollected = false
        
        startMotionCollection()
        //Check for motion data
        Timer.scheduledTimer(withTimeInterval: TimeInterval(motionRefreshRate), repeats: true){_ in
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
            //Check If workout should be stopped or activated
            switch appState{
            case .activeWorkout:
                if Int64(NSDate().timeIntervalSince1970) - appStateChangeTime > maxWorkoutTime{
                    DispatchQueue.main.async() {
                        postHTTP(info: workoutDict, url: serverUrl)
                        // TODO: Empty the workout dictionary
                    }
                    stopWorkout()
                }
            case .activeNotWorkout:
                if Int64(NSDate().timeIntervalSince1970) - appStateChangeTime > timeBetweenWorkouts{
                    DispatchQueue.main.async() {
                        postHTTP(info: workoutDict, url: serverUrl)
                        // TODO: Empty the workout dictionary
                    }
                    startWorkout()
                }
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
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in if !success {
                fatalError("Error requesting authorization from health store: \(String(describing: error)))")
            }
        }
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
            //send data to server here
            let info: Dictionary = [
                "HeartRate": Int(HRstringValue)!,
                "Energy Burned": Int(AEBstringValue)!,
                "Distance Walked": Int(DWstringValue)!]
            postHTTP(info: info as Dictionary<String, Any> ,url: serverUrl)
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
        configuration.locationType = .indoor
        
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
        appStateChangeTime = Int64(NSDate().timeIntervalSince1970)
        
    }
    
    
    func stopWorkout() {
            // Stop the workout session
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
        appStateChangeTime = Int64(NSDate().timeIntervalSince1970)
        }
    
    func getSendECG(){
        //Get ECG
        ECG = requestECG()
        if(ECG == nil){
            print("[ECG]: No ECG data available")
        }else{
            ecgDict["data"]!["ecg"]!.append(ECG!)
            ecgDict["data"]!["timestamp"]!.append(Int64(NSDate().timeIntervalSince1970))
            print("[Start Workout]: ECG retrieved with average HR of \(String(describing: ECG?.averageHeartRate)) and classification of \(String(describing: ECG?.classification))")
            //Send ECG
            DispatchQueue.main.async() {
                self.postHTTP(info: self.ecgDict as Dictionary<String,[String:[Any]]>, url: self.serverUrl)
            }
        }
    }
    
    func postHTTP(info: Dictionary<String, Any>, url: URL) {
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: info, options: JSONSerialization.WritingOptions.prettyPrinted)
            
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        print("error=\(String(describing: error))")
                        return
                    }
                    guard let httpResponse = response as? HTTPURLResponse,
                        (200...299).contains(httpResponse.statusCode) else {
                        print("error=\(String(describing: error))")
                        return
                    }
                    if let mimeType = httpResponse.mimeType, mimeType == "text/plain",
                        let data = data,
                        let message = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            print(message)
                        }
                    }
                }
            task.resume()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func requestECG() -> HKElectrocardiogram? {
        // Create the electrocardiogram sample type.
        let ecgType = HKObjectType.electrocardiogramType()
        var latestECG: HKElectrocardiogram?

        // Query for electrocardiogram samples
        let ecgQuery = HKSampleQuery(sampleType: ecgType,
                                     predicate: nil,
                                     limit: HKObjectQueryNoLimit,
                                     sortDescriptors: nil) { (query, samples, error) in
            if let error = error {
                // Handle the error here.
                fatalError("*** An error occurred \(error.localizedDescription) ***")
            }
            
            guard let ecgSamples = samples as? [HKElectrocardiogram] else {
                fatalError("*** Unable to convert \(String(describing: samples)) to [HKElectrocardiogram] ***")
            }
            if (latestECG != nil){
                latestECG = ecgSamples[0]
            }
            
//            for sample in ecgSamples {
//                 Handle the samples here.
//
//            }
        }

        // Execute the query.
        healthStore.execute(ecgQuery)
        return latestECG
    }
    
        
    @IBAction func buttonPressed() {
        
        switch appState {
        case .welcome:
            labelGroup.setRelativeHeight(0.5,withAdjustment: 0)
            buttonGroup.setRelativeHeight(0.5,withAdjustment: 0)
            startWorkout()
            getSendECG()
            appState = possibleAppStates.activeWorkout
            startStopButton!.setTitle("Stop")
        case .activeWorkout:
            stopWorkout()
            appState = possibleAppStates.activeNotWorkout
            bpmLabel!.setText("---")
            startStopButton!.setTitle("Start")
        case .activeNotWorkout:
            break
        case .emergency:
            break
        case .stopped:
            break
        }
        
//        switch state{
//        case HKWorkoutSessionState.running:
//            stopWorkout()
//            state = HKWorkoutSessionState.ended
//            bpmLabel!.setText("---")
//            startStopButton!.setTitle("Start")
//        default:
//            startWorkout()
//            state = HKWorkoutSessionState.running
//            startStopButton!.setTitle("Stop")
//        }
    }
}
    
