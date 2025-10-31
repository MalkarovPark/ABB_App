//
//  Functions.swift
//  ABB App
//
//  Created by Artem on 15.09.2025.
//

import Foundation
import Network
import IndustrialKit

// MARK: - UwU
// Functions? OwO

/*
 override func move_to(point: PositionPoint)
 {
     // Convert Euler angles (degrees) to quaternion
     let roll = point.r * Float.pi / 180
     let pitch = point.p * Float.pi / 180
     let yaw = point.w * Float.pi / 180
     
     let cy = cos(yaw * 0.5)
     let sy = sin(yaw * 0.5)
     let cp = cos(pitch * 0.5)
     let sp = sin(pitch * 0.5)
     let cr = cos(roll * 0.5)
     let sr = sin(roll * 0.5)

     let q4 = cr * cp * cy + sr * sp * sy  // w
     let q1 = sr * cp * cy - cr * sp * sy  // x
     let q2 = cr * sp * cy + sr * cp * sy  // y
     let q3 = cr * cp * sy - sr * sp * cy  // z
     
     // Format command string
     let command_str = String(format: "SET_TARGET %.3f,%.3f,%.3f,%.6f,%.6f,%.6f,%.6f",
                              point.x, point.y, point.z,
                              q1, q2, q3, q4)
     
     guard let active_connection = SocketHolder.nw_connection, SocketHolder.is_ready else
     {
         print("❌ connection not ready")
         return
     }
     
     /*// Send command
     active_connection.send(content: command_str.data(using: .utf8), completion: .contentProcessed { send_error in
         if let send_error = send_error
         {
             print("❌ send error: \(send_error)")
             return
         }
         print("✅ sent SET_TARGET")
     })*/
     
     // Send command
     active_connection.send(content: command_str.data(using: .utf8), completion: .contentProcessed { send_error in
         if let send_error = send_error
         {
             print("❌ send error: \(send_error)")
             return
         }
         print("✅ sent SET_TARGET")
         
         // Wait for response
         func receive_next()
         {
             active_connection.receive(minimumIncompleteLength: 1, maximumLength: 256)
             { data, _, is_complete, recv_error in
                 guard let data = data,
                       let response_text = String(data: data, encoding: .utf8),
                       recv_error == nil
                 else
                 {
                     print("❌ receive error or no data")
                     return
                 }
                 
                 print("📍 robot output: \(response_text)")
                 
                 if is_complete
                 {
                     print("✅ connection closed by peer")
                     return
                 }
                 
                 // keep waiting for next response
                 receive_next()
             }
         }
         
         receive_next()
     })
     
     //usleep(500000)
 }
 */

//
//  Connector.swift
//  ABB App
//
//  Created by Artem on 28.07.2025.
//

