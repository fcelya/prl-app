//
//  UtilHTTP.swift
//  test-4 WatchKit Extension
//
//  Created by Elena Ponce Moreno on 6/24/22.
//

import Foundation
import WatchKit

extension InterfaceController{
    func postHTTP2(info: Dictionary<String, Any>, url: URL) {
        //TODO: Return response code
        //create the session object
        let session = URLSession.shared

        //now create the URLRequest object using the url object
        var request = URLRequest(url: url)
        request.httpMethod = "POST" //set http method as POST

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: info, options: .prettyPrinted) // pass dictionary to nsdata object and set it as request body

        } catch let error {
            print(error.localizedDescription)
        }

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        //create dataTask using the session object to send data to the server
        let task = session.dataTask(with: request, completionHandler: { data, response, error in

            guard error == nil else {
                print("[HTTP POST]: Encountered error: \(error!)")
                return
            }

            guard let data = data else {
                return
            }

            do {
                //create json object from data
                if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    print(json)
                    // handle json...
//                    let emerg = json["emergency"] as! String
//                    let prefix = String(emerg.prefix(1))
//                    switch prefix{
//                        case "0":
//                        break
//                        case "1":
//                        self.stopWorkout()
//                        self.appState = possibleAppStates.welcome
//                        WKInterfaceDevice.current().play(.failure)
//                        self.pushController(withName: "descansa", context: nil)
//                        case "2":
//                        self.stopWorkout()
//                        self.appState = possibleAppStates.welcome
//                        WKInterfaceDevice.current().play(.failure)
//                        self.pushController(withName: "caida", context: nil)
//                        default:
//                        break
//                    }
                }

            } catch let error {
                print(error.localizedDescription)
            }
        })
        task.resume()
    }
    
    func getHTTP2(url: URL) {
        //create the session object
        let session = URLSession.shared

        //now create the URLRequest object using the url object
        var request = URLRequest(url: url)
        request.httpMethod = "GET" //set http method as POST

        //create dataTask using the session object to send data to the server
        let task = session.dataTask(with: request, completionHandler: { data, response, error in

            guard error == nil else {
                print("[HTTP GET]: Encountered error: \(error!)")
                return
            }

            guard let data = data else {
                return
            }

            do {
                //create json object from data
                if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    print(json)
                    // handle json...
                    let emerg = json["emergency"] as! String
                    let prefix = String(emerg.prefix(1))
                    switch prefix{
                        case "0":
                        break
                        case "1":
                        self.stopWorkout()
                        self.appState = possibleAppStates.welcome
                        self.startStopButton!.setTitle("Start")
                        WKInterfaceDevice.current().play(.failure)
                        self.pushController(withName: "descansa", context: nil)
                        case "2":
                        self.stopWorkout()
                        self.appState = possibleAppStates.welcome
                        self.startStopButton!.setTitle("Start")
                        WKInterfaceDevice.current().play(.failure)
                        self.pushController(withName: "caida", context: nil)
                        default:
                        break
                    }
                }

            } catch let error {
                print(error.localizedDescription)
            }
        })
        task.resume()
    }
    
    
    
    func sendAndSave(){
        //TODO: only erase data if return code is successful
        let postURL = self.serverUrl.appendingPathComponent("post")
        self.postHTTP2(info: self.workoutDict, url: postURL)
        self.postHTTP2(info: self.motionDict, url: postURL)
        self.motionDict = ["type": ["type":["motion"], "device id": [deviceID]],
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
        self.workoutDict = ["type": ["type": ["health"], "device id": [deviceID]],
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
        print("[HTTP]: Sent motion and health data")
        return
    }
}

extension InterfaceControllerAlert{
    func postHTTP2(info: Dictionary<String, Any>, url: URL) {
        //TODO: Return response code
        //create the session object
        let session = URLSession.shared

        //now create the URLRequest object using the url object
        var request = URLRequest(url: url)
        request.httpMethod = "POST" //set http method as POST

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: info, options: .prettyPrinted) // pass dictionary to nsdata object and set it as request body

        } catch let error {
            print(error.localizedDescription)
        }

        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        //create dataTask using the session object to send data to the server
        let task = session.dataTask(with: request, completionHandler: { data, response, error in

            guard error == nil else {
                print("[HTTP POST]: Encountered error: \(error!)")
                return
            }

            guard let data = data else {
                return
            }

            do {
                //create json object from data
                if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    print(json)
                    // handle json...
//                    let emerg = json["emergency"] as! String
//                    let prefix = String(emerg.prefix(1))
//                    switch prefix{
//                        case "0":
//                        break
//                        case "1":
//                        self.stopWorkout()
//                        self.appState = possibleAppStates.welcome
//                        WKInterfaceDevice.current().play(.failure)
//                        self.pushController(withName: "descansa", context: nil)
//                        case "2":
//                        self.stopWorkout()
//                        self.appState = possibleAppStates.welcome
//                        WKInterfaceDevice.current().play(.failure)
//                        self.pushController(withName: "caida", context: nil)
//                        default:
//                        break
//                    }
                }

            } catch let error {
                print(error.localizedDescription)
            }
        })
        task.resume()
    }
}
