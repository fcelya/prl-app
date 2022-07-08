//
//  UtilHealth.swift
//  test-4 WatchKit Extension
//
//  Created by Elena Ponce Moreno on 6/24/22.
//

import Foundation
import HealthKit
import WatchKit

extension InterfaceController{
    
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
                self.postHTTP2(info: self.ecgDict as Dictionary<String,[String:[Any]]>, url: self.serverUrl)
            }
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
}