/*
import Foundation
import Network
import IndustrialKit

nonisolated class ABBConnector: RobotConnector, @unchecked Sendable //nonisolated(unsafe) open class ABB_Connector: RobotConnector
{
    // MARK: - Connection
    override var parameters: [ConnectionParameter]
    {
        [
            .init(name: "IP Address", value: "169.254.5.175"),
            .init(name: "Port", value: "5000")
        ]
    }
    
    override func connection_process() async -> Bool
    {
        guard parameters.count > 0 else
        {
            output += "\n"
            output += "<failed: ❌ missing connection address>"
            return false
        }
        
        let host = parameters[0].value as! String
        let port: NWEndpoint.Port =
        {
            if parameters.count > 1, let p = UInt16(parameters[1].value as! String)
            {
                return NWEndpoint.Port(rawValue: p) ?? 5000
            }
            else
            {
                return 5000
            }
        }()
        
        if SocketHolder.nw_connection != nil
        {
            output += "\n"
            output += "ℹ️ connection already exists"
            return false
        }
        
        let new_connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp) //NWConnection(host: "169.254.5.175", port: 5000, using: .tcp)
        SocketHolder.nw_connection = new_connection
        
        //var output = String()
        var result = false
        
        output += "\n"
        
        let semaphore = DispatchSemaphore(value: 0) //!!
        
        new_connection.stateUpdateHandler = { state in
            //print("connection_state: \(state)")
            switch state
            {
            case .ready:
                self.output += "<done: ✅ connection ready>"
                result = true
                SocketHolder.is_ready = true
            case .failed(let error):
                self.output += "<failed: ❌ connection failed: \(error)>"
                result = false
                SocketHolder.is_ready = false
                SocketHolder.nw_connection = nil
            case .waiting(let error):
                self.output += "<failed: ⚠️ connection waiting: \(error)>"
                result = false
                SocketHolder.is_ready = false
                SocketHolder.nw_connection = nil
            default:
                break
            }
        }
        
        new_connection.start(queue: SocketHolder.nw_queue)
        
        // Wait max 2 seconds for connection state
        _ = semaphore.wait(timeout: .now() + 1) //!!
        
        return result
        //return true
    }
    
    override func disconnection_process()
    {
        guard let active_connection = SocketHolder.nw_connection else
        {
            print("ℹ️ no active connection")
            return
        }
        
        active_connection.cancel()
        SocketHolder.nw_connection = nil
        SocketHolder.is_ready = false
    }
    
    // Holder for connection instance and state
    private struct SocketHolder
    {
        static var nw_connection: NWConnection? = nil
        static var is_ready = false
        static let nw_queue = DispatchQueue(label: "robot_socket_queue")
    }
    
    // MARK: - Performing
    override func move_to(point: PositionPoint)
    {
        // Convert Euler angles (degrees) to quaternion
        let roll = point.r * Float.pi / 180
        let pitch = point.p * Float.pi / 180
        let yaw = point.w * Float.pi / 180
        
        let cy = cos(yaw * 0.5)
        let sy = sin(yaw * 0.5)
        let cp = cos(pitch * 0.5)
        let sp = sin(pitch * 0.5)
        let cr = cos(roll * 0.5)
        let sr = sin(roll * 0.5)

        let q4 = cr * cp * cy + sr * sp * sy  // w
        let q1 = sr * cp * cy - cr * sp * sy  // x
        let q2 = cr * sp * cy + sr * cp * sy  // y
        let q3 = cr * cp * sy - sr * sp * cy  // z
        
        // Format command string
        let command_str = String(format: "SET_TARGET %.3f,%.3f,%.3f,%.6f,%.6f,%.6f,%.6f",
                                 point.x, point.y, point.z,
                                 q1, q2, q3, q4)
        
        guard let active_connection = SocketHolder.nw_connection, SocketHolder.is_ready else
        {
            print("❌ connection not ready")
            return
        }
        
        // Семафор для блокировки
        let semaphore = DispatchSemaphore(value: 0)
        
        /*// Send command
        active_connection.send(content: command_str.data(using: .utf8), completion: .contentProcessed { send_error in
            if let send_error = send_error
            {
                print("❌ send error: \(send_error)")
                semaphore.signal() // чтобы не зависнуть навсегда
                return
            }
            print("✅ sent SET_TARGET")
            
            // Wait for response until MOVE_OK
            func receive_next()
            {
                active_connection.receive(minimumIncompleteLength: 1, maximumLength: 256)
                { data, _, is_complete, recv_error in
                    guard let data = data,
                          let response_text = String(data: data, encoding: .utf8),
                          recv_error == nil
                    else
                    {
                        print("❌ receive error or no data")
                        semaphore.signal()
                        return
                    }
                    
                    print("📍 robot output: \(response_text)")
                    
                    if response_text.contains("MOVE_OK")
                    {
                        print("✅ received MOVE_OK, done waiting")
                        semaphore.signal()
                        return
                    }
                    
                    if is_complete
                    {
                        print("✅ connection closed by peer")
                        semaphore.signal()
                        return
                    }
                    
                    // keep waiting for next response
                    receive_next()
                }
            }
            
            receive_next()
        })*/
        
        /*self.get_output
        { output in
            if output?.state.completed == true
            {
                print("✅ received MOVE_OK, done waiting")
                semaphore.signal()
                return
            }
        }*/
        
        self.completed = false
        
        active_connection.send(
            content: command_str.data(using: .utf8),
            //completion: .idempotent
            completion: .contentProcessed
            { send_error in
                func receive_next()
                {
                    self.get_output
                    { output in
                        if output?.state.completed ?? false //let output2 = output, output2.state.completed
                        {
                            print("✅ received MOVE_OK, done waiting")
                            //self.completed = false
                            semaphore.signal()
                            return
                        }
                        else
                        {
                            receive_next()
                        }
                    }
                }
                
                receive_next()
            }
        )
        
        // Ждём ответа (⚠️ можно задать timeout)
        semaphore.wait()
        
        print("🍷")
        
        /*self.completed = false
        
        func receive_next()
        {
            self.get_output
            { output in
                if output?.state.completed ?? false //let output2 = output, output2.state.completed
                {
                    print("✅ received MOVE_OK, done waiting")
                    //self.completed = false
                    semaphore.signal()
                    return
                }
                else
                {
                    receive_next()
                }
            }
        }
        
        receive_next()
        
        // Ждём ответа (⚠️ можно задать timeout)
        semaphore.wait()
        
        print("🍷")*/
        //self.cnt = 0
    }
    
    // MARK: - Statistics
    override func initial_charts_data() -> [WorkspaceObjectChart]
    {
        /*@START_MENU_TOKEN@*//*@PLACEHOLDER=return [WorkspaceObjectChart]()@*/return [WorkspaceObjectChart]()/*@END_MENU_TOKEN@*/
    }
    
    override func updated_charts_data() -> [WorkspaceObjectChart]?
    {
        /*@START_MENU_TOKEN@*//*@PLACEHOLDER=return [WorkspaceObjectChart]()@*/return [WorkspaceObjectChart]()/*@END_MENU_TOKEN@*/
    }
    
    override func initial_states_data() -> [StateItem]
    {
        /*@START_MENU_TOKEN@*//*@PLACEHOLDER=return [StateItem]()@*/return [StateItem]()/*@END_MENU_TOKEN@*/
    }
    
    override func updated_states_data() -> [StateItem]?
    {
        /*@START_MENU_TOKEN@*//*@PLACEHOLDER=return [StateItem]()@*/return [StateItem]()/*@END_MENU_TOKEN@*/
    }
    
    var cnt = 0
    
    var x = Float()
    var y = Float()
    var z = Float()
    
    var processing = false
    var completed  = false
    var error = false
    
    // MARK: - Other
    public func get_output(completion: @escaping ((position:
                                                (x: Float, y: Float, z: Float,
                                                 r: Float, p: Float, w: Float),
                                            state:
                                                (processing: Bool, completed: Bool, error: Bool)
                                           )?) -> Void)
    {
        /*sleep(1)
        cnt += 1
        
        completion((
            position: (x: Float(cnt), y: 0, z: 0, r: 0, p: 0, w: 0),
            state: (processing: false, completed: cnt > 4, error: false)
        ))*/
        
        usleep(50000)
        
        guard let active_connection = SocketHolder.nw_connection, SocketHolder.is_ready else
        {
            print("❌ connection not ready")
            completion(nil)
            return
        }
        
        // Send GET_OUTPUT command
        let command_str = "GET_OUTPUT"
        active_connection.send(content: command_str.data(using: .utf8), completion: .contentProcessed { send_error in
            if let send_error = send_error
            {
                print("❌ send error: \(send_error)")
                completion(nil)
                return
            }
            print("✅ sent GET_OUTPUT")
            
            // Receive response
            active_connection.receive(minimumIncompleteLength: 1, maximumLength: 256)
            { data, _, _, recv_error in
                guard let data = data,
                      let response_text = String(data: data, encoding: .utf8),
                      recv_error == nil else
                {
                    print("❌ receive error or no data")
                    completion(nil)
                    return
                }
                
                print("📍 robot output: \(response_text)")
                
                // Parse response
                let parsed_values = response_text.split(separator: ",").compactMap { Float($0) }
                if parsed_values.count == 10
                {
                    /*var x = parsed_values[0]
                    var y = parsed_values[1]
                    var z = parsed_values[2]*/
                    
                    self.x = parsed_values[0]
                    self.y = parsed_values[1]
                    self.z = parsed_values[2]
                    
                    /*var q1 = parsed_values[3]
                    var q2 = parsed_values[4]
                    var q3 = parsed_values[5]
                    var q4 = parsed_values[6]
                    
                    // Convert quaternion to Euler angles
                    let sinr_cosp = 2 * (q4 * q1 + q2 * q3)
                    let cosr_cosp = 1 - 2 * (q1 * q1 + q2 * q2)
                    var r = atan2(sinr_cosp, cosr_cosp) * 180 / .pi
                    
                    let sinp = 2 * (q4 * q2 - q3 * q1)
                    var p: Float
                    if abs(sinp) >= 1
                    {
                        p = (sinp > 0 ? 90 : -90)
                    }
                    else
                    {
                        p = asin(sinp) * 180 / .pi
                    }
                    
                    let siny_cosp = 2 * (q4 * q3 + q1 * q2)
                    let cosy_cosp = 1 - 2 * (q2 * q2 + q3 * q3)
                    var w = atan2(siny_cosp, cosy_cosp) * 180 / .pi*/
                    
                    // Calibration
                    self.x -= 556
                    self.y -= 8.6
                    self.z -= 662.4
                    
                    /*r -= 90
                    p += 90
                    w -= 180*/
                    
                    // State flags
                    self.processing = (parsed_values[7] == 1)
                    self.completed  = (parsed_values[8] == 1)
                    self.error  = (parsed_values[9] == 1)
                    
                    /*let processing = (parsed_values[7] == 1)
                    let completed  = (parsed_values[8] == 1)
                    let error  = (parsed_values[9] == 1)
                    
                    completion((
                        position: (x: x, y: y, z: z, r: r, p: p, w: w),
                        state: (processing: processing, completed: completed, error: error)
                    ))*/
                }
                else
                {
                    print("⚠️ response parsing failed")
                    completion(nil)
                }
            }
            
            print(self.completed)
            
            completion((
                position: (x: self.x, y: self.y, z: self.z, r: 0, p: 0, w: 0),
                state: (processing: self.processing, completed: self.completed, error: self.error)
            ))
        })
    }
}
*/

/*// Convert Euler angles (degrees) to quaternion
let roll = point.r * Float.pi / 180
let pitch = point.p * Float.pi / 180
let yaw = point.w * Float.pi / 180

let cy = cos(yaw * 0.5)
let sy = sin(yaw * 0.5)
let cp = cos(pitch * 0.5)
let sp = sin(pitch * 0.5)
let cr = cos(roll * 0.5)
let sr = sin(roll * 0.5)

let q4 = cr * cp * cy + sr * sp * sy  // w
let q1 = sr * cp * cy - cr * sp * sy  // x
let q2 = cr * sp * cy + sr * cp * sy  // y
let q3 = cr * cp * sy - sr * sp * cy  // z

// Format command string
let command_str = String(format: "SET_TARGET %.3f,%.3f,%.3f,%.6f,%.6f,%.6f,%.6f",
                         point.x, point.y, point.z,
                         q1, q2, q3, q4)

guard let active_connection = SocketHolder.nw_connection, SocketHolder.is_ready else
{
    print("❌ connection not ready")
    return
}

// Семафор для блокировки
let semaphore = DispatchSemaphore(value: 0)

// Send command
active_connection.send(content: command_str.data(using: .utf8), completion: .contentProcessed { send_error in
    if let send_error = send_error
    {
        print("❌ send error: \(send_error)")
        semaphore.signal() // чтобы не зависнуть навсегда
        return
    }
    print("✅ sent SET_TARGET")
    
    // Wait for response until MOVE_OK
    func receive_next()
    {
        active_connection.receive(minimumIncompleteLength: 1, maximumLength: 256)
        { data, _, is_complete, recv_error in
            guard let data = data,
                  let response_text = String(data: data, encoding: .utf8),
                  recv_error == nil
            else
            {
                print("❌ receive error or no data")
                semaphore.signal()
                return
            }
            
            print("📍 robot output: \(response_text)")
            
            if response_text.contains("MOVE_OK")
            {
                print("✅ received MOVE_OK, done waiting")
                semaphore.signal()
                return
            }
            
            if is_complete
            {
                print("✅ connection closed by peer")
                semaphore.signal()
                return
            }
            
            // keep waiting for next response
            receive_next()
        }
    }
    
    receive_next()
})

self.get_output
{ output in
    if output?.state.completed == true
    {
        print("✅ received MOVE_OK, done waiting")
        semaphore.signal()
        return
    }
}*/

// Семафор для блокировки
//let semaphore = DispatchSemaphore(value: 0)

/*self.completed = false

active_connection.send(
    content: command_str.data(using: .utf8),
    //completion: .idempotent
    completion: .contentProcessed
    { send_error in
        func receive_next()
        {
            self.get_output
            { output in
                if output?.state.completed ?? false //let output2 = output, output2.state.completed
                {
                    print("✅ received MOVE_OK, done waiting")
                    //self.completed = false
                    semaphore.signal()
                    return
                }
                else
                {
                    receive_next()
                }
            }
        }
        
        receive_next()
    }
)

// Ждём ответа (⚠️ можно задать timeout)
semaphore.wait()

print("🍷")*/
